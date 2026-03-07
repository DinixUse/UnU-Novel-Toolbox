import '../download_pages/ciweimao.dart';

import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:webview_windows/webview_windows.dart';
import 'dart:async';

/// 刺猬猫小说内容提取工具类
/// 提供初始化和提取小说内容的方法，可在任意地方调用
class cwm_NovelExtractor {
  // Windows专用WebView控制器
  late final WebviewController _webviewController;
  // 标记WebView是否初始化完成
  bool _webViewInitialized = false;

  /// 【初始化方法】必须先调用此方法完成初始化，才能提取内容
  /// 返回值：初始化成功返回true，失败返回false
  Future<bool> initialize() async {
    try {
      _webviewController = WebviewController();
      await _webviewController.initialize();
      _webviewController.loadingState.listen((state) {
        if (state == LoadingState.navigationCompleted) {}
      });
      _webViewInitialized = true;
      return true;
    } catch (e) {
      print('cwm_NovelExtractor初始化失败：$e');
      _webViewInitialized = false;
      return false;
    }
  }

  /// 【获取小说内容方法】提取指定URL的小说内容
  /// [url] 刺猬猫章节URL（格式：https://www.ciweimao.com/chapter/数字）
  /// 返回值：成功返回小说内容字符串，失败返回错误信息字符串
  Future<String> getNovelContent(String url) async {
    // 1. 校验URL格式
    if (!_validateCiweimaoUrl(url)) {
      return 'URL格式错误！请输入类似：https://www.ciweimao.com/chapter/114373635 的链接';
    }

    // 2. 检查WebView初始化状态
    if (!_webViewInitialized) {
      return 'WebView尚未初始化完成，请先调用initialize()方法';
    }

    try {
      // 3. 加载URL
      await _webviewController.loadUrl(url);
      
      // 4. 等待页面渲染（可根据网络情况调整时长）
      await Future.delayed(const Duration(seconds: 6));
      
      // 5. 获取页面HTML
      final dynamic result = await _webviewController.executeScript('document.documentElement.outerHTML');
      final String htmlContent = result?.toString() ?? '';
      
      if (htmlContent.isEmpty) {
        return '获取页面HTML失败，返回内容为空';
      }
      
      // 6. 解析提取内容
      return _extractNovelFromHtml(htmlContent);
    } catch (e) {
      return '提取失败：$e';
    }
  }

  /// 释放资源（建议在不用时调用，避免内存泄漏）
  void dispose() {
    if (_webViewInitialized) {
      _webviewController.dispose();
      _webViewInitialized = false;
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
        return '未找到小说内容区域（J_BookRead），可能页面结构已变更';
      }

      final paragraphs = contentDiv.getElementsByClassName('chapter');
      if (paragraphs.isEmpty) {
        return '未找到章节内容（class=chapter），可能页面结构已变更';
      }

      final List<String> cleanContent = [];
      
      for (var p in paragraphs) {
        String text = p.text.trim();
        
        // 清理文本中的无用字符和特殊符号
        text = text
            .replaceAll('27J6IT', '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'[^\u4e00-\u9fa5a-zA-Z0-9，。！？；：""''（）()、《》【】\s]'), '')
            .trim();
        
        // 过滤空内容和作者说
        if (text.isNotEmpty && 
            text != '———' && 
            !p.classes.contains('author_say')) {
          cleanContent.add(text);
        }
      }

      if (cleanContent.isEmpty) {
        return '提取到的内容为空，可能需要登录后再试';
      }

      return cleanContent.join('\n\n');
    } catch (e) {
      return '解析失败：$e';
    }
  }
}


class cwm_DownloadManager {
  void startDownload(
    String coverUrl,
    String novelAuthor,
    String novelTitle,
    List<cwm_NovelVolume> chapters,
    bool isEpub
  ) {
    
  }
}
