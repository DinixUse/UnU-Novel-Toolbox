import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_shapes/material_shapes.dart'; // 导入正确的形状库

class NovelConverterSplashScreen extends StatefulWidget {
  const NovelConverterSplashScreen({super.key});

  @override
  State<NovelConverterSplashScreen> createState() =>
      _NovelConverterSplashScreenState();
}

class _NovelConverterSplashScreenState extends State<NovelConverterSplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // 初始化动画
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.elasticOut,
    );

    _slideAnimation =
        Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: const Offset(0, 0),
        ).animate(
          CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
        );

    // 启动动画序列
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _fadeController.forward();
      Future.delayed(const Duration(milliseconds: 200), () {
        _slideController.forward();
      });
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 根据屏幕尺寸计算形状大小
  double _getShapeSize(double screenWidth, double ratio) {
    return screenWidth * ratio;
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: Stack(
        children: [
          // ===== 使用material_shapes的几何形状色块 =====
          // 1. Pill形状（胶囊形）- 文件下载按钮风格
          Positioned(
            top: -_getShapeSize(size.width, 0.1),
            right: -_getShapeSize(size.width, 0.1),
            child: AnimatedBuilder(
              animation: _scrollController,
              builder: (context, child) {
                final offset = _scrollController.hasClients
                    ? _scrollController.offset * 0.0008
                    : 0.0;

                return Transform.translate(
                  offset: Offset(offset * 15, offset * 10),
                  child: child,
                );
              },
              child: MaterialShapes.pill(
                size: _getShapeSize(size.width, 0.7),
                color: colorScheme.primary.withOpacity(0.15),
                isStroked: false, // 填充色块（无描边）
              ),
            ),
          ),

          Positioned(
            bottom: size.height * 0.3,
            right: size.width * 0.2,
            child: Transform.rotate(
              angle: 0.15,
              child: MaterialShapes.fourLeafClover(
                size: _getShapeSize(size.width, 0.1),
                color: colorScheme.tertiary,
                isStroked: false,
              ),
            ),
          ),

          Positioned(
            top: size.height * 0.25,
            right: size.width * 0.4,
            child: MaterialShapes.circle(
              size: _getShapeSize(size.width, 0.04),
              color: colorScheme.primary.withOpacity(0.1),
              isStroked: false,
            ),
          ),

          SizedBox(
            height: size.height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 顶部留白
                  SizedBox(height: size.height * 0.2),

                  // 品牌标识（小说格式转换工具箱）
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'UnU Novel Toolbox',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.onBackground,
                            letterSpacing: 1.5,
                          ),
                        ),
                        Text(
                          'By UnU & Ecnu',
                          style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w800,
                            color: colorScheme.primary,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // 核心内容（滑动动画）
                  SlideTransition(
                    position: _slideAnimation,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '下載 · 轉換 · 傳送',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w500,
                            color: colorScheme.onBackground.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '多合一小説工具箱',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onBackground,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '支持TXT、EPUB、MOBI等多格式互轉，\n快捷下載網路小説。\n\n請忽略這些奇怪的表述和設計畢竟這個頁面因爲懶得設計所以交給了人工智能（捂臉）',
                          style: TextStyle(
                            fontSize: 16,
                            color: colorScheme.onBackground.withOpacity(0.6),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // 底部信息
                  const Align(
                    alignment: Alignment.bottomRight,
                    child: SizedBox(),
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
