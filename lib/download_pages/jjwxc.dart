import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unu_novel_toolbox/widgets/widgets.dart';

class JjwxcDownloadPage extends StatefulWidget {
  const JjwxcDownloadPage({super.key});
  @override
  State<JjwxcDownloadPage> createState() => _JjwxcDownloadPageState();
}

class _JjwxcDownloadPageState extends State<JjwxcDownloadPage> {
  final TextEditingController _urlController = TextEditingController(text: '');
  bool _isLoading = false;
  String _statusMessage = '';

  // 仅保留UI展示用的基础数据
  String _novelTitle = '';
  String _novelAuthor = '';
  String _novelCover = 'https://e1.kuangxiangit.com/uploads/allimg/c230810/10-08-23130101-63904.jpg';
  String _bookId = '100012892';

  bool _isEpub = false;
  bool _isTaskAdded = false;
  bool _webViewInitialized = true; // 直接设为true，避免初始化逻辑

  @override
  void initState() {
    super.initState();
    _urlController.addListener(() {
      // 移除URL解析逻辑，仅保留空方法
    });
  }

  // 空方法，仅用于UI点击响应
  Future<void> _fetchAndParseCatalog() async {
    setState(() {
      _isLoading = true;
      _statusMessage = '模拟加载中...';
    });

    // 模拟加载延迟
    await Future.delayed(const Duration(seconds: 1));
    
    setState(() {
      _isLoading = false;
      _statusMessage = '加载完成（仅UI展示）';
      // 模拟解析到数据
      _novelTitle = '示例小说标题';
      _novelAuthor = '示例作者';
      _bookId = '4170491';
    });
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
                    onPressed: _isLoading ? null : () {
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
                    color: Theme.of(context).colorScheme.inverseSurface.withAlpha(128),
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
                    color: Theme.of(context).colorScheme.surfaceContainerLowest,
                    child: SizedBox(
                      height: 400,
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              '目录展示区域（仅UI）',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 16),
                            Text('业务逻辑已移除')
                          ],
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
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        elevation: 0.0,
        child: Row(
          children: <Widget>[
            if (_novelTitle.isNotEmpty) ...[
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
              onPressed: _novelTitle.isNotEmpty && !_isTaskAdded
                  ? () {
                      setState(() {
                        _isTaskAdded = true;
                      });
                    }
                  : null,
              child: _novelTitle.isEmpty
                  ? const Text("等待開始")
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