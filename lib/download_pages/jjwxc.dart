import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:charset/charset.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:unu_novel_toolbox/preferences.dart';
import 'package:unu_novel_toolbox/widgets/widgets.dart';
import 'package:webview_windows/webview_windows.dart';

import '../widgets/expressive_refresh.dart';
import '../services/download_manager.dart';

import '../services/cwm_tracker_core/book_fetcher.dart';

class JjwxcNovelCatalogPage extends StatefulWidget {
  const JjwxcNovelCatalogPage({super.key});
  @override
  State<JjwxcNovelCatalogPage> createState() => _JjwxcNovelCatalogPageState();
}

class _JjwxcNovelCatalogPageState extends State<JjwxcNovelCatalogPage> {
  final TextEditingController _urlController = TextEditingController(text: '');
  bool _isLoading = false;
  String _statusMessage = '';

  String _novelTitle = '';
  String _novelAuthor = '';
  String _novelCover = '';
  List<NovelVolume> _catalogData = [];

  String _bookId = '9715036';

  bool _isEpub = false;
  bool _isTaskAdded = false;

  @override
  void initState() {
    super.initState();

    _urlController.addListener(() {
      _parseBookIdFromUrl(_urlController.text);
    });
  }

  void _parseBookIdFromUrl(String url) {
    final regex = RegExp(r'.*onebook\.php\?novelid=(\d+)');
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      setState(() {
        _bookId = match.group(1)!;
      });
    }
  }

  /// 目录解析逻辑
  List<NovelVolume> _parseCatalogFromHtml(String html) {
    final List<NovelVolume> volumes = [];
    try {
      final document = parse(html);

      // 1. 解析书名（适配晋江结构）
      _novelTitle =
          // 方式1：从h1标题获取（最准确）
          document.querySelector('h1[itemprop="name"] span')?.text?.trim() ??
          // 方式2：从title标签解析
          document
              .querySelector('title')
              ?.text
              ?.replaceAll('_晋江文学城_【衍生小说|言情小说】', '')
              ?.replaceAll('《', '')
              ?.replaceAll('》', '')
              ?.trim() ??
          // 方式3：meta标签
          document
              .querySelector('meta[name="Keywords"]')
              ?.attributes['content']
              ?.split('，')
              ?.first
              ?.replaceAll('《', '')
              ?.replaceAll('》', '')
              ?.trim() ??
          '未知书名';

      // 2. 解析作者（适配晋江结构）
      _novelAuthor =
          // 方式1：从作者链接获取
          document
              .querySelector('h2 a span[itemprop="author"]')
              ?.text
              ?.trim() ??
          // 方式2：meta标签
          document
              .querySelector('meta[name="Author"]')
              ?.attributes['content']
              ?.trim() ??
          // 方式3：Keywords meta解析
          (document
                      .querySelector('meta[name="Keywords"]')
                      ?.attributes['content']
                      ?.split('，')
                      ?.elementAtOrNull(1) ??
                  '')
              .trim() ??
          '未知作者';

      // 3. 解析封面（适配晋江结构）
      _novelCover =
          document
              .querySelector('img.noveldefaultimage')
              ?.attributes['src']
              ?.trim() ??
          document
              .querySelector('img[itemprop="image"]')
              ?.attributes['src']
              ?.trim() ??
          "https://gd-hbimg.huaban.com/501f05df7cf3f7d94911329ad33e4365fbee4a3ef777-KBS5Su_fw658";

      debugPrint('解析到书名：$_novelTitle');
      debugPrint('解析到作者：$_novelAuthor');
      debugPrint('解析到封面：$_novelCover');

      // 4. 定位目录区域（晋江的章节列表在id为oneboolt的表格中）
      dom.Element? catalogTable = document.getElementById('oneboolt');
      if (catalogTable == null) {
        throw Exception('未找到目录区域，请检查网站结构');
      }

      // 5. 解析章节列表（晋江没有分卷，所有章节在一个列表中）
      final chapterRows = catalogTable.querySelectorAll(
        'tr[itemprop="chapter"]',
      );
      List<NovelChapter> allChapters = [];

      for (var row in chapterRows) {
        // 获取章节标题链接
        final chapterLink = row.querySelector(
          'td:nth-child(2) a[itemprop="url"]',
        );
        if (chapterLink != null) {
          final title = chapterLink.text.trim();
          final url = chapterLink.attributes['href'] ?? '';

          if (title.isNotEmpty && url.isNotEmpty) {
            // 处理URL，确保是完整链接
            final fullUrl = url.startsWith('http')
                ? url
                : url.startsWith('/')
                ? 'http://www.jjwxc.net$url'
                : 'http://www.jjwxc.net/$url';

            allChapters.add(NovelChapter(title: title, url: fullUrl));
          }
        }
      }

      // 6. 创建默认卷（晋江没有分卷，统一放在"全部章节"中）
      if (allChapters.isNotEmpty) {
        volumes.add(NovelVolume(volumeName: '全部章节', chapters: allChapters));
      } else {
        throw Exception('未找到章节链接，可能是反爬限制');
      }

      if (volumes.isEmpty) throw Exception('解析到0个章节');
      return volumes;
    } catch (e) {
      setState(() => _statusMessage = '解析失败：$e');
      return volumes;
    }
  }

  /// 核心流程：加载+接口请求+解析
  Future<void> _fetchAndParseCatalog() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '';
      _catalogData.clear();
      _novelTitle = '';
      _novelAuthor = '';
    });

    final url = _urlController.text.trim();
    final regex = RegExp(
      r'^https://www\.jjwxc\.net/onebook\.php\?novelid=\d+$',
    );
    if (!regex.hasMatch(url)) {
      setState(() {
        _isLoading = false;
        _statusMessage =
            'URL格式錯誤，示例：https://www.jjwxc.net/onebook.php?novelid=9715036';
      });
      return;
    }

    try {
      setState(() => _statusMessage = '請求接口...');

      Dio dio = Dio();

      Map<String, dynamic> bookData = {};
      final _response = await dio.get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final _htmlString = GbkDecoder().convert(_response.data);
      final _document = parse(_htmlString);

      setState(() => _statusMessage = '解析章節數據...');

      final List<dom.Element> _paragraphElements = _document.querySelectorAll(
        'tr[itemprop="chapter"][itemtype="http://schema.org/Chapter"]',
      );

      List<NovelVolume> _volumes = [];
      List<NovelChapter> _chapters = [];

      for (final singleElement in _paragraphElements) {
        final _urlLink = singleElement.querySelector('a[itemprop="url"]');

        if (_urlLink == null) continue;

        if (_urlLink.attributes['href'] == null) continue;

        _chapters.add(
          NovelChapter(
            title: _urlLink.text.trim(),
            url: _urlLink.attributes['href']?.trim() ?? "Error reading URL",
          ),
        );
      }

      _volumes.add(NovelVolume(volumeName: '全部章节', chapters: _chapters));

      bookData["catalogData"] = _volumes;

      bookData["novelTitle"] =
          _document.querySelector("title")?.text.trim() ?? "書名解析失敗";
      bookData["novelAuthor"] =
          _document
              .querySelector('meta[name="Author"]')
              ?.attributes['content']
              ?.trim() ??
          "作者解析失敗";
      bookData["novelCover"] =
          _document
              .querySelector('img.noveldefaultimage')
              ?.attributes["_src"] ??
          "https://gd-hbimg.huaban.com/501f05df7cf3f7d94911329ad33e4365fbee4a3ef777-KBS5Su_fw658";

      // TODO 替換邏輯為GET請求
      // Map<String, dynamic> bookData = await BookFetcher.fetchBook(url);

      _novelAuthor = bookData["novelAuthor"];
      _novelCover = bookData["novelCover"];
      _novelTitle = bookData["novelTitle"];

      setState(() {
        final catalog = bookData["catalogData"];
        _catalogData = catalog;
        final totalChapters = catalog.fold(0, (s, v) => s + v.chapters.length);
        _statusMessage = catalog.isNotEmpty
            ? '解析成功！共 ${catalog.length} 卷，$totalChapters 章'
            : '未解析到章节';
      });
    } catch (e) {
      setState(() => _statusMessage = '加载失败：$e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: '請填入URL',
                      hintText: 'https://www.jjwxc.net/onebook.php?novelid=數字',
                      border: const OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(128)),
                      ),
                      prefixIcon: const Icon(Icons.list),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _urlController.clear(),
                      ),
                    ),
                    style: const TextStyle(fontSize: 16),
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),

                SizedBox(
                  height: 50,
                  width: 200,
                  child: FilledButton(
                    onPressed: (_isLoading)
                        ? null
                        : () {
                            setState(() {
                              _isTaskAdded = false;
                            });
                            _fetchAndParseCatalog();
                          },
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(128),
                      ),
                    ),
                    child: _isLoading
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // CircularProgressIndicator(
                              //   color: Colors.white,
                              // ),
                              ExpressiveLoadingIndicator(
                                color: Colors.white.withValues(alpha: 0.5),
                              ),
                            ],
                          )
                        : const Text('解析目錄', style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (_statusMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  _statusMessage,
                  style: TextStyle(
                    color: Theme.of(
                      context,
                    ).colorScheme.inverseSurface.withAlpha(128),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),

            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                _novelTitle.isNotEmpty
                    ? Expanded(
                        flex: 1,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.network(
                                  _novelCover,
                                  width: 200,
                                  height: 290,
                                  fit: BoxFit.cover,
                                ),
                              ),

                              const SizedBox(height: 8),
                              Text(
                                '小説信息',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).colorScheme.tertiary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '標題：$_novelTitle',
                                style: const TextStyle(fontSize: 16),
                              ),
                              if (_novelAuthor.isNotEmpty)
                                Text(
                                  '作者：$_novelAuthor',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              if (_bookId.isNotEmpty)
                                Text(
                                  'ID：$_bookId',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      )
                    : const SizedBox(),
                Expanded(
                  flex: 1,
                  child: Material(
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.hardEdge,
                    color:
                        UserPreferences
                                .instance
                                .currentSettingsMap["scaffold_background_image_url"] ==
                            ""
                        ? Theme.of(context).colorScheme.surfaceContainerLowest
                        : Theme.of(
                            context,
                          ).colorScheme.surfaceContainerLowest.withAlpha(
                            UserPreferences
                                .instance
                                .currentSettingsMap["ui_alpha"],
                          ),
                    child: SizedBox(
                      height: 400,
                      child: _catalogData.isEmpty
                          ? const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    '等待開始...',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Scaffold(
                              backgroundColor: Colors.transparent,
                              body: SingleChildScrollView(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _catalogData.map((vol) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Ink(
                                          decoration: BoxDecoration(
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.tertiaryContainer,
                                            borderRadius: BorderRadius.circular(
                                              128,
                                            ),
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 8,
                                              horizontal: 24,
                                            ),
                                            margin: const EdgeInsets.symmetric(
                                              vertical: 8,
                                            ),
                                            child: Text(
                                              '${vol.volumeName}（共${vol.chapters.length}章）',
                                              style: TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .onTertiaryContainer,
                                              ),
                                            ),
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 5,
                                          ),
                                          child: Column(
                                            children: vol.chapters.asMap().entries.map((
                                              entry,
                                            ) {
                                              final idx = entry.key + 1;
                                              final ch = entry.value;
                                              return ListTile(
                                                shape:
                                                    const RoundedRectangleBorder(
                                                      borderRadius:
                                                          BorderRadius.all(
                                                            Radius.circular(4),
                                                          ),
                                                    ),
                                                leading: CircleAvatar(
                                                  radius: 12,
                                                  backgroundColor:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerLow,
                                                  child: Text(
                                                    '$idx',
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                title: Text(
                                                  ch.title,
                                                  style: const TextStyle(
                                                    fontSize: 15,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                subtitle: Text(
                                                  ch.url,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),

                                                onTap: () async {
                                                  void Function()?
                                                  closeLoadingDialog;

                                                  showDialog(
                                                    barrierDismissible: false,
                                                    context: context,
                                                    builder: (context) {
                                                      closeLoadingDialog = () =>
                                                          Navigator.pop(
                                                            context,
                                                          );
                                                      return Container(
                                                        alignment:
                                                            Alignment.center,
                                                        child:
                                                            const ExpressiveLoadingIndicator(
                                                              contained: true,
                                                            ),
                                                      );
                                                    },
                                                  );

                                                  String content = "";
                                                  final jjwxc_NovelExtractor
                                                  extractor =
                                                      jjwxc_NovelExtractor();
                                                  content = await extractor
                                                      .fetchChapterHtml(
                                                        Dio(),
                                                        ch.url,
                                                      );
                                                  // final cwm_NovelExtractor
                                                  // extractor =
                                                  //     cwm_NovelExtractor();
                                                  // bool isInitSuccess =
                                                  //     await extractor
                                                  //         .initialize();

                                                  // if (isInitSuccess) {
                                                  //   content = await extractor
                                                  //       .getNovelContent(
                                                  //         ch.url,
                                                  //       );

                                                  //   if (content.contains(
                                                  //         '失败',
                                                  //       ) ||
                                                  //       content.contains(
                                                  //         '未找到',
                                                  //       ) ||
                                                  //       content.contains(
                                                  //         'URL格式错误',
                                                  //       )) {
                                                  //     print('提取失败：$content');
                                                  //   } else {
                                                  //     print(
                                                  //       '提取成功，内容长度：${content.length} 字符',
                                                  //     );
                                                  //   }

                                                  //   extractor.dispose();
                                                  // } else {
                                                  //   print('工具类初始化失败，无法提取内容');
                                                  // }
                                                  closeLoadingDialog!();

                                                  // 測試用 開始
                                                  // File txtFile = File(
                                                  //   "C:/Users/Dinix/Desktop/example.txt",
                                                  // );

                                                  // await txtFile.writeAsString(
                                                  //   content,
                                                  //   encoding:
                                                  //       Encoding.getByName(
                                                  //         'utf-8',
                                                  //       )!,
                                                  // );
                                                  // 測試用 結束

                                                  showDialog(
                                                    context: context,
                                                    builder: (context) {
                                                      return AlertDialog(
                                                        title: Row(
                                                          mainAxisAlignment:
                                                              MainAxisAlignment
                                                                  .spaceBetween,
                                                          children: [
                                                            Text(ch.title),
                                                            IconButton(
                                                              onPressed: () =>
                                                                  Navigator.of(
                                                                    context,
                                                                  ).pop(),
                                                              icon: const Icon(
                                                                Icons.close,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                        content:
                                                            SingleChildScrollView(
                                                              child:
                                                                  SelectableText(
                                                                    content,
                                                                  ),
                                                            ),
                                                      );
                                                    },
                                                  );
                                                },
                                                //trailing: ExpressiveLoadingIndicator(),
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),

      bottomNavigationBar: BottomAppBar(
        color:
            UserPreferences
                    .instance
                    .currentSettingsMap["scaffold_background_image_url"] ==
                ""
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(
                UserPreferences.instance.currentSettingsMap["ui_alpha"],
              ),
        elevation: 0.0,
        child: Row(
          children: <Widget>[
            if (_catalogData.isNotEmpty) ...[
              IntrinsicWidth(
                child: RadioListTile<bool>(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(128)),
                  ),
                  title: const Text("TXT"),
                  value: false,
                  groupValue: _isEpub,
                  onChanged: (bool? value) => setState(() {
                    _isEpub = false;
                  }),
                ),
              ),
              IntrinsicWidth(
                child: RadioListTile<bool>(
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.all(Radius.circular(128)),
                  ),
                  title: const Text("EPUB"),
                  value: true,
                  groupValue: _isEpub,
                  onChanged: (bool? value) => setState(() {
                    _isEpub = true;
                  }),
                ),
              ),
            ],
            const Expanded(child: SizedBox()),

            FilledButton(
              onPressed:
                  _catalogData.isNotEmpty &&
                      _isTaskAdded == false &&
                      DownloadManager.instance.hasTaskByNovelTitle(
                            _novelTitle,
                          ) ==
                          false
                  ? () {
                      // final NovelExtractor extractor = NovelExtractor();
                      // bool isInitSuccess = await extractor.initialize();

                      // if (isInitSuccess) {
                      //   String novelUrl =
                      //       'https://www.ciweimao.com/chapter/114373635';
                      //   String content = await extractor.getNovelContent(
                      //     novelUrl,
                      //   );

                      //   if (content.contains('失败') ||
                      //       content.contains('未找到') ||
                      //       content.contains('URL格式错误')) {
                      //     print('提取失败：$content');
                      //   } else {
                      //     print('提取成功，内容长度：${content.length} 字符');
                      //     print('小说内容：$content');
                      //   }

                      //   extractor.dispose();
                      // } else {
                      //   print('工具类初始化失败，无法提取内容');
                      // }

                      DownloadManager.instance.addDownloadTask(
                        taskType: TaskType.jjwxc,
                        coverUrl: _novelCover,
                        novelAuthor: _novelAuthor,
                        novelTitle: _novelTitle,
                        volumes: _catalogData,
                        isEpub: _isEpub,
                        savePath:
                            "${UserPreferences.instance.currentSettingsMap["download_root_path"]}/$_novelTitle",
                      );

                      setState(() {
                        _isTaskAdded = true;
                      });
                    }
                  : null,
              child: _catalogData.isEmpty
                  ? const Text("等待開始")
                  : DownloadManager.instance.hasTaskByNovelTitle(_novelTitle)
                  ? const Text("已添加")
                  : _isTaskAdded
                  ? const Text("已添加")
                  : const Text("添加到下載列表"),
            ),
          ],
        ),
      ),
    );
  }
}
