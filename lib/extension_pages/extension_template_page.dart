import 'package:flutter/material.dart';
import 'package:webview_windows/webview_windows.dart';
import 'dart:ui';

void main() {
  runApp(const A());
}

class A extends StatelessWidget {
  const A({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tmp Page',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const ExtensionTemplateWebView(
        url:
            'file:///E:/Things/Github/UnU-Novel-Toolbox/modules/example-extension/index.html',
      ),
    );
  }
}

class ExtensionTemplateWebView extends StatefulWidget {
  const ExtensionTemplateWebView({
    super.key,
    this.title,
    required this.url,
    this.alpha,
    this.enableBlur,
  });
  final String? title;
  final String url;

  final int? alpha;
  final bool? enableBlur;

  @override
  State<ExtensionTemplateWebView> createState() =>
      _ExtensionTemplateWebViewState();
}

class _ExtensionTemplateWebViewState extends State<ExtensionTemplateWebView> {
  final WebviewController _webViewController = WebviewController();
  String? _pageTitle;

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  Future<void> _initWebView() async {
    try {
      await _webViewController.initialize();
      await _webViewController.loadUrl(widget.url);

      _webViewController.loadingState.listen((state) {
        if (mounted) setState(() {});
      });

      _webViewController.title.listen((title) {
        if (mounted) {
          setState(() {
            _pageTitle = title;
          });
        }
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
    return BackdropFilter(
      filter: widget.enableBlur ?? false
          ? ImageFilter.blur(sigmaX: 10, sigmaY: 10)
          : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Theme.of(
            context,
          ).colorScheme.surface.withAlpha(widget.alpha ?? 255),
          title: Text(widget.title ?? _pageTitle ?? 'Loading...'),
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
      ),
    );
  }
}
