import 'dart:ui';

import 'package:flutter/material.dart';

import 'converter_page.dart';
import 'preferences.dart';

class ConvertersPage extends StatefulWidget {
  const ConvertersPage({super.key});

  @override
  State<ConvertersPage> createState() => _ConvertersPageState();
}

class _ConvertersPageState extends State<ConvertersPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final List<String> _tabTitles = ['Ebook Convert', UserPreferences.instance.modules.contains(
                "txt_to_epub_maker",
              ) ? 'Txt To Epub' : null].whereType<String>().toList();

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
        appBar: AppBar(
          backgroundColor: Colors.transparent,

          title: TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: _tabTitles.map((title) {
            switch (title) {
              case 'Ebook Convert':
                return const ConverterPage();
              default:
                return Center(child: Text('仍在施工喵：$title'));
            }
          }).toList(),
        ),
      ),
    );
  }
}
