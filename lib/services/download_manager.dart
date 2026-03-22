import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:path/path.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:path/path.dart' as path;
import 'package:url_launcher/url_launcher.dart';

import '../preferences.dart';

// ========== 1. 刺猬猫内容提取工具（完全移除Isolate依赖） ==========
class cwm_NovelExtractor {
  late final WebviewController _webviewController;
  bool _webViewInitialized = false;

  Future<bool> initialize() async {
    try {
      // 仅在主线程初始化WebView（webview_windows不支持多线程）
      _webviewController = WebviewController();
      await _webviewController.initialize();
      _webViewInitialized = true;
      return true;
    } catch (e) {
      print('cwm_NovelExtractor初始化失败：$e');
      _webViewInitialized = false;
      return false;
    }
  }

  Future<String> getNovelContent(String url) async {
    if (!_validateCiweimaoUrl(url)) {
      return 'URL格式错误！请输入类似：https://www.ciweimao.com/chapter/114373635 的链接';
    }

    if (!_webViewInitialized) {
      return 'WebView尚未初始化完成，请先调用initialize()方法';
    }

    try {
      await _webviewController.loadUrl(url);

      // 优化：监听页面加载完成事件，替代固定延迟
      Completer<void> loadCompleter = Completer();
      StreamSubscription? loadSubscription;

      loadSubscription = _webviewController.loadingState.listen((state) {
        if (state == LoadingState.navigationCompleted) {
          loadCompleter.complete();
          loadSubscription?.cancel();
        }
      });

      // 5秒超时保护
      await loadCompleter.future.timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          loadSubscription?.cancel();
          throw TimeoutException('页面加载超时');
        },
      );

      final dynamic result = await _webviewController.executeScript(
        'document.documentElement.outerHTML',
      );
      final String htmlContent = result?.toString() ?? '';

      if (htmlContent.isEmpty) {
        return '获取页面HTML失败，返回内容为空';
      }

      // ========== 新增：付费章节检测逻辑 ==========
      final payCheckResult = _checkIfPaidChapter(htmlContent);
      if (payCheckResult != null) {
        return payCheckResult; // 返回付费提示
      }

      return _extractNovelFromHtml(htmlContent);
    } catch (e) {
      return '提取失败：$e';
    }
  }

  void dispose() {
    if (_webViewInitialized) {
      _webviewController.dispose();
      _webViewInitialized = false;
    }
  }

  bool _validateCiweimaoUrl(String url) {
    if (url.isEmpty) return false;
    final regex = RegExp(r'^https://www\.ciweimao\.com/chapter/\d+$');
    return regex.hasMatch(url);
  }

  // ========== 新增：付费章节检测方法 ==========
  String? _checkIfPaidChapter(String html) {
    try {
      final document = parse(html);
      // 查找包含付费信息的元素
      final heavyFontElements = document.getElementsByClassName('heavy-font');

      for (var element in heavyFontElements) {
        final bTag = element.querySelector('b');
        if (bTag != null) {
          // 提取数字部分（移除所有非数字字符）
          final text = bTag.text.replaceAll(RegExp(r'[^\d]'), '');
          if (text.isNotEmpty) {
            final coinNum = int.tryParse(text) ?? 0;
            if (coinNum > 0) {
              return '該章節是付費章節，不提供下載';
            }
          }
        }
      }

      // 备用方案：使用正则表达式直接匹配，提高兼容性
      final regExp = RegExp(r'购买本章\s*<b>\s*(\d+)\s*币</b>');
      final match = regExp.firstMatch(html);
      if (match != null) {
        final coinNum = int.tryParse(match.group(1)!) ?? 0;
        if (coinNum > 0) {
          return '該章節是付費章節，不提供下載';
        }
      }

      return null; // 不是付费章节
    } catch (e) {
      print('付费章节检查失败：$e');
      return null; // 检查失败时继续提取内容
    }
  }

  String _extractNovelFromHtml(String html) {
    try {
      final document = parse(html);
      final contentDiv = document.getElementById('J_BookRead');
      if (contentDiv == null) {
        return '未找到小说内容区域（J_BookRead），可能页面结构已变更';
      }

      // 清理干扰标签
      final allSpanTags = contentDiv.getElementsByTagName('span');
      for (var span in allSpanTags) span.remove();
      final pgidITags = contentDiv.querySelectorAll('i[data-pgid]');
      for (var iTag in pgidITags) iTag.remove();
      final numITags = contentDiv.querySelectorAll('i.J_Num, i.num');
      for (var iTag in numITags) iTag.remove();

      final paragraphs = contentDiv.getElementsByClassName('chapter');
      if (paragraphs.isEmpty) {
        return '未找到章节内容（class=chapter），可能页面结构已变更';
      }

      final List<String> cleanContent = [];
      for (var p in paragraphs) {
        String text = p.text.trim().replaceAll(RegExp(r'\s+'), ' ').trim();

        if (text.isNotEmpty &&
            text != '———' &&
            !p.classes.contains('author_say')) {
          cleanContent.add(text);
        }
      }

      if (cleanContent.isEmpty) {
        return '提取到的内容为空，可能需要登录后再试';
      }

      return cleanContent.join('\n\n');
    } catch (e) {
      return '解析失败：$e';
    }
  }
}

// ========== 2. 数据模型（关键修改：为TaskModel添加ValueNotifier） ==========
enum TaskType { ciweimao, jjwxc, yamibo }

enum DownloadTaskStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled, // 新增：取消状态
}

class NovelChapter {
  final String title;
  final String url;
  double progress;
  DownloadTaskStatus status;

  NovelChapter({
    required this.title,
    required this.url,
    this.progress = 0.0,
    this.status = DownloadTaskStatus.pending,
  });
}

class NovelVolume {
  final String volumeName;
  final List<NovelChapter> chapters;

  NovelVolume({required this.volumeName, required this.chapters});
}

class TaskModel {
  final TaskType taskType;
  final String coverUrl;
  final String novelAuthor;
  final String novelTitle;
  final List<NovelVolume> volumes;
  final bool isEpub;
  final String savePath;

  // 关键：添加ValueNotifier管理进度
  final ValueNotifier<double> progressNotifier;

  // 便捷访问：通过progress直接获取进度值
  double get progress => progressNotifier.value;

  TaskModel({
    required this.taskType,
    required this.coverUrl,
    required this.novelAuthor,
    required this.novelTitle,
    required this.volumes,
    required this.isEpub,
    required this.savePath,
  }) : progressNotifier = ValueNotifier(0.0);

  String get taskId => '${taskType}_${novelTitle}_${novelAuthor}'.replaceAll(
    RegExp(r'\s+'),
    '_',
  );

  // 计算总章节数
  int get totalChapterCount =>
      volumes.fold(0, (sum, vol) => sum + vol.chapters.length);

  // 释放资源（避免内存泄漏）
  void dispose() {
    progressNotifier.dispose();
  }
}

// ========== 下载管理器（重构为严格串行队列） ==========
class DownloadManager extends ChangeNotifier {
  String novelsSavePath = "C:\\";
  int processConcurrent = 3;

  // 任务队列：存储所有任务（等待/处理中/已完成）
  List<TaskModel> tasks = [];
  // 当前正在处理的任务（确保唯一）
  TaskModel? _currentProcessingTask;

  List<TaskModel> finishedTasks = [];

  final ValueNotifier<int> pendingTaskCount = ValueNotifier(0);

  static final DownloadManager instance = DownloadManager._internal();
  DownloadManager._internal();

  final StreamController<void> _taskChangedController =
      StreamController<void>.broadcast();
  bool _daemonRunning = false;
  final Map<String, Map<String, dynamic>> _taskProgress = {};

  // 重试间隔常量
  final int retryIntervalSeconds = 5;
  // 最大重试次数
  final int maxRetryCount = 300;

  // 暴露给UI的Stream和状态
  Stream<void> get taskChangedStream => _taskChangedController.stream;
  bool get isDaemonRunning => _daemonRunning;

  void _updatePendingTaskCount() {
    final count = tasks.length - finishedTasks.length;
    pendingTaskCount.value = count;
  }

  // 启动下载守护进程（仅负责调度队列）
  void startDaemon() {
    if (_daemonRunning) return;
    _daemonRunning = true;
    _scheduleNextTask(); // 启动任务调度
  }

  // 停止守护进程
  void stopDaemon() {
    _daemonRunning = false;
    _taskChangedController.close();
    _currentProcessingTask = null;
    // 释放所有任务资源
    for (var task in tasks) {
      task.dispose();
    }
    tasks.clear();
    pendingTaskCount.dispose();
    _taskProgress.clear();
  }

  /// 移除Windows路径中所有非法字符
  String removeWindowsInvalidPathChars(String input) {
    RegExp invalidCharsRegex = RegExp(r'[<>:"/\\|?*]');
    return input.replaceAll(invalidCharsRegex, '');
  }

  /// 带重试机制的小说提取方法
  Future<String> extractNovelWithRetry(
    cwm_NovelExtractor extractor,
    String url,
    String savePath,
    int index,
  ) async {
    int retryCount = 0;
    String content = "";

    while (retryCount < maxRetryCount) {
      // 检查：守护进程是否运行/任务是否被取消
      if (!_daemonRunning ||
          (_currentProcessingTask != null &&
              getTaskProgressById(_currentProcessingTask!.taskId)!['status'] ==
                  DownloadTaskStatus.cancelled.name)) {
        throw Exception("任务已被取消");
      }

      // 尝试提取内容
      content = await extractor.getNovelContent(url);

      // 检查是否提取成功
      if (!content.contains("提取失败")) {
        return content;
      }

      // 提取失败，记录日志并重试
      retryCount++;
      try {
        final uri = Uri.parse(url);
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (e) {
        print("打开URL失败: $e");
      }

      // 等待一段时间后重试
      await Future.delayed(Duration(seconds: retryIntervalSeconds));
    }

    // 达到最大重试次数，抛出异常
    final errorMsg = "章节 $index 提取失败，已重试 $maxRetryCount 次，URL: $url";
    throw Exception(errorMsg);
  }

  // 任务调度核心：找到下一个等待任务并处理
  Future<void> _scheduleNextTask() async {
    // 循环调度：守护进程运行中且有任务
    while (_daemonRunning && tasks.isNotEmpty) {
      // 1. 查找第一个等待状态的任务
      TaskModel? nextTask;
      try {
        nextTask = tasks.firstWhere(
          (task) =>
              getTaskProgressById(task.taskId)!['status'] ==
              DownloadTaskStatus.pending.name,
        );
      } catch (e) {
        // 无等待任务，退出循环
        break;
      }

      if (nextTask == null) break;

      // 2. 设置为当前处理任务并更新状态
      _currentProcessingTask = nextTask;
      _updateTaskProgress(nextTask, {
        'status': DownloadTaskStatus.downloading.name,
      });
      _taskChangedController.sink.add(null);

      try {
        // 3. 执行任务下载逻辑
        await _executeTask(nextTask);

        // 4. 任务完成：标记为已完成
        nextTask.progressNotifier.value = 1.0;
        _updateTaskProgress(nextTask, {
          'status': DownloadTaskStatus.completed.name,
          'progress': 1.0,
          'completed': nextTask.totalChapterCount,
        });
        print("任务完成：${nextTask.novelTitle}");
        //tasks.remove(nextTask);
        finishedTasks.add(nextTask);

        _updatePendingTaskCount();
      } catch (e) {
        // 5. 任务失败/取消：更新状态
        print("任务失败/取消：$e");
        if (e.toString().contains("任务已被取消") || e.toString().contains("任务已取消")) {
          _updateTaskProgress(nextTask, {
            'status': DownloadTaskStatus.cancelled.name,
            'error': '任务已取消',
            'progress': nextTask.progress,
          });
        } else {
          _updateTaskProgress(nextTask, {
            'status': DownloadTaskStatus.failed.name,
            'error': e.toString(),
            'progress': nextTask.progress,
          });
        }
      } finally {
        // 6. 清空当前处理任务
        _currentProcessingTask = null;
        _taskChangedController.sink.add(null);

        // 短暂延迟，避免CPU空转
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  /// 合并多个TXT文件到一个文件中
  ///
  /// [chapterTasks] - 章节任务列表，包含标题、文件路径、卷名
  ///
  /// [outputPath] - 输出文件的绝对路径 (例如: "C:\\output.txt")
  ///
  /// 返回值: 成功返回true，失败返回false
  Future<bool> mergeTxtFiles({
    required List<Map<String, String>> chapterTasks,
    required String outputPath,
  }) async {
    try {
      // 1. 按卷名分组章节
      final Map<String, List<Map<String, String>>> volChapters = {};

      for (var chapter in chapterTasks) {
        final vol = chapter['vol'] ?? '默认卷';
        final title = chapter['title'] ?? '未知章节';
        final savepath = chapter['savepath'] ?? '';

        // 过滤掉路径为空的无效章节
        if (savepath.isEmpty) continue;

        if (!volChapters.containsKey(vol)) {
          volChapters[vol] = [];
        }
        volChapters[vol]!.add({
          'title': title,
          'savepath': savepath,
          'vol': vol,
        });
      }

      // 2. 创建输出文件并写入内容
      final outputFile = File(outputPath);
      // 如果文件已存在，先清空
      if (await outputFile.exists()) {
        await outputFile.writeAsString('', mode: FileMode.write);
      }

      // 3. 遍历每个卷，写入卷标题和章节内容
      for (var entry in volChapters.entries) {
        final volName = entry.key;
        final chapters = entry.value;

        // 写入卷标题 (格式: ## 卷名 ##)
        await outputFile.writeAsString(
          '## $volName ##\n\n',
          mode: FileMode.append,
        );

        // 遍历该卷下的所有章节
        for (var chapter in chapters) {
          final chapterTitle = chapter['title']!;
          final chapterPath = chapter['savepath']!;

          // 写入章节标题 (格式: *# 章名 #*)
          await outputFile.writeAsString(
            '*# $chapterTitle #*\n\n',
            mode: FileMode.append,
          );

          // 读取并写入章节内容
          final chapterFile = File(chapterPath);
          if (await chapterFile.exists()) {
            final content = await chapterFile.readAsString();
            await outputFile.writeAsString(
              '$content\n\n',
              mode: FileMode.append,
            );
          } else {
            // 章节文件不存在时写入提示信息
            await outputFile.writeAsString(
              '【章节文件不存在: $chapterPath】\n\n',
              mode: FileMode.append,
            );
          }
        }

        // 卷之间添加分隔线
        await outputFile.writeAsString(
          '=' * 50 + '\n\n',
          mode: FileMode.append,
        );
      }

      print('TXT文件合并完成，输出路径: $outputPath');
      return true;
    } catch (e) {
      print('合并TXT文件出错: $e');
      return false;
    }
  }

  // 执行单个任务的核心下载逻辑
  Future<void> _executeTask(TaskModel task) async {
    String novelRootPath = path.join(
      novelsSavePath,
      removeWindowsInvalidPathChars(task.novelTitle).trim(),
    );
    Directory targetDir = Directory(novelRootPath);
    if (!await targetDir.exists()) {
      await targetDir.create(recursive: true);
    }

    // 獲取封面
    Dio dio = Dio();
    Response response = await dio.get(
      task.coverUrl,
      options: Options(responseType: ResponseType.bytes, followRedirects: true),
    );

    File imgFile = File(path.join(novelRootPath, 'Cover.png'));
    await imgFile.writeAsBytes(response.data);

    // 构建章节任务列表
    List<Map<String, String>> chapterTasks = [];

    for (final volume in task.volumes) {
      for (final chapter in volume.chapters) {
        chapterTasks.add({
          "vol": volume.volumeName,
          "title": chapter.title,
          "url": chapter.url,
          "savepath": path.join(
            novelRootPath,
            "Source",
            removeWindowsInvalidPathChars(volume.volumeName).trim(),
            "${removeWindowsInvalidPathChars(chapter.title).trim()}.txt",
          ),
        });
      }
    }

    if (chapterTasks.isEmpty) {
      throw Exception("任务无章节可下载");
    }

    /// 如果是刺蝟貓
    if (task.taskType == TaskType.ciweimao) {
      // 初始化提取器
      final extractor = cwm_NovelExtractor();
      await extractor.initialize();
      final double progressStep = 1.0 / chapterTasks.length;

      try {
        // 逐个下载章节
        for (int i = 0; i < chapterTasks.length; i++) {
          // 检查：任务是否被取消（取消则终止）
          if (getTaskProgressById(task.taskId)!['status'] ==
              DownloadTaskStatus.cancelled.name) {
            throw Exception("任务已被取消");
          }

          final chapter = chapterTasks[i];
          String content = await extractNovelWithRetry(
            extractor,
            chapter["url"]!,
            chapter["savepath"]!,
            i,
          );

          // 跳过付费章节（仍计算进度）
          if (content.contains("該章節是付費章節")) {
            // print("跳过付费章节：${chapter["savepath"]}");
            // task.progressNotifier.value += progressStep;
            // _updateTaskProgress(task, {
            //   'completed': i + 1,
            //   'progress': task.progress,
            //   'currentChapter': chapter["savepath"]!.split(path.separator).last,
            // });
            // continue;
            chapterTasks = chapterTasks.sublist(0, i);

            break;
          }

          // 保存章节内容
          final saveFile = File(chapter["savepath"]!);
          await Directory(saveFile.parent.path).create(recursive: true);
          await saveFile.writeAsString(content);

          // 更新进度
          task.progressNotifier.value += progressStep;
          _updateTaskProgress(task, {
            'completed': i + 1,
            'progress': task.progress,
            'currentChapter': chapter["savepath"]!.split(path.separator).last,
          });

          stdout.writeln(
            "已下载章节 ${i + 1}/${chapterTasks.length}：${chapter["savepath"]}",
          );
          stdout.flush();
        }
      } finally {
        extractor.dispose();
      }

      Map<String, dynamic> bookInfoMap = {
        "Title": task.novelTitle,
        "Author": task.novelAuthor,
        "BookId": task.hashCode.toString(),
        "CoverPath": imgFile.path,
        "Volumes": task.volumes.map((vol) {
          return {
            "Title": vol.volumeName,
            "Chapters": vol.chapters.map((chap) {
              return {
                "Title": chap.title,
                "FilePath": path.join(
                  novelRootPath,
                  "Source",
                  removeWindowsInvalidPathChars(vol.volumeName).trim(),
                  "${removeWindowsInvalidPathChars(chap.title).trim()}.txt",
                ),
              };
            }).toList(),
          };
        }).toList(),
      };

      File bookInfoFile = File(path.join(novelRootPath, 'BookInfo.json'));
      await bookInfoFile.writeAsString(jsonEncode(bookInfoMap));

      if (task.isEpub) {
        // TODO: EPUB生成逻辑
      } else {
        String outputPath = path.join(
          novelRootPath,
          "${removeWindowsInvalidPathChars(task.novelTitle).trim()}.txt",
        );
        bool _result = await mergeTxtFiles(
          chapterTasks: chapterTasks,
          outputPath: outputPath,
        );
        print(_result);
      }
    }

    /// 刺蝟貓結束
  }

  // 添加任务到等待队列（核心：仅添加，不中断当前任务）
  void addDownloadTask({
    required TaskType taskType,
    required String coverUrl,
    required String novelAuthor,
    required String novelTitle,
    required List<NovelVolume> volumes,
    required bool isEpub,
    required String savePath,
  }) {
    // 1. 创建新任务
    final newTask = TaskModel(
      taskType: taskType,
      coverUrl: coverUrl,
      novelAuthor: novelAuthor,
      novelTitle: novelTitle,
      volumes: volumes,
      isEpub: isEpub,
      savePath: savePath,
    );

    // 2. 更新保存路径
    if (novelsSavePath !=
        UserPreferences.instance.currentSettingsMap["download_root_path"]) {
      novelsSavePath =
          UserPreferences.instance.currentSettingsMap["download_root_path"];
    }

    // 3. 添加到任务队列（仅加入，不处理）
    tasks.add(newTask);
    _initTaskProgress(newTask);
    _updatePendingTaskCount();

    // 4. 通知UI刷新
    _taskChangedController.sink.add(null);

    // 5. 如果当前无任务处理且守护进程已启动，触发调度
    if (_daemonRunning && _currentProcessingTask == null) {
      _scheduleNextTask();
    }

    print("任务已加入等待队列：${newTask.novelTitle}，队列总数：${tasks.length}");
  }

  // 取消下载任务并从队列移除
  Future<void> cancelDownloadTask({
    required String taskId,
    bool deleteFiles = true,
  }) async {
    try {
      // 1. 查找目标任务
      final targetTask = tasks.firstWhere(
        (task) => task.taskId == taskId,
        orElse: () => throw Exception("未找到任务：$taskId"),
      );

      // 2. 更新状态为取消
      _updateTaskProgress(targetTask, {
        'status': DownloadTaskStatus.cancelled.name,
        'error': '任务已取消',
      });

      // 3. 如果是当前处理的任务，清空标记
      if (_currentProcessingTask == targetTask) {
        _currentProcessingTask = null;
      }

      // 4. 删除文件（如果需要）
      if (deleteFiles) {
        String novelRootPath = path.join(
          novelsSavePath,
          removeWindowsInvalidPathChars(targetTask.novelTitle).trim(),
        );
        Directory novelDir = Directory(novelRootPath);
        if (await novelDir.exists()) {
          await novelDir.delete(recursive: true);
          print("已删除任务文件：$novelRootPath");
        }
      }

      // 5. 释放资源并从队列移除
      targetTask.dispose();
      tasks.remove(targetTask);
      _taskProgress.remove(taskId);

      // 6. 通知UI刷新
      _taskChangedController.sink.add(null);

      // 7. 如果有等待任务，触发下一个任务调度
      if (_daemonRunning &&
          _currentProcessingTask == null &&
          tasks.isNotEmpty) {
        _scheduleNextTask();
      }

      print("任务已取消并移除：$taskId");
    } catch (e) {
      print("取消任务失败：$e");
      throw Exception("取消任务失败：$e");
    }
  }

  // 初始化任务进度
  void _initTaskProgress(TaskModel task) {
    final total = task.totalChapterCount;
    _taskProgress[task.taskId] = {
      'taskId': task.taskId,
      'novelTitle': task.novelTitle,
      'completed': 0,
      'total': total,
      'progress': 0.0,
      'currentChapter': '',
      'status': DownloadTaskStatus.pending.name,
      'error': '',
    };
  }

  // 更新任务进度（触发UI刷新）
  void _updateTaskProgress(TaskModel task, Map<String, dynamic> data) {
    if (!_taskProgress.containsKey(task.taskId)) {
      _initTaskProgress(task);
    }
    _taskProgress[task.taskId]!.addAll(data);
    _taskChangedController.sink.add(null); // 通知UI刷新
  }

  // 获取单个任务进度
  Map<String, dynamic> getTaskProgress(TaskModel task) {
    return _taskProgress[task.taskId] ??
        {
          'taskId': task.taskId,
          'novelTitle': task.novelTitle,
          'completed': 0,
          'total': task.totalChapterCount,
          'progress': task.progress,
          'currentChapter': '',
          'status': DownloadTaskStatus.pending.name,
          'error': '',
        };
  }

  // 通过ID获取任务进度
  Map<String, dynamic>? getTaskProgressById(String taskId) =>
      _taskProgress[taskId];

  // 保存章节为TXT文件（Windows兼容）
  static Future<void> _saveChapterToTxt(
    String saveDir,
    String title,
    String content,
  ) async {
    // 清理Windows非法文件名字符
    final safeTitle = title.replaceAll(RegExp(r'[\/:*?"<>|]'), '_').trim();
    final filePath = path.join(saveDir, '$safeTitle.txt');

    // 创建目录（不存在则创建）
    final dir = Directory(saveDir);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    // 写入文件（UTF-8编码）
    final file = File(filePath);
    final utf8 = Encoding.getByName('utf-8');
    if (utf8 == null) throw Exception('不支持UTF-8编码');
    await file.writeAsString(content, encoding: utf8);

    print('章节已保存：$filePath');
  }

  /// 根据小说标题查找对应的下载任务
  ///
  /// [novelTitle] 要查找的小说标题
  ///
  /// 返回值：如果找到匹配的任务，返回true；否则返回false
  bool hasTaskByNovelTitle(String novelTitle) {
    // 遍历任务队列查找匹配的标题
    for (var task in tasks) {
      // 使用trim()去除首尾空格，equalsIgnoreCase忽略大小写（可选，根据需求调整）
      if (task.novelTitle.trim() == novelTitle.trim()) {
        return true;
      }
    }

    // 同时检查已完成任务列表（如果需要）
    for (var task in finishedTasks) {
      if (task.novelTitle.trim() == novelTitle.trim()) {
        return true;
      }
    }

    return false;
  }
}
