import 'package:flutter/material.dart';
//import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'testing.dart';
import 'testing_2.dart';
import 'downloader_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //await LiquidGlassWidgets.initialize();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // 定义页面列表
  final List<Widget> _pages = [
    const Center(child: Text("起始頁内容", style: TextStyle(fontSize: 24))),
    const DownloaderPage(),
    const Center(child: Text("設定页面内容", style: TextStyle(fontSize: 24))),
    
    //const NovelExtractorPage(),
    const NovelCatalogPage(),
    const Center(child: Text("其他页面", style: TextStyle(fontSize: 24))),
  ];

  int _selectedIndex = 0;
  // 可空动画控制器
  AnimationController? _animationController;
  Animation<Offset>? _slideAnimation;

  @override
  void initState() {
    super.initState();
    // 初始化动画
    _initAnimation();
    // 首次进入播放一次动画
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _animationController?.forward();
    });
  }

  void _initAnimation() {
    try {
      _animationController = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      );

      _slideAnimation =
          Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
            CurvedAnimation(
              parent: _animationController!,
              curve: Curves.easeOutCubic,
            ),
          );
    } catch (e) {
      final fallbackController = AnimationController(
        vsync: this,
        duration: Duration.zero,
      );
      fallbackController.forward();

      _slideAnimation = Tween<Offset>(begin: Offset.zero, end: Offset.zero)
          .animate(
            CurvedAnimation(parent: fallbackController, curve: Curves.linear),
          );
      _animationController = fallbackController;
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    if (_animationController != null) {
      _animationController!.reset();
      _animationController!.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final slideAnimation =
        _slideAnimation ??
        Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
          CurvedAnimation(
            parent: AnimationController(vsync: this, duration: Duration.zero)
              ..forward(),
            curve: Curves.linear,
          ),
        );

    final animationController =
        _animationController ??
              AnimationController(
                vsync: this,
                duration: const Duration(milliseconds: 300),
              )
          ..forward();

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Scaffold(
          appBar: AppBar(
            scrolledUnderElevation: 0,
            surfaceTintColor: Theme.of(context).colorScheme.surface,
            backgroundColor: Theme.of(context).colorScheme.surface,
            title: const Text("UnU Novel Toolbox"),
            flexibleSpace: GestureDetector(
              onPanStart: (_) async => await windowManager.startDragging(),
              child: Container(color: Colors.transparent),
            ),
            actions: [
              IconButton.filledTonal(
                onPressed: () => windowManager.minimize(),
                icon: const Icon(Icons.minimize),
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                onPressed: () async => await windowManager.isMaximized()
                    ? windowManager.unmaximize()
                    : windowManager.maximize(),
                icon: const Icon(Icons.crop_square_outlined),
              ),
              const SizedBox(width: 4),
              IconButton.filled(
                onPressed: () => windowManager.close(),
                icon: Icon(
                  Icons.close,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ],
            actionsPadding: const EdgeInsets.only(right: 8),
          ),
          body: Row(
            children: [
              SizedBox(
                width: 256,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    spacing: 4,
                    children: [
                      ListTile(
                        onTap: () =>
                            _selectedIndex == 0 ? null : _onItemTapped(0),
                        contentPadding: const EdgeInsets.only(
                          top: 4,
                          bottom: 4,
                          left: 16,
                        ),
                        leading: const Icon(Icons.home),
                        title: const Text("起始頁"),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(128)),
                        ),
                        tileColor: _selectedIndex == 0
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        textColor: _selectedIndex == 0
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      ListTile(
                        onTap: () =>
                            _selectedIndex == 1 ? null : _onItemTapped(1),
                        contentPadding: const EdgeInsets.only(
                          top: 4,
                          bottom: 4,
                          left: 16,
                        ),
                        leading: const Icon(Icons.download),
                        title: const Text("下載器"),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(128)),
                        ),
                        tileColor: _selectedIndex == 1
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        textColor: _selectedIndex == 1
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                      ListTile(
                        onTap: () =>
                            _selectedIndex == 2 ? null : _onItemTapped(2),
                        contentPadding: const EdgeInsets.only(
                          top: 4,
                          bottom: 4,
                          left: 16,
                        ),
                        leading: const Icon(Icons.settings),
                        title: const Text("設定"),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(128)),
                        ),
                        tileColor: _selectedIndex == 2
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        textColor: _selectedIndex == 2
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      ),

                      ListTile(
                        onTap: () =>
                            _selectedIndex == 3 ? null : _onItemTapped(3),
                        contentPadding: const EdgeInsets.only(
                          top: 4,
                          bottom: 4,
                          left: 16,
                        ),
                        leading: const Icon(Icons.toc_outlined),
                        title: const Text("測試頁面"),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(128)),
                        ),
                        tileColor: _selectedIndex == 3
                            ? Theme.of(context).colorScheme.primaryContainer
                            : null,
                        textColor: _selectedIndex == 3
                            ? Theme.of(context).colorScheme.onPrimaryContainer
                            : Theme.of(context).colorScheme.onSurface,
                      ),
                    ],
                  ),
                ),
              ),

              Expanded(
                child: SlideTransition(
                  position: slideAnimation,
                  child: FadeTransition(
                    opacity: animationController,
                    child: _pages[_selectedIndex],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
