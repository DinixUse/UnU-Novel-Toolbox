import 'dart:io';

import 'package:flutter/material.dart';
//import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/download_manager.dart';

import 'testing.dart';
import 'testing_2.dart';
import 'downloader_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //await LiquidGlassWidgets.initialize();
  await windowManager.ensureInitialized();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1208, 789),
    minimumSize: Size(1208, 789),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await _restoreWindowPosition();

    await windowManager.show();
    await windowManager.focus();
  });

  windowManager.addListener(MyWindowListener());

  DownloadManager.instance.startDaemon();

  runApp(const MyApp());
}

// 保存窗口位置和尺寸到本地
Future<void> _saveWindowPosition() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    // 获取当前窗口的位置（x, y）和尺寸（width, height）
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();

    // 保存到本地
    await prefs.setDouble('window_x', position.dx);
    await prefs.setDouble('window_y', position.dy);
    await prefs.setDouble('window_width', size.width);
    await prefs.setDouble('window_height', size.height);
  } catch (e) {
    debugPrint("保存窗口位置失败: $e");
  }
}

// 从本地恢复窗口位置和尺寸
Future<void> _restoreWindowPosition() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    // 读取本地保存的值（带默认值，首次启动用默认值）
    final x = prefs.getDouble('window_x');
    final y = prefs.getDouble('window_y');
    final width = prefs.getDouble('window_width') ?? 1208;
    final height = prefs.getDouble('window_height') ?? 789;

    // 如果有保存的位置，恢复位置；否则保持居中
    if (x != null && y != null) {
      // 先设置尺寸，再设置位置（避免尺寸异常导致位置偏移）
      await windowManager.setSize(Size(width, height));
      await windowManager.setPosition(Offset(x, y));
    }
  } catch (e) {
    debugPrint("恢复窗口位置失败: $e");
  }
}

class MyWindowListener extends WindowListener {
  @override
  void onWindowClose() {
    // 保存位置完成后再销毁窗口
    _saveWindowPosition().then((_) => windowManager.destroy());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UnU Novel Toolbox',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
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

    const NovelExtractorPage(),
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
      backgroundColor: Color.alphaBlend(
        Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        Theme.of(context).colorScheme.surfaceContainerLow,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            leading: Container(
              alignment: Alignment.center,
              child: Image.asset("assets/img/Cirno.png", width: 36, height: 36),
            ),
            scrolledUnderElevation: 0,
            surfaceTintColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            title: const Text("UnU Novel Toolbox"),
            flexibleSpace: GestureDetector(
              onPanStart: (_) async => await windowManager.startDragging(),
              child: Container(color: Colors.transparent),
            ),
            actions: [
              Stack(
                children: [
                  IconButton.filledTonal(
                    onPressed: () {
                      // Navigator.push(
                      //   context,
                      //   MaterialPageRoute(
                      //     builder: (context) => const AllDownloadTasksPage(),
                      //   ),
                      // );
                    },
                    icon: const Icon(Icons.download_outlined),
                    style: IconButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.tertiaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 4),
              IconButton.filledTonal(
                // style: IconButton.styleFrom(
                //   backgroundColor: Theme.of(
                //     context,
                //   ).colorScheme.tertiaryContainer,
                //   foregroundColor: Theme.of(
                //     context,
                //   ).colorScheme.onTertiaryContainer,
                // ),
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
                onPressed: () async {
                  //await _saveWindowPosition();
                  windowManager.close();
                },
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
                    child: Padding(
                      padding: const EdgeInsets.only(left: 12, top: 8),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.all(
                          Radius.circular(8),
                        ),
                        child: _pages[_selectedIndex],
                      ),
                    ),
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
