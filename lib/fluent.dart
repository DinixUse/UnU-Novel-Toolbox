import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:provider/provider.dart';

import 'downloader_page.dart';
import 'preferences.dart';
import 'services/download_manager.dart';
import 'main.dart';
import 'main_download_screen.dart';

import 'fluent_themeing.dart';
import 'package:flutter/material.dart' hide Colors, Image, Placeholder, Scaffold, Tab, TabBar, TabController, Text, IconButton;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  await flutter_acrylic.Window.initialize();
  await UserPreferences.instance.initializePreferences();

  WindowOptions windowOptions = const WindowOptions(
    size: Size(1100, 660),
    minimumSize: Size(1100, 660),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  DownloadManager.instance.startDaemon();
  runApp(MyFluentApp());
}

class MyFluentApp extends StatelessWidget {
  MyFluentApp({super.key});

  final _appTheme = AppTheme();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _appTheme,
      builder: (final context, final child) {
        final appTheme = context.watch<AppTheme>();
        return FluentApp(
          title: 'UnU Novel Toolbox',
          themeMode: appTheme.mode,
          darkTheme: FluentThemeData(
            brightness: Brightness.dark,
            accentColor: Colors.blue,
            visualDensity: appTheme.visualDensity,
            focusTheme: FocusThemeData(
              glowFactor: is10footScreen(context) ? 2.0 : 0.0,
            ),
            fontFamily: "Segoe UI",
          ),
          theme: FluentThemeData(
            accentColor: Colors.blue,
            visualDensity: appTheme.visualDensity,
            focusTheme: FocusThemeData(
              glowFactor: is10footScreen(context) ? 2.0 : 0.0,
            ),
            fontFamily: "Segoe UI",
          ),

          builder: (final context, final child) {
            return Directionality(
              textDirection: appTheme.textDirection,
              child: NavigationPaneTheme(
                data: NavigationPaneThemeData(
                  backgroundColor:
                      appTheme.windowEffect !=
                          flutter_acrylic.WindowEffect.disabled
                      ? Colors.transparent
                      : null,
                ),
                child: child!,
              ),
            );
          },
          home: const FluentHomePage(),
        );
      },
    );
  }
}

class FluentHomePage extends StatefulWidget {
  const FluentHomePage({super.key});

  @override
  State<FluentHomePage> createState() => _FluentHomePageState();
}

class _FluentHomePageState extends State<FluentHomePage> {
  int topIndex = 0;

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      transitionBuilder: (child, animation) => SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(animation),
        child: FadeTransition(opacity: animation, child: child),
      ),
      titleBar: TitleBar(
        endHeader: ValueListenableBuilder<int>(
                    valueListenable: DownloadManager.instance.pendingTaskCount,
                    builder: (context, count, child) {
                      // 只在 count > 0 時顯示數字
                      return Badge.count(
                        count: count > 0 ? count : 0,
                        isLabelVisible: count > 0, // 數量為0時隱藏標籤
                        child: IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const MainDownloadScreen(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.download_outlined),
                        ),
                      );
                    },
                  ),
        onDragStarted: () => windowManager.startDragging(),
        onDoubleTap: () async {
          final isMaximized = await windowManager.isMaximized();
          if (isMaximized) {
            windowManager.restore();
          } else {
            windowManager.maximize();
          }
        },

        icon: Image.asset("assets/img/Cirno.png", width: 24, height: 24),
        title: const Text('UnU Novel Toolbox'),
        captionControls: const WindowButtons(),
      ),

      pane: NavigationPane(
        size: NavigationPaneSize(openMaxWidth: 240),
        selected: topIndex,
        onChanged: (i) => setState(() => topIndex = i),
        displayMode: PaneDisplayMode.auto,
        items: [
          PaneItem(
            icon: Icon(FluentIcons.home),
            title: Text('Home'),
            body: Placeholder(),
          ),
          PaneItem(
            icon: Icon(FluentIcons.download),
            title: Text('Downloader'),
            body: const DownloaderPage(),
          ),
          PaneItem(
            icon: Icon(FluentIcons.transportation),
            title: Text('Converter'),
            body: Placeholder(),
          ),
        ],
        footerItems: [
          PaneItem(
            icon: Icon(FluentIcons.settings),
            title: Text('Settings'),
            body: const SettingsPage(),
          ),
        ],
      ),
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(final BuildContext context) {
    final theme = FluentTheme.of(context);

    return SizedBox(
      width: 138,
      height: 50,
      child: WindowCaption(
        brightness: theme.brightness,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}
