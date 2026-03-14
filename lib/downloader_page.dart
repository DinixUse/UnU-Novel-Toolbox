import 'package:flutter/material.dart';
import 'package:unu_novel_toolbox/preferences.dart';

import 'download_pages/ciweimao.dart';
import 'preferences.dart';

class DownloaderPage extends StatefulWidget {
  const DownloaderPage({super.key});

  @override
  State<DownloaderPage> createState() => _DownloaderPageState();
}

class _DownloaderPageState extends State<DownloaderPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabTitles = ['刺蝟貓', '晉江文學城'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor:
          UserPreferences
                  .instance
                  .currentSettingsMap["scaffold_background_image_url"] == ""
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surface.withAlpha(UserPreferences.instance.currentSettingsMap["ui_alpha"]),
        title: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
        ),
      ),

      body: TabBarView(
        controller: _tabController,
        children: _tabTitles.map((title) {
          if (title == "刺蝟貓") {
            return const cwm_NovelCatalogPage();
          } else {
            return const Center(child: Text("施工中"));
          }
        }).toList(),
      ),
    );
  }
}
