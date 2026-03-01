import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:clipboard/clipboard.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:async';


class NovelExtractorPage extends StatefulWidget {
  const NovelExtractorPage({super.key});

  @override
  State<NovelExtractorPage> createState() => _NovelExtractorPageState();
}

class _NovelExtractorPageState extends State<NovelExtractorPage> {
  final TextEditingController _urlController = TextEditingController(
    text: 'https://www.ciweimao.com/chapter/114373635',
  );
  String _novelContent = '';
  bool _isLoading = false;
  String _statusMessage = '';
  
  // Windows专用WebView控制器
  late final WebviewController _webviewController;
  // 标记WebView是否初始化完成
  bool _webViewInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // 初始化Windows WebView控制器
    _webviewController = WebviewController();
    _initWebView();
  }

  /// 初始化Windows WebView
  Future<void> _initWebView() async {
    try {
      await _webviewController.initialize();
      _webviewController.loadingState.listen((state) {
        if (state == LoadingState.navigationCompleted) {}
      });
      
      setState(() {
        _webViewInitialized = true;
      });
    } catch (e) {
      setState(() {
        _statusMessage = '❌ WebView初始化失败：$e';
      });
    }
  }

  /// 【核心封装方法】提取小说内容 - 调用后直接返回小说内容字符串
  /// [url] 刺猬猫章节URL
  /// 返回值：小说内容字符串（失败时返回错误信息）
  Future<String> extractNovelContent(String url) async {
    // 1. 校验URL格式
    if (!_validateCiweimaoUrl(url)) {
      return '❌ URL格式错误！请输入类似：https://www.ciweimao.com/chapter/114373635 的链接';
    }

    // 2. 检查WebView初始化状态
    if (!_webViewInitialized) {
      return '❌ WebView尚未初始化完成，请稍候再试';
    }

    try {
      // 3. 加载URL
      await _webviewController.loadUrl(url);
      
      // 4. 等待页面渲染
      await Future.delayed(const Duration(seconds: 6));
      
      // 5. 获取页面HTML
      final dynamic result = await _webviewController.executeScript('document.documentElement.outerHTML');
      final String htmlContent = result?.toString() ?? '';
      
      if (htmlContent.isEmpty) {
        return '❌ 获取页面HTML失败，返回内容为空';
      }
      
      // 6. 解析提取内容
      return _extractNovelFromHtml(htmlContent);
    } catch (e) {
      return '❌ 提取失败：$e';
    }
  }

  /// 校验URL格式
  bool _validateCiweimaoUrl(String url) {
    if (url.isEmpty) return false;
    final regex = RegExp(r'^https://www\.ciweimao\.com/chapter/\d+$');
    return regex.hasMatch(url);
  }

  /// 从HTML中解析小说内容
  String _extractNovelFromHtml(String html) {
    try {
      final document = parse(html);
      
      final contentDiv = document.getElementById('J_BookRead');
      if (contentDiv == null) {
        return '❌ 未找到小说内容区域（J_BookRead），可能页面结构已变更';
      }

      final paragraphs = contentDiv.getElementsByClassName('chapter');
      if (paragraphs.isEmpty) {
        return '❌ 未找到章节内容（class=chapter），可能页面结构已变更';
      }

      final List<String> cleanContent = [];
      
      for (var p in paragraphs) {
        String text = p.text.trim();
        
        text = text
            .replaceAll('27J6IT', '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9，。！？；：""''（）()、《》【】\s]'), '')
            .trim();
        
        if (text.isNotEmpty && 
            text != '———' && 
            !p.classes.contains('author_say')) {
          cleanContent.add(text);
        }
      }

      if (cleanContent.isEmpty) {
        return '❌ 提取到的内容为空，可能需要登录后再试';
      }

      return cleanContent.join('\n\n');
    } catch (e) {
      return '❌ 解析失败：$e';
    }
  }

  /// 页面交互方法：调用封装的提取方法并更新UI
  Future<void> _fetchAndExtractNovel() async {
    setState(() {
      _isLoading = true;
      _novelContent = '';
      _statusMessage = '';
    });

    final url = _urlController.text.trim();
    
    // 调用封装的提取方法
    final content = await extractNovelContent(url);
    
    setState(() {
      _novelContent = content;
      _statusMessage = content.startsWith('❌') 
          ? content 
          : '✅ 提取成功！共 ${content.split('\n\n').length} 个段落';
      _isLoading = false;
    });
  }

  /// Windows剪贴板复制功能
  Future<void> _copyToClipboard() async {
    if (_novelContent.isEmpty) return;
    
    try {
      await FlutterClipboard.copy(_novelContent);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ 内容已复制到剪贴板'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ 复制失败：$e')),
        );
      }
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
      appBar: AppBar(
        title: const Text('Tracker'),
        actions: [
          if (_novelContent.isNotEmpty && !_isLoading)
            IconButton(
              icon: const Icon(Icons.copy),
              onPressed: _copyToClipboard,
              tooltip: '复制到剪贴板',
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _urlController,
                  decoration: InputDecoration(
                    labelText: '刺猬猫小说章节URL',
                    hintText: 'https://www.ciweimao.com/chapter/数字',
                    border: const OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(8)),
                    ),
                    prefixIcon: const Icon(Icons.link),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => _urlController.clear(),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  style: const TextStyle(fontSize: 16),
                  maxLines: 1,
                ),
                const SizedBox(height: 20),

                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: (_isLoading || !_webViewInitialized) ? null : _fetchAndExtractNovel,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 4,
                    ),
                    child: _isLoading
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              SizedBox(width: 16),
                              Text(
                                '正在提取内容...',
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          )
                        : !_webViewInitialized
                            ? const Text(
                                'WebView初始化中...',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                              )
                            : const Text(
                                '提取小说内容',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                              ),
                  ),
                ),
                const SizedBox(height: 16),

                if (_statusMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      _statusMessage,
                      style: TextStyle(
                        color: _statusMessage.startsWith('✅') ? Colors.green : Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),

                const Text(
                  'Result：',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Container(
                  height: 600,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.shade200,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      )
                    ],
                  ),
                  child: _novelContent.isEmpty
                      ? const Center(
                          child: Text(
                            '请输入有效的刺猬猫小说章节URL\n点击提取按钮获取内容',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            _novelContent,
                            style: const TextStyle(
                              fontSize: 16,
                              height: 1.8,
                              fontFamily: 'Microsoft YaHei',
                            ),
                            textAlign: TextAlign.justify,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
