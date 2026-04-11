import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:url_launcher/url_launcher.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: StaggeredGridView.countBuilder(
        crossAxisCount: 4,
        itemCount: 4,
        itemBuilder: (BuildContext context, int index) {
          switch (index) {
            case 0:
              return WelcomeCard(
                icon: Icons.home_max,
                title: const Text(
                  "歡迎",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
                ),
                content: const Text("即刻開始處理電子書~\n\n程式版本：Nightly 0.4"),
                actions: [
                  Image.asset("assets/img/Cirno.png", width: 256, height: 256),
                ],
              );
            case 1:
              return WelcomeCard(
                iconBackgroundColor: Theme.of(
                  context,
                ).colorScheme.secondaryContainer,
                iconForegroundColor: Theme.of(
                  context,
                ).colorScheme.onSecondaryContainer,
                icon: Icons.explore,
                title: const Text(
                  "瀏覽",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
                ),
                content: const Text("尋找電子書並使用下載器下載"),
                actions: [
                  FilledButton.tonal(
                    onPressed: () {},
                    child: const Text("前往下載器頁面"),
                  ),
                ],
              );
            case 2:
              return WelcomeCard(
                icon: Icons.person,
                title: const Text(
                  "本軟體的貢獻者們~",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
                ),
                content: Column(
                  children: [
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: const Text("DinixUse <Github>"),
                      subtitle: const Text("誰だって楽になりたいさ。"),
                      leading: Image.asset(
                        "assets/img/dinix2.png",
                        width: 36,
                        height: 36,
                      ),
                      onTap: () {
                        launchUrl(
                          Uri.parse("https://github.com/DinixUse"),
                        );
                      },
                    ),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: const Text("Dinix_NeverOSC <Bilibili>"),
                      subtitle: const Text("​電柱が続く夏空の下、君と歩いた記憶。"),
                      leading: Image.asset(
                        "assets/img/dinix1.png",
                        width: 36,
                        height: 36,
                      ),
                      onTap: () {
                        launchUrl(
                          Uri.parse("https://space.bilibili.com/1865480050"),
                        );
                      },
                    ),
                    ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      title: const Text("Sbqmyy <Github>"),
                      subtitle: const Text("No, I was just imagining what kind of flower would suit you."),
                      leading: Image.asset(
                        "assets/img/sbqmyy1.png",
                        width: 36,
                        height: 36,
                      ),
                      onTap: () {
                        launchUrl(
                          Uri.parse("https://github.com/Sbqmyy"),
                        );
                      },
                    ),
                  ],
                ),
              );
            case 3:
              return WelcomeCard(
                icon: Icons.settings,
                iconBackgroundColor: Theme.of(
                  context,
                ).colorScheme.tertiaryContainer,
                iconForegroundColor: Theme.of(
                  context,
                ).colorScheme.onTertiaryContainer,
                title: const Text(
                  "進行設定",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w400),
                ),
                content: const Text("高度客制化這個應用，爲了你自己~"),
                actions: [
                  FilledButton.tonal(
                    onPressed: () {},
                    child: const Text("前往設定"),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.tertiaryContainer,
                      foregroundColor: Theme.of(
                        context,
                      ).colorScheme.onTertiaryContainer,
                    ),
                  ),
                ],
              );
            default:
              return const SizedBox();
          }
        },
        staggeredTileBuilder: (int index) =>
            StaggeredTile.count(2, index.isEven ? 2 : 1),
        mainAxisSpacing: 4.0,
        crossAxisSpacing: 4.0,
      ),
    );
  }
}

class WelcomeCard extends StatelessWidget {
  const WelcomeCard({
    super.key,
    required this.icon,
    required this.content,
    this.title,
    this.actions,
    this.borderRadius,
    this.padding,
    this.backgroundColor,
    this.foregroundColor,
    this.iconBackgroundColor,
    this.iconForegroundColor,
  });

  final IconData icon;
  final Widget content;

  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? iconBackgroundColor;
  final Color? iconForegroundColor;
  final BorderRadius? borderRadius;
  final EdgeInsets? padding;
  final Widget? title;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: borderRadius ?? BorderRadius.circular(24),
      ),
      color: backgroundColor ?? Theme.of(context).colorScheme.surface,
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor:
                  iconBackgroundColor ??
                  Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                icon,
                color:
                    iconForegroundColor ??
                    Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ListTile(
                    title: Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: title,
                    ),
                    subtitle: content,
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 2,
                  ),

                  if (actions != null && actions!.isNotEmpty) ...[
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: actions!,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
