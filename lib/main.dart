import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:m3e_design/m3e_design.dart';

import 'services/download_manager.dart';
import 'main_download_screen.dart';
import 'downloader_page.dart';
import 'preferences.dart';
import 'welcome_page.dart';

import 'testing.dart';
import 'testing_2.dart';
import 'testing_3.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await UserPreferences.instance.initializePreferences();

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

Future<void> _saveWindowPosition() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final position = await windowManager.getPosition();
    final size = await windowManager.getSize();
    await prefs.setDouble('window_x', position.dx);
    await prefs.setDouble('window_y', position.dy);
    await prefs.setDouble('window_width', size.width);
    await prefs.setDouble('window_height', size.height);
  } catch (e) {
    debugPrint("保存窗口位置失败: $e");
  }
}

Future<void> _restoreWindowPosition() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final x = prefs.getDouble('window_x');
    final y = prefs.getDouble('window_y');
    final width = prefs.getDouble('window_width') ?? 1208;
    final height = prefs.getDouble('window_height') ?? 789;

    if (x != null && y != null) {
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
    _saveWindowPosition().then((_) => windowManager.destroy());
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UnU Novel Toolbox',
      theme: withM3ETheme(
        ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2196F3)),
        ),
      ),
      home: HomePage(),
    );
  }
}

// Tab 模型类
class AppTab {
  final String title;
  final IconData icon;
  final Widget page;

  const AppTab({required this.title, required this.icon, required this.page});
}

class HomePage extends StatefulWidget {
  HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  // Tab 配置列表
  final List<AppTab> _tabs = [
    const AppTab(title: "起始頁", icon: Icons.home, page: WelcomePage()),
    const AppTab(title: "下載器", icon: Icons.download, page: DownloaderPage()),
    const AppTab(
      title: "轉換工具",
      icon: Icons.conveyor_belt,
      page: Center(child: Text("轉換工具頁内容", style: TextStyle(fontSize: 24))),
    ),
    const AppTab(title: "設定", icon: Icons.settings, page: SettingsPage()),
    // const AppTab(
    //   title: "測試頁面",
    //   icon: Icons.toc_outlined,
    //   page: NovelExtractorPage(),
    // ),
  ];

  int _selectedIndex = 0;
  AnimationController? _animationController;
  Animation<Offset>? _slideAnimation;

  final double _itemHeight = 52;
  final double _itemSpacing = 4;

  @override
  void initState() {
    super.initState();
    _initAnimation();
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
      final ctrl = AnimationController(vsync: this, duration: Duration.zero)
        ..forward();
      _slideAnimation = Tween<Offset>(
        begin: Offset.zero,
        end: Offset.zero,
      ).animate(ctrl);
      _animationController = ctrl;
    }
  }

  @override
  void dispose() {
    _animationController?.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    _animationController?.reset();
    _animationController?.forward();
  }

  double get _selectedTop {
    return _selectedIndex * (_itemHeight + _itemSpacing);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final slideAnimation =
        _slideAnimation ??
        Tween<Offset>(begin: Offset.zero, end: Offset.zero).animate(
          AnimationController(vsync: this, duration: Duration.zero)..forward(),
        );

    return Scaffold(
      backgroundColor: Color.alphaBlend(
        scheme.primaryContainer.withOpacity(0.3),
        scheme.surfaceContainerLow,
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Opacity(
              opacity:
                  UserPreferences
                          .instance
                          .currentSettingsMap["scaffold_background_image_url"] ==
                      ""
                  ? 1.0
                  : UserPreferences
                        .instance
                        .currentSettingsMap["image_opacity"],
              child: Image.file(
                File(
                  UserPreferences
                      .instance
                      .currentSettingsMap["scaffold_background_image_url"],
                ),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox();
                },
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(8),
            child: Scaffold(
              backgroundColor: Colors.transparent,
              appBar: AppBar(
                leading: Container(
                  alignment: Alignment.center,
                  child: Image.asset(
                    "assets/img/Cirno.png",
                    width: 36,
                    height: 36,
                  ),
                ),
                scrolledUnderElevation: 0,
                surfaceTintColor: Colors.transparent,
                backgroundColor: Colors.transparent,
                title: const Text("UnU Novel Toolbox"),
                flexibleSpace: GestureDetector(
                  onPanStart: (_) => windowManager.startDragging(),
                ),
                actions: [
                  ValueListenableBuilder<int>(
                    valueListenable: DownloadManager.instance.pendingTaskCount,
                    builder: (context, count, child) {
                      // 只在 count > 0 時顯示數字
                      return Badge.count(
                        count: count > 0 ? count : 0,
                        isLabelVisible: count > 0, // 數量為0時隱藏標籤
                        child: IconButton.filledTonal(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MainDownloadScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_outlined),
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.tertiaryContainer,
                            foregroundColor: scheme.onTertiaryContainer,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 4),
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
                    style: IconButton.styleFrom(
                      backgroundColor: scheme.primaryContainer,
                      foregroundColor: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton.filled(
                    onPressed: () => windowManager.close(),
                    icon: Icon(Icons.close, color: scheme.onPrimary),
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
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 550),
                            curve: Curves.elasticOut,
                            top: _selectedTop,
                            left: 0,
                            right: 0,
                            height: _itemHeight,
                            child: IgnorePointer(
                              child: Ink(
                                decoration: BoxDecoration(
                                  borderRadius: const BorderRadius.all(
                                    Radius.circular(128),
                                  ),
                                  color: scheme.primaryContainer,
                                ),
                              ),
                            ),
                          ),

                          Column(
                            spacing: _itemSpacing,
                            children: List.generate(_tabs.length, (index) {
                              final tab = _tabs[index];
                              final selected = _selectedIndex == index;
                              return SizedBox(
                                height: _itemHeight,
                                child: ListTile(
                                  onTap: () => _onItemTapped(index),
                                  contentPadding: const EdgeInsets.only(
                                    left: 16,
                                    top: 2,
                                  ),
                                  leading: Icon(
                                    tab.icon,
                                    color: selected
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurface,
                                  ),
                                  title: Text(
                                    tab.title,
                                    style: TextStyle(
                                      color: selected
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(128),
                                  ),
                                  tileColor: Colors.transparent,
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    ),
                  ),
                  Expanded(
                    child: SlideTransition(
                      position: slideAnimation,
                      child: FadeTransition(
                        opacity: _animationController!,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 12, top: 8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: _tabs[_selectedIndex].page,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool dynamicColorEnabled =
      UserPreferences.instance.currentSettingsMap["dynamic_app_color"];
  bool blurEnabled = UserPreferences.instance.currentSettingsMap["enable_blur"];
  double imageOpacity =
      UserPreferences.instance.currentSettingsMap["image_opacity"];
  int uiAlpha = UserPreferences.instance.currentSettingsMap["ui_alpha"];

  final thumbIcon = WidgetStateProperty.resolveWith<Icon?>((
    Set<WidgetState> states,
  ) {
    if (states.contains(WidgetState.selected)) {
      return const Icon(Icons.check);
    }
    return const Icon(Icons.close);
  });

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: UserPreferences.instance.currentSettingsMap["enable_blur"] == true
          ? ImageFilter.blur(sigmaX: 10, sigmaY: 10)
          : ImageFilter.blur(sigmaX: 0, sigmaY: 0),
      child: Scaffold(
        backgroundColor:
            UserPreferences
                    .instance
                    .currentSettingsMap["scaffold_background_image_url"] ==
                ""
            ? Theme.of(context).colorScheme.surface
            : Theme.of(context).colorScheme.surface.withAlpha(
                UserPreferences.instance.currentSettingsMap["ui_alpha"],
              ),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              surfaceTintColor:
                  UserPreferences
                          .instance
                          .currentSettingsMap["scaffold_background_image_url"] ==
                      ""
                  ? Theme.of(context).colorScheme.surface
                  : Colors.transparent,
              backgroundColor:
                  UserPreferences
                          .instance
                          .currentSettingsMap["scaffold_background_image_url"] ==
                      ""
                  ? Theme.of(context).colorScheme.surface
                  : Colors.transparent,

              expandedHeight: 80.0,
              floating: true,
              pinned: true,
              snap: false,

              flexibleSpace: const FlexibleSpaceBar(
                title: Text('設定'),
                titlePadding: EdgeInsetsDirectional.only(start: 16, bottom: 16),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SettingsHeader(title: "外觀"),
                    SettingsTile(
                      position: TilePosition.first,
                      tileIcon: const Icon(Icons.color_lens),
                      title: "强調色",
                      subtitle: const Text("選擇應用强調色"),
                      tileColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      trailing: CircleAvatar(
                        backgroundColor: Color(
                          UserPreferences
                              .instance
                              .currentSettingsMap["app_color"],
                        ),
                      ),
                    ),
                    SettingsTile(
                      position: TilePosition.middle,
                      tileIcon: const Icon(Icons.image),
                      title: "背景圖片",
                      subtitle:
                          UserPreferences
                                  .instance
                                  .currentSettingsMap["scaffold_background_image_url"] ==
                              ""
                          ? null
                          : Text(
                              "${UserPreferences.instance.currentSettingsMap["scaffold_background_image_url"]}",
                            ),
                      tileColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                    ),
                    if (UserPreferences
                            .instance
                            .currentSettingsMap["scaffold_background_image_url"] !=
                        "") ...[
                      SettingsTile(
                        position: TilePosition.middle,
                        tileIcon: const Icon(Icons.opacity),
                        title: "圖片不透明度",
                        subtitle: Slider(
                          divisions: 10,
                          label: imageOpacity.toString(),
                          value: imageOpacity,
                          onChanged: (value) {
                            setState(() {
                              imageOpacity = value;
                            });
                          },
                        ),
                        tileColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                      ),
                      SettingsTile(
                        position: TilePosition.middle,
                        tileIcon: const Icon(Icons.umbrella_outlined),
                        title: "UI不透明度",
                        subtitle: Slider(
                          divisions: 255,
                          label: uiAlpha.toString(),
                          value: uiAlpha / 255.0,
                          onChanged: (value) {
                            setState(() {
                              uiAlpha = (value * 255).toInt();
                            });
                          },
                        ),
                        tileColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerLow,
                      ),
                    ],
                    SettingsTile(
                      position: TilePosition.middle,
                      tileIcon: const Icon(Icons.blur_circular),
                      title: "模糊效果",
                      tileColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      onTap: () => setState(() {
                        blurEnabled = !blurEnabled;
                      }),
                      trailing: Switch(
                        thumbIcon: thumbIcon,
                        value: blurEnabled,
                        onChanged: (val) {
                          setState(() {
                            blurEnabled = val;
                          });
                        },
                      ),
                    ),
                    SettingsTile(
                      position: TilePosition.last,
                      tileIcon: const Icon(Icons.auto_awesome),
                      title: "動態取色",
                      tileColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                      onTap: () => setState(() {
                        dynamicColorEnabled = !dynamicColorEnabled;
                      }),
                      trailing: Switch(
                        thumbIcon: thumbIcon,
                        value: dynamicColorEnabled,
                        onChanged: (val) {
                          setState(() {
                            dynamicColorEnabled = val;
                          });
                        },
                      ),
                    ),

                    const SizedBox(height: 24),
                    const SettingsHeader(title: "下載"),
                    SettingsTile(
                      position: TilePosition.single,
                      tileIcon: const Icon(Icons.folder_open),
                      title: "下載路徑",
                      subtitle:
                          UserPreferences
                                  .instance
                                  .currentSettingsMap["download_root_path"] !=
                              ""
                          ? Text(
                              UserPreferences
                                  .instance
                                  .currentSettingsMap["download_root_path"],
                            )
                          : null,
                      tileColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerLowest,
                    ),
                  ],
                ),
              ),
            ),

            // SliverList(
            //   delegate: SliverChildBuilderDelegate(
            //     (context, index) => ListTile(
            //       leading: const Icon(Icons.settings_outlined),
            //       title: Text('设置选项 ${index + 1}'),
            //       trailing: const Icon(Icons.arrow_forward_ios),
            //     ),
            //     childCount: 20,
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}

enum TilePosition { first, middle, last, single }

class SettingsHeader extends StatelessWidget {
  final String title;
  final Color? textColor;
  const SettingsHeader({super.key, required this.title, this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: textColor ?? Theme.of(context).colorScheme.secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsTile extends StatelessWidget {
  final TilePosition position;
  final Icon tileIcon;
  final String title;
  final Widget? subtitle;
  final VoidCallback? onTap;
  final Color? tileColor;
  final Widget? trailing;
  const SettingsTile({
    super.key,
    required this.position,
    required this.tileIcon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.tileColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: switch (position) {
        TilePosition.first => const EdgeInsets.only(bottom: 1),
        TilePosition.last => const EdgeInsets.only(top: 1),
        TilePosition.middle => const EdgeInsets.only(top: 1, bottom: 1),
        TilePosition.single => const EdgeInsets.only(top: 1, bottom: 1),
      },
      child: ListTile(
        subtitleTextStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: Theme.of(context).colorScheme.inverseSurface.withAlpha(192),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: switch (position) {
            TilePosition.first => const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            TilePosition.middle => const BorderRadius.all(Radius.circular(4)),
            TilePosition.last => const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
              bottomLeft: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            TilePosition.single => BorderRadius.circular(24),
          },
        ),
        tileColor: tileColor == null
            ? Colors.transparent
            : tileColor!.withAlpha(
                UserPreferences
                            .instance
                            .currentSettingsMap["scaffold_background_image_url"] ==
                        ""
                    ? 255
                    : UserPreferences.instance.currentSettingsMap["ui_alpha"],
              ),
        leading: tileIcon,
        title: Text(title),
        subtitle: subtitle,
        trailing: trailing,
        onTap: onTap ?? () {},
      ),
    );
  }
}

/* 
ListTile(
      shape: RoundedRectangleBorder(
        borderRadius: switch (position) {
          TilePosition.first => const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(4),
          ),
          TilePosition.middle => const BorderRadius.all(Radius.circular(4)),
          TilePosition.last => const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(4),
            bottomLeft: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          TilePosition.single => BorderRadius.circular(24),
        },
      ),
      tileColor: tileColor ?? Colors.transparent,
      leading: tileIcon,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap ?? () {
        
      },
    )
*/
