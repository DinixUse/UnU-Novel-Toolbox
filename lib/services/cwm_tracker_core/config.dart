// config.dart

import 'book_model.dart';
import 'tools.dart';

class AppConfig {
  // 单例模式
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  // 配置项
  ManualBookConfig manualBook = ManualBookConfig();
  BatchConfig batch = BatchConfig();
  CacheConfig cache = CacheConfig();
  HomePageConfig homePage = HomePageConfig();
  LogConfig log = LogConfig();

  String? textFolder;
  String? imageFolder;

  /// 初始化配置。如果目录中存在 `setting.yaml` 会尝试读取，否则
  /// 使用默认值（与 Python 版本一致）。
  void init() {
    // 目前我们不处理 yaml，全部采用内存默认值。
    // 未来可以添加 `package:yaml` 来解析文件。
  }

  /// 计算一些辅助字段（例如安全的文件名），并填充到 Book/Chapter 中。
  void calculateParams(Book book) {
    // 书籍层面
    // Book.safeName 在 getter 中已经处理，这里仅通过 id 赋值欣赏，
    // 并且为每章设置 bookId 和 safeTitle。
    for (var chapter in book.chapters) {
      chapter.bookId = book.id;
      chapter.safeTitle = Tools.sanitizeName(chapter.title ?? '');
    }

    // 初始化全局缓存路径，和 python 版本的行为保持一致
    if (cache.text) {
      textFolder = Tools.processString(cache.textFolder, book);
    }
    if (cache.image) {
      imageFolder = Tools.processString(cache.imageFolder, book);
    }
  }
}

class ManualBookConfig {
  bool enable = false;
  String jsonString = '';
}

class BatchConfig {
  bool enable = false;
  bool auto = false;
  List<String> queue = [];
}

class CacheConfig {
  bool text = false;
  bool image = false;
  String textFolder = '{bookName}';
  String imageFolder = '{bookName}/images';
}

class HomePageConfig {
  bool enable = false;
  String style = '书籍名称：{bookName}\n作者：{bookAuthor}\n简介：{bookDescription}';
}

class LogConfig {
  bool notFoundWarn = true;
}
