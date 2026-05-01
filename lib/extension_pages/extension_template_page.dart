import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tmp Page',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const FullScreenWebView(),
    );
  }
}

class FullScreenWebView extends StatefulWidget {
  const FullScreenWebView({super.key});

  @override
  State<FullScreenWebView> createState() => _FullScreenWebViewState();
}

class _FullScreenWebViewState extends State<FullScreenWebView> {
  final WebviewController _webViewController = WebviewController();

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      await _webViewController.initialize();
      await _webViewController.loadUrl('https://www.bing.com');

      _webViewController.loadingState.listen((state) {
        if (mounted) setState(() {});
      });
    } catch (e) {
      debugPrint('WebView 初始化失败: $e');
    }
  }

  @override
  void dispose() {
    _webViewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Example WebView'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            await _webViewController.goBack();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _webViewController.reload();
            },
          ),
        ],
      ),
      body: Webview(_webViewController),
    );
  }
}
