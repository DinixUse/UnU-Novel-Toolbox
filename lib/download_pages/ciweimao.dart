import 'dart:convert';
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:unu_novel_toolbox/widgets/widgets.dart';
import 'package:webview_windows/webview_windows.dart';

import '../widgets/expressive_refresh.dart';
import '../services/download_manager.dart';

// 章节数据模型
class cwm_NovelChapter {
  final String title;
  final String url;
  cwm_NovelChapter({required this.title, required this.url});
}

// 卷数据模型
class cwm_NovelVolume {
  final String volumeName;
  final List<cwm_NovelChapter> chapters;
  cwm_NovelVolume({required this.volumeName, required this.chapters});
}

class cwm_NovelCatalogPage extends StatefulWidget {
  const cwm_NovelCatalogPage({super.key});
  @override
  State<cwm_NovelCatalogPage> createState() => _cwm_NovelCatalogPageState();
}

class _cwm_NovelCatalogPageState extends State<cwm_NovelCatalogPage> {
  final TextEditingController _urlController = TextEditingController(text: '');
  bool _isLoading = false;
  String _statusMessage = '';

  String _novelTitle = '';
  String _novelAuthor = '';
  String _novelCover = '';
  List<cwm_NovelVolume> _catalogData = [];

  late final WebviewController _webviewController;
  bool _webViewInitialized = false;
  String _bookId = '100012892';

  bool _isEpub = true;
  bool _isTaskAdded = false;

  @override
  void initState() {
    super.initState();
    _webviewController = WebviewController();
    _initWebView();
    _urlController.addListener(() {
      _parseBookIdFromUrl(_urlController.text);
    });
  }

  void _parseBookIdFromUrl(String url) {
    final regex = RegExp(r'book/(\d+)');
    final match = regex.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      setState(() {
        _bookId = match.group(1)!;
      });
    }
  }

  Future<void> _initWebView() async {
    try {
      await _webviewController.initialize();
      // 设置User-Agent，模拟真实浏览器（反爬）
      await _webviewController.setUserAgent(
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      );
      await _webviewController.setBackgroundColor(Colors.transparent);

      // 监听控制台日志
      _webviewController.webMessage.listen((message) {
        debugPrint('WebView日志：$message');
      });

      _webviewController.loadingState.listen((state) {
        if (state == LoadingState.navigationCompleted) {
          debugPrint('页面加载完成');
        }
      });

      setState(() => _webViewInitialized = true);
    } catch (e) {
      setState(() => _statusMessage = 'WebView初始化失败：$e');
    }
  }

  /// 绕过反爬，直接请求章节接口（替代WebView JS执行）
  Future<bool> _fetchChaptersByApi() async {
    try {
      setState(() => _statusMessage = '请求章节接口...');
      int page = 1;
      bool hasMore = true;
      const maxPage = 20;
      List<Map<String, dynamic>> allChapters = [];

      while (hasMore && page <= maxPage) {
        final url = Uri.parse('https://www.ciweimao.com/book/get_more_chapter')
            .replace(
              queryParameters: {
                'book_id': _bookId,
                'page': page.toString(),
                'is_paid': '1',
              },
            );

        // 模拟浏览器请求头
        final response = await HttpClient().getUrl(url).then((request) {
          request.headers.add(
            'Accept',
            'application/json, text/javascript, */*; q=0.01',
          );
          request.headers.add('X-Requested-With', 'XMLHttpRequest');
          request.headers.add('Referer', _urlController.text);
          request.headers.add(
            'User-Agent',
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          );
          request.headers.add('Cookie', 'ciweimao_token='); // 替换为真实Cookie
          return request.close();
        });

        final responseBody = await response.transform(utf8.decoder).join();
        final jsonData = jsonDecode(responseBody);

        if (jsonData['code'] == 100000) {
          final chapters = jsonData['data']['chapters'] as List;
          allChapters.addAll(chapters.cast<Map<String, dynamic>>());
          hasMore = jsonData['data']['has_more'] == 1;
          debugPrint('第 $page 页获取到 ${chapters.length} 章，是否有更多：$hasMore');
          page++;
          await Future.delayed(const Duration(milliseconds: 500)); // 避免请求过快
        } else {
          debugPrint('接口返回错误：${jsonData['tip']}');
          hasMore = false;
        }
      }

      // 将接口数据渲染到WebView的目录中
      if (allChapters.isNotEmpty) {
        final renderScript =
            '''
          (function() {
            const catalogList = document.querySelector('#J_book_chapter_list .book-chapter-list') || 
                                document.querySelector('.book-chapter-list');
            if (!catalogList) return false;
            
            let html = '';
            ${allChapters.map((ch) => '''
              html += '<li><a href="https://www.ciweimao.com/chapter/${ch['chapter_id']}" target="_blank" rel="noopener noreferrer">${ch['chapter_name']}</a></li>';
            ''').join('')}
            
            catalogList.innerHTML += html;
            return true;
          })();
        ''';
        await _webviewController.executeScript(renderScript);
        setState(() => _statusMessage = '接口获取到 ${allChapters.length} 章');
        return true;
      } else {
        setState(() => _statusMessage = '接口未返回章节数据');
        return false;
      }
    } catch (e) {
      debugPrint('接口请求失败：$e');
      setState(() => _statusMessage = '接口请求失败：$e');
      return false;
    }
  }

  /// 目录解析逻辑
  List<cwm_NovelVolume> _parseCatalogFromHtml(String html) {
    final List<cwm_NovelVolume> volumes = [];
    try {
      final document = parse(html);

      // 方式1：从meta标签获取（优先）
      _novelTitle =
          document
              .querySelector('meta[property="og:novel:book_name"]')
              ?.attributes['content']
              ?.trim() ??
          document
              .querySelector('meta[name="title"]')
              ?.attributes['content']
              ?.trim() ??
          // 方式2：从页面标题解析
          document
              .querySelector('title')
              ?.text
              ?.replaceAll('- 刺猬猫阅读', '')
              .trim() ??
          // 方式3：从DOM元素获取
          document.querySelector('.book-name')?.text?.trim() ??
          document.querySelector('.book-info h1')?.text?.trim() ??
          document.querySelector('.book-info .title')?.text?.trim() ??
          '未知书名';

      _novelAuthor =
          document
              .querySelector('meta[property="og:novel:author"]')
              ?.attributes['content']
              ?.trim() ??
          document.querySelector('.author-name')?.text?.trim() ??
          document
              .querySelector('.book-info .author')
              ?.text
              ?.replaceAll('作者：', '')
              .trim() ??
          document.querySelector('.book-info .author a')?.text?.trim() ??
          '未知作者';

      debugPrint('解析到书名：$_novelTitle');
      debugPrint('解析到作者：$_novelAuthor');

      _novelCover =
          document
              .querySelector('meta[property="og:image"]')
              ?.attributes['content']
              ?.trim() ??
          "https://gd-hbimg.huaban.com/501f05df7cf3f7d94911329ad33e4365fbee4a3ef777-KBS5Su_fw658";
      debugPrint('解析到封面：$_novelCover');

      // 定位目录区域
      dom.Element? catalogBox = document.getElementById('J_book_chapter_list');
      if (catalogBox == null)
        catalogBox = document.querySelector('.book-chapter-box');
      if (catalogBox == null)
        catalogBox = document.querySelector('.chapter-list');
      if (catalogBox == null) throw Exception('未找到目录区域，请检查网站结构');

      // 方案A：按DOM层级解析（推荐）- 查找所有卷名元素及其对应的章节
      final volumeSections = catalogBox.querySelectorAll(
        '.volume-item, .chapter-group',
      );

      if (volumeSections.isNotEmpty) {
        // 有明确的卷分组结构
        for (var section in volumeSections) {
          // 提取卷名（支持多种卷名选择器）
          String volName =
              section
                  .querySelector(
                    'h4, .volume-title, .sub-tit, .chapter-group-title',
                  )
                  ?.text
                  ?.trim() ??
              '未知卷名';

          // 提取当前卷下的所有章节
          final chapterElements = section.querySelectorAll(
            'li a, .chapter-item a',
          );
          List<cwm_NovelChapter> volChapters = [];

          for (var chapter in chapterElements) {
            final title = chapter.text.trim();
            final url = chapter.attributes['href'] ?? '';
            if (title.isNotEmpty && url.isNotEmpty) {
              final fullUrl = url.startsWith('http')
                  ? url
                  : 'https://www.ciweimao.com$url';
              volChapters.add(cwm_NovelChapter(title: title, url: fullUrl));
            }
          }

          if (volChapters.isNotEmpty) {
            volumes.add(
              cwm_NovelVolume(volumeName: volName, chapters: volChapters),
            );
          }
        }
      } else {
        // 方案B：没有明确分组，查找独立的卷名标题+后续章节
        final allElements = catalogBox.children;
        String currentVolName = '全部章节';
        List<cwm_NovelChapter> currentChapters = [];

        for (var element in allElements) {
          // 判断是否是卷名标题
          if (element.localName == 'h4' ||
              element.classes.contains('sub-tit') ||
              element.classes.contains('volume-title') ||
              element.text.contains('卷')) {
            // 如果已有章节，先保存当前卷
            if (currentChapters.isNotEmpty) {
              volumes.add(
                cwm_NovelVolume(
                  volumeName: currentVolName,
                  chapters: currentChapters,
                ),
              );
              currentChapters = [];
            }

            // 更新当前卷名
            currentVolName = element.text.trim();
          }
          // 判断是否是章节列表项
          else if (element.localName == 'li' ||
              element.classes.contains('chapter-item')) {
            final chapterLink = element.querySelector('a');
            if (chapterLink != null) {
              final title = chapterLink.text.trim();
              final url = chapterLink.attributes['href'] ?? '';
              if (title.isNotEmpty && url.isNotEmpty) {
                final fullUrl = url.startsWith('http')
                    ? url
                    : 'https://www.ciweimao.com$url';
                currentChapters.add(
                  cwm_NovelChapter(title: title, url: fullUrl),
                );
              }
            }
          }
        }

        // 添加最后一卷
        if (currentChapters.isNotEmpty) {
          volumes.add(
            cwm_NovelVolume(
              volumeName: currentVolName,
              chapters: currentChapters,
            ),
          );
        }
      }

      // 保底方案：如果没有解析到任何卷，但有章节，创建默认卷
      if (volumes.isEmpty) {
        final chapterElements = catalogBox.querySelectorAll(
          'li a, .chapter-item a',
        );
        List<cwm_NovelChapter> allChapters = [];

        for (var chapter in chapterElements) {
          final title = chapter.text.trim();
          final url = chapter.attributes['href'] ?? '';
          if (title.isNotEmpty && url.isNotEmpty) {
            final fullUrl = url.startsWith('http')
                ? url
                : 'https://www.ciweimao.com$url';
            allChapters.add(cwm_NovelChapter(title: title, url: fullUrl));
          }
        }

        if (allChapters.isNotEmpty) {
          volumes.add(
            cwm_NovelVolume(volumeName: '全部章節', chapters: allChapters),
          );
        } else {
          throw Exception('未找到章节链接，可能是反爬限制');
        }
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
    if (!_webViewInitialized) {
      setState(() => _statusMessage = 'WebView尚未初始化');
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = '';
      _catalogData.clear();
      _novelTitle = '';
      _novelAuthor = '';
    });

    final url = _urlController.text.trim();
    final regex = RegExp(r'^https://www\.ciweimao\.com/book/\d+$');
    if (!regex.hasMatch(url)) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'URL格式錯誤，示例：https://www.ciweimao.com/book/100012892';
      });
      return;
    }

    try {
      // 1. 加载页面（等待更长时间）
      setState(() => _statusMessage = 'Loading Novel Page...');
      await _webviewController.loadUrl(url);

      // 等待页面完全加载（最长15秒）
      int waitCount = 0;
      bool pageReady = false;
      while (waitCount < 15) {
        final isLoaded = await _webviewController.executeScript('''
          document.readyState === 'complete' && 
          !!document.body && 
          document.body.innerText.length > 1000; // 确保页面内容加载完成
        ''');
        if (isLoaded == true) {
          pageReady = true;
          break;
        }
        await Future.delayed(const Duration(seconds: 1));
        waitCount++;
      }

      if (!pageReady) {
        throw Exception('Time Out.');
      }

      // 2. 先尝试接口请求章节（优先级最高）
      bool apiSuccess = await _fetchChaptersByApi();

      // 3. 如果接口失败，尝试点击展开按钮
      if (!apiSuccess) {
        setState(() => _statusMessage = '接口失敗，使用Webview...');
        const clickScript = '''
          (function() {
            // 兼容所有展开按钮ID/类名
            const expandBtn = document.getElementById('J_ReadAll') || 
                              document.querySelector('.expand-more') ||
                              document.querySelector('.show-all-chapters');
            if (expandBtn) {
              expandBtn.click();
              return true;
            }
            return false;
          })();
        ''';
        await _webviewController.executeScript(clickScript);
        await Future.delayed(const Duration(seconds: 3));
      }

      // ========== 修复3：获取完整的页面HTML ==========
      setState(() => _statusMessage = '解析章節數據...');
      // 改为获取整个页面的HTML，而不仅仅是目录区域，确保能拿到书名/作者信息
      final html = await _webviewController.executeScript('''
        document.documentElement.outerHTML;
      ''');

      if (html == null || html.toString().isEmpty) {
        throw Exception('获取HTML为空，可能是反爬限制');
      }

      // 5. 解析数据
      final catalog = _parseCatalogFromHtml(html.toString());
      setState(() {
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
    _webviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //appBar: AppBar(title: const Text('刺蝟貓小説解析下載工具')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
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
                        hintText: 'https://www.ciweimao.com/book/数字',
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
                      onPressed: (_isLoading || !_webViewInitialized)
                          ? null
                          : (){
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
                          : !_webViewInitialized
                          ? const Text(
                              '初始化WebView...',
                              style: TextStyle(fontSize: 18),
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
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.tertiary,
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
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
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
                                                  final cwm_NovelExtractor
                                                  extractor =
                                                      cwm_NovelExtractor();
                                                  bool isInitSuccess =
                                                      await extractor
                                                          .initialize();

                                                  if (isInitSuccess) {
                                                    content = await extractor
                                                        .getNovelContent(
                                                          ch.url,
                                                        );

                                                    if (content.contains(
                                                          '失败',
                                                        ) ||
                                                        content.contains(
                                                          '未找到',
                                                        ) ||
                                                        content.contains(
                                                          'URL格式错误',
                                                        )) {
                                                      print('提取失败：$content');
                                                    } else {
                                                      print(
                                                        '提取成功，内容长度：${content.length} 字符',
                                                      );
                                                    }

                                                    extractor.dispose();
                                                  } else {
                                                    print('工具类初始化失败，无法提取内容');
                                                  }
                                                  closeLoadingDialog!();

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
                            )
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: BottomAppBar(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
              onPressed: _catalogData.isNotEmpty && _isTaskAdded == false
                  ? () {
                      // final cwm_NovelExtractor extractor = cwm_NovelExtractor();
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

                      cwm_DownloadManager.instance.addDownloadTask(
                        _novelCover,
                        _novelAuthor,
                        _novelTitle,
                        _catalogData,
                        _isEpub,
                      );

                      setState(() {
                        _isTaskAdded = true;
                      });
                    }
                  : null,
              child: _catalogData.isEmpty ? const Text("等待開始") : _isTaskAdded ? const Text("已添加") : const Text("添加到下載列表"),
            ),
          ],
        ),
      ),
    );
  }
}
