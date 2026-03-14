// ciweimao_downloader.dart
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

import 'book_model.dart';
import 'config.dart';
import 'request_utils.dart';
import 'file_utils.dart';
import 'tools.dart';
import 'decrypt_utils.dart';
import 'epub_utils.dart';

// 简易进度条类替代第三方库
class ProgressBar {
  final int total;
  final String prefix;
  int _current = 0;

  ProgressBar({required this.total, this.prefix = ''});

  void increment() {
    _current++;
    stdout.write('\r$prefix ${_current}/$total');
  }

  void complete() {
    stdout.writeln();
    stdout.writeln('$prefix 完成');
  }
}

class CiweimaoDownloader {
  final AppConfig _config = AppConfig();

  Future<void> run() async {
    _config.init();

    // 打印版权信息
    _printCopyrightInfo();

    // 初始化队列
    final queue = await _initQueue();

    // 处理每本书
    for (var url in queue) {
      await _processBook(url);
    }

    PrintUtils.opt("[OPT] 任意键退出程序...");
    stdin.readLineSync();
  }

  /// 对外公开的接口，可以从 UI 传入 URL 并执行
  Future<void> processBook(String url) async {
    _config.init();
    await _processBook(url);
  }

  void _printCopyrightInfo() {
    PrintUtils.info("本程序基于Zn90107UlKa/CiweimaoDownloader@github.com");
    PrintUtils.info("如果您是通过被售卖的渠道获得的本软件，请您立刻申请退款。");
    PrintUtils.info("仅供个人学习与技术研究");
    PrintUtils.info("禁止任何形式的商业用途");
    PrintUtils.info("所有内容版权归原作者及刺猬猫平台所有");
    PrintUtils.info("请在 24 小时内学习后立即删除文件");
    PrintUtils.info("作者不承担因不当使用导致的损失及法律后果");
  }

  Future<List<String>> _initQueue() async {
    final queue = <String>[];
    final rootFolder = Directory.current;

    if (_config.manualBook.enable) {
      PrintUtils.info("[INFO] 手动目录模式已开启");
      queue.add("1000000");
    } else if (!_config.batch.enable) {
      // 自动查找数字目录
      try {
        for (var entity in rootFolder.listSync()) {
          if (entity is Directory &&
              int.tryParse(path.basename(entity.path)) != null) {
            PrintUtils.warn("[INFO] 自动模式找到了以下目录：${path.basename(entity.path)}");
          }
        }
      } catch (e) {
        PrintUtils.err("[ERR] 自动寻找目录失败，原因是： $e");
      }

      // 输入URL或目录名
      PrintUtils.opt("[OPT] 输入你想下载的书籍Url或目录名字：");
      final input = stdin.readLineSync()?.trim() ?? '';
      if (input.isNotEmpty) queue.add(input);
    } else if (!_config.batch.auto) {
      queue.addAll(_config.batch.queue);
    } else {
      // 批量自动模式
      try {
        for (var entity in rootFolder.listSync()) {
          if (entity is Directory &&
              int.tryParse(path.basename(entity.path)) != null) {
            PrintUtils.warn("[INFO] 自动模式找到了以下目录：${path.basename(entity.path)}");
            queue.add(path.basename(entity.path));
          }
        }
      } catch (e) {
        PrintUtils.err("[ERR] 自动寻找目录失败，原因是： $e");
      }
    }

    return queue;
  }

  Future<void> _processBook(String url) async {
    // 每次处理之前将 key 目录下的文件名转换为章节 ID
    try {
      FileUtils.transformFilename('key');
    } catch (_) {}

    final book = Book();

    // 处理手动模式
    if (_config.manualBook.enable) {
      try {
        final bookJson = json.decode(_config.manualBook.jsonString);
        book.id = int.parse(bookJson["bookID"].toString());
        book.name = bookJson["bookName"];
        book.author = bookJson["authorName"];
        book.description = bookJson["bookDescription"];

        // 读取封面
        try {
          final coverFile = File(bookJson["coverPath"]);
          book.cover = coverFile.readAsBytesSync();
        } catch (e) {
          PrintUtils.err("[ERR] $e");
        }

        // 读取章节
        final chapterDir = Directory("${book.id}");
        if (chapterDir.existsSync()) {
          for (var file in chapterDir.listSync()) {
            if (file is File &&
                int.tryParse(path.basenameWithoutExtension(file.path)) !=
                    null) {
              final chapterId = int.parse(
                path.basenameWithoutExtension(file.path),
              );
              final title =
                  bookJson["contents"][chapterId.toString()] ??
                  chapterId.toString();

              book.chapters.add(
                Chapter(bookId: book.id, id: chapterId, title: title),
              );
            }
          }
        }
      } catch (e) {
        PrintUtils.err("[ERR] $e");
      }
    } else {
      // 非手动模式解析ID
      book.url = url;
      // 先尝试把整个字符串当成数字
      final idFromNumber = int.tryParse(url);
      if (idFromNumber != null) {
        book.id = idFromNumber;
      } else {
        final uri = Uri.parse(url);
        final pathSegments = uri.pathSegments;
        book.id = pathSegments.isNotEmpty
            ? int.tryParse(pathSegments.last) ?? 0
            : 0;
      }
    }

    // 验证ID
    if (book.id == null || book.id! <= 0) {
      PrintUtils.err("[ERR] 错误的输入：$url，这一项会被忽略");
      return;
    }

    // 处理加密文件
    FileUtils.removeNewlinesInEachFile(Directory("${book.id}"));

    // 获取书籍信息
    if (!_config.manualBook.enable) {
      final nameResult = await RequestUtils.getName(book);
      if (nameResult != 0) {
        throw Exception("[ERR] 无法获取书籍信息");
      }
      PrintUtils.info("[INFO] 获取到：标题: ${book.name}， 作者： ${book.author}");

      final contentsResult = await RequestUtils.getContents(book);
      if (contentsResult != 0) {
        PrintUtils.opt("[OPT][ERR] 无法获取目录，请稍后再试，按回车退出程序");
        exit(1);
      }
    }

    // 初始化缓存目录
    if (_config.cache.text) {
      try {
        _config.textFolder = Tools.processString(
          _config.cache.textFolder,
          book,
        );
        FileUtils.ensureDirectoryExists(_config.textFolder!);
      } catch (e) {
        PrintUtils.err("[ERR] 设置文件中，textFolder为无效地址，错误为$e");
      }
    }

    if (_config.cache.image) {
      try {
        _config.imageFolder = Tools.processString(
          _config.cache.imageFolder,
          book,
        );
        FileUtils.ensureDirectoryExists(_config.imageFolder!);
      } catch (e) {
        PrintUtils.err("[ERR] 设置文件中，imageFolder为无效地址，错误为$e");
      }
    }

    // 计算参数
    _config.calculateParams(book);

    // 删除旧的解密文件
    final decryptedTxt = File(book.decryptedTxtPath);
    if (decryptedTxt.existsSync()) {
      decryptedTxt.deleteSync(recursive: true);
    }

    // 解密并处理章节
    final progress = ProgressBar(
      total: book.chapters.length,
      prefix: PrintUtils.processingLabel("[PROCESSING] 解码中"),
    );

    for (var chapter in book.chapters) {
      progress.increment();

      if (!chapter.isVolIntro) {
        // 检查缓存
        final decryptedFile = File(chapter.decryptedPath);
        if (decryptedFile.existsSync()) {
          final txt = decryptedFile.readAsStringSync();
          chapter.content = txt;

          // 写入总文件
          decryptedTxt.writeAsStringSync(
            "${chapter.title}\n$txt\n\n",
            mode: FileMode.append,
          );
          continue;
        }

        // 读取密钥和加密内容
        final keyFile = File(chapter.keyPath);
        final encryptedFile = File(chapter.encryptedTxtPath);

        // 如果加密文件不存在，则视为未购买/缺失
        if (!encryptedFile.existsSync()) {
          if (_config.log.notFoundWarn) {
            PrintUtils.warn("[WARN] ${chapter.title} 文件缺失");
          }
          final txt = "本章未购买";
          chapter.content = txt;
          decryptedTxt.writeAsStringSync(
            "${chapter.title}\n$txt\n",
            mode: FileMode.append,
          );
          continue;
        }

        // 读取或解密内容
        String txt;
        try {
          if (keyFile.existsSync()) {
            final seed = keyFile.readAsStringSync();
            final encryptedTxt = encryptedFile.readAsStringSync();
            txt = DecryptUtils.decrypt(encryptedTxt, seed);
          } else {
            txt = encryptedFile.readAsStringSync();
          }
        } catch (e) {
          PrintUtils.err("[ERR] 读取/解密 ${chapter.encryptedTxtPath} 时失败：$e");
          continue;
        }

        chapter.content = txt;

        // 写入缓存（无需中断处理）
        if (_config.cache.text) {
          try {
            decryptedFile.writeAsStringSync(txt);
          } catch (e) {
            PrintUtils.err("[ERR] 写入缓存 ${chapter.decryptedPath} 失败：$e");
          }
        }

        // 写入总文件
        decryptedTxt.writeAsStringSync(
          "${chapter.title}\n$txt\n",
          mode: FileMode.append,
        );
      } else {
        // 处理卷介绍
        try {
          decryptedTxt.writeAsStringSync(
            "${chapter.title}\n\n",
            mode: FileMode.append,
          );
        } catch (e) {
          PrintUtils.err("[ERR] 保存 ${chapter.encryptedTxtPath} 时发生错误：$e");
          continue;
        }
      }
    }

    progress.complete();

    // 输出结果
    PrintUtils.info("[INFO] txt文件已生成在：${book.safeName}");
    PrintUtils.info("[INFO] 正在打包Epub...");

    // 添加主页章节
    if (_config.homePage.enable) {
      PrintUtils.warn("[INFO] 检测到书籍主页选项打开");
      final homeChapter = Chapter(
        bookId: book.id,
        id: 0,
        title: book.name ?? '',
        isVolIntro: false,
      );
      homeChapter.content = Tools.processString(_config.homePage.style, book);
      book.chapters.insert(0, homeChapter);
    }

    // 生成EPUB
    try {
      await EpubUtils.generateEpub(book, "${book.safeName}.epub");
      PrintUtils.info("[INFO] EPUB 生成成功：${book.safeName}.epub");
    } catch (e) {
      PrintUtils.err("[ERR] EPUB 生成失败: $e");
    }
  }
}
