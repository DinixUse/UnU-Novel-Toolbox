import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart' as dom;
import 'package:path/path.dart';
import 'package:webview_windows/webview_windows.dart';
import 'package:path/path.dart' as path;

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

// ========== 2. 数据模型（保持不变） ==========
enum TaskType { ciweimao, jjwxc, yamibo }

enum DownloadTaskStatus {
  pending,
  downloading,
  paused,
  completed,
  failed,
  cancelled,
}

class cwm_NovelChapter {
  final String title;
  final String url;
  double progress;
  DownloadTaskStatus status;

  cwm_NovelChapter({
    required this.title,
    required this.url,
    this.progress = 0.0,
    this.status = DownloadTaskStatus.pending,
  });
}

class cwm_NovelVolume {
  final String volumeName;
  final List<cwm_NovelChapter> chapters;

  cwm_NovelVolume({required this.volumeName, required this.chapters});
}

class TaskModel {
  final TaskType taskType;
  final String coverUrl;
  final String novelAuthor;
  final String novelTitle;
  final List<cwm_NovelVolume> volumes;
  final bool isEpub;
  final String savePath;

  TaskModel({
    required this.taskType,
    required this.coverUrl,
    required this.novelAuthor,
    required this.novelTitle,
    required this.volumes,
    required this.isEpub,
    required this.savePath,
  });

  String get taskId => '${taskType}_${novelTitle}_${novelAuthor}'.replaceAll(
    RegExp(r'\s+'),
    '_',
  );
}

// ========== 下载管理器 ==========
class DownloadManager extends ChangeNotifier {
  final ValueNotifier<double> taskProgress = ValueNotifier(0.0);

  String novelsSavePath = "C:\\";
  int processConcurrent = 3;

  List<TaskModel> tasks = [];
  static final DownloadManager instance = DownloadManager._internal();
  DownloadManager._internal(); // 移除Isolate初始化代码

  final StreamController<void> _taskChangedController =
      StreamController<void>.broadcast();
  bool _daemonRunning = false;
  final Map<String, Map<String, dynamic>> _taskProgress = {};

  // 关键：限制并发下载数（避免创建过多WebView导致崩溃）
  final int _maxConcurrent = 2;
  int _currentActive = 0;

  // 暴露给UI的Stream和状态
  Stream<void> get taskChangedStream => _taskChangedController.stream;
  bool get isDaemonRunning => _daemonRunning;

  // 启动下载守护进程
  void startDaemon() {
    if (_daemonRunning) return;
    _daemonRunning = true;
    _processTasks(); // 开始处理任务队列
  }

  // 停止守护进程
  void stopDaemon() {
    _daemonRunning = false;
    _taskChangedController.close();
  }

  /// 移除Windows路径中所有非法字符
  /// Windows路径非法字符包括：< > : " / \ | ? *
  String removeWindowsInvalidPathChars(String input) {
    // 定义Windows路径非法字符的正则表达式（转义特殊字符）
    // 正则中需要转义的字符：\ " /，其他字符直接列出
    RegExp invalidCharsRegex = RegExp(r'[<>:"/\\|?*]');

    // 将所有非法字符替换为空字符串
    return input.replaceAll(invalidCharsRegex, '');
  }

  // 任务处理核心逻辑（纯主线程）
  Future<void> _processTasks() async {
    while (_daemonRunning && tasks.isNotEmpty) {
      // 控制并发数
      if (_currentActive < _maxConcurrent) {
        final task = tasks.removeAt(0);
        _currentActive++;

        // 异步执行单个任务（不阻塞队列处理）
        // _downloadSingleTask(task).whenComplete(() {
        //   _currentActive--;
        //   // 任务完成后继续处理下一个
        //   if (_daemonRunning) _processTasks();
        // });

        String novelRootPath = path.join(
          novelsSavePath,
          removeWindowsInvalidPathChars(task.novelTitle).trim(),
        );
        Directory targetDir = Directory(novelRootPath);
        if (!await targetDir.exists()) {
          await targetDir.create(recursive: true);
        }

        File _infoJson = File(path.join(novelRootPath, "BookInfo.json"));
        Map<String, dynamic> _infoMap = {};
        List<Map<String, String>> _taskList = [];

        for (final _volume in task.volumes) {
          for (final _chapter in _volume.chapters) {
            _taskList.add({
              "url": _chapter.url,
              "savepath": path.join(
                novelRootPath,
                removeWindowsInvalidPathChars(_volume.volumeName).trim(),
                "${removeWindowsInvalidPathChars(_chapter.title).trim()}.txt",
              ),
            });
          }
        }

        _infoMap["tasks"] = _taskList;
        // _infoMap[""] = ""

        await _infoJson.writeAsString(jsonEncode(_infoMap));

        // 1. 基础边界校验
        if (_taskList.isEmpty || processConcurrent <= 0) {
          print("错误：任务列表为空或并发数无效");
          return;
        }

        final int totalTasks = _taskList.length;
        final int lastIndex = totalTasks - 1; // 闭区间的最大有效索引

        // 2. 计算每个分片的基础长度（向上取整，避免任务遗漏）
        int singleTaskCount = (totalTasks / processConcurrent).ceil();
        List<(int, int)> taskRanges = [];

        for (int i = 0; i < processConcurrent; i++) {
          // 闭区间：start 是当前分片的起始索引
          int start = i * singleTaskCount;

          // 闭区间：end 初始为下一分片起始索引-1（保证闭区间连续）
          int end = (i + 1) * singleTaskCount - 1;

          // 3. 闭区间关键适配：
          // - 最后一个分片的end取最大有效索引
          // - 若start已超过最大索引，直接终止循环（避免空分片）
          if (start > lastIndex) {
            break;
          }
          if (i == processConcurrent - 1 || end > lastIndex) {
            end = lastIndex;
          }

          taskRanges.add((start, end));

          // 提前终止：如果已经覆盖到最后一个索引，无需继续生成分片
          if (end == lastIndex) {
            break;
          }
        }


        Process.run(
            path.join(
              UserPreferences.instance.webWebBrowserPath,
              "web_web_browser.exe",
            ),
            [
              "--tasktype=cwm",
              "--jsonfilepath=${_infoJson.path}",
              "--taskmergestart=0",
              "--taskmergeend=${_taskList.length - 1}",
            ],
          );
        // 4. 启动子进程处理每个分片（遍历实际生成的分片，避免空进程）
        // for (int i = 0; i < taskRanges.length; i++) {
        //   int processNo = i + 1; // 进程编号（从1开始）
        //   var (start, end) = taskRanges[i];

        //   // 打印分片信息（便于调试）
        //   print("进程$processNo 处理区间：[$start, $end]（闭区间）");

        //   // 启动进程并监听所有状态
        //   Process.run(
        //     path.join(
        //       UserPreferences.instance.webWebBrowserPath,
        //       "web_web_browser.exe",
        //     ),
        //     [
        //       "--tasktype=cwm",
        //       "--jsonfilepath=${_infoJson.path}",
        //       "--taskmergestart=$start",
        //       "--taskmergeend=$end",
        //     ],
        //   ).asStream().listen(
        //     (event) {
        //       // 输出子进程日志
        //       if (event.stdout.isNotEmpty) {
        //         print("子进程$processNo 标准输出：${event.stdout}");
        //       }
        //       if (event.stderr.isNotEmpty) {
        //         print("子进程$processNo 错误输出：${event.stderr}");
        //       }
        //       // 检查进程退出码（判断执行是否成功）
        //       if (event.exitCode != null) {
        //         if (event.exitCode == 0) {
        //           print("子进程$processNo 执行完成（退出码：${event.exitCode}）");
        //         } else {
        //           print("子进程$processNo 执行失败（退出码：${event.exitCode}）");
        //         }
        //       }
        //     },
        //     onError: (error) {
        //       // 捕获进程启动失败的异常
        //       print("子进程$processNo 启动失败：$error");
        //     },
        //   );
        // }
      } else {
        // 等待100ms后重试（避免CPU空转）
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  // 下载单个任务（纯主线程）
  Future<void> _downloadSingleTask(TaskModel task) async {
    _initTaskProgress(task);
    final totalChapters = task.volumes.fold(
      0,
      (sum, vol) => sum + vol.chapters.length,
    );
    int completed = 0;

    // 1. 初始化WebView提取器（主线程）
    final extractor = cwm_NovelExtractor();
    final initSuccess = await extractor.initialize();

    if (!initSuccess) {
      _updateTaskProgress(task, {
        'error': 'WebView初始化失败，请检查环境',
        'status': DownloadTaskStatus.failed.name,
        'progress': 0.0,
      });
      _currentActive--;
      return;
    }

    // 2. 遍历所有章节下载
    try {
      for (final volume in task.volumes) {
        if (!_daemonRunning) break; // 检查是否需要停止

        for (final chapter in volume.chapters) {
          if (!_daemonRunning) break;

          // 更新章节开始下载状态
          chapter.status = DownloadTaskStatus.downloading;
          _updateTaskProgress(task, {
            'completed': completed,
            'total': totalChapters,
            'progress': totalChapters > 0 ? completed / totalChapters : 0.0,
            'currentChapter': chapter.title,
            'status': DownloadTaskStatus.downloading.name,
          });

          try {
            // 3. 下载章节内容（主线程WebView）
            final content = await extractor.getNovelContent(chapter.url);

            // 检查内容是否有效（新增：包含付费提示判断）
            if (content.startsWith('提取失败') ||
                content.startsWith('URL格式错误') ||
                content.startsWith('未找到') ||
                content == '該章節是付費章節，不提供下載') {
              // 新增付费提示判断
              throw Exception(content);
            }

            // 4. 保存为TXT文件
            await _saveChapterToTxt(task.savePath, chapter.title, content);

            // 5. 更新进度
            completed++;
            chapter.progress = 1.0;
            chapter.status = DownloadTaskStatus.completed;

            _updateTaskProgress(task, {
              'completed': completed,
              'progress': totalChapters > 0 ? completed / totalChapters : 1.0,
              'currentChapter': chapter.title,
            });
          } catch (e) {
            // 单个章节失败，标记并继续下一个
            chapter.status = DownloadTaskStatus.failed;
            _updateTaskProgress(task, {
              'error': '章节${chapter.title}下载失败：$e',
              'currentChapter': chapter.title,
            });
            continue; // 跳过失败章节，继续下一个
          }
        }
      }

      // 任务全部完成
      _updateTaskProgress(task, {
        'progress': 1.0,
        'status': completed == totalChapters
            ? DownloadTaskStatus.completed.name
            : DownloadTaskStatus.failed.name,
        'error': completed < totalChapters ? '部分章节下载失败' : '',
      });
    } catch (e) {
      // 任务整体失败
      _updateTaskProgress(task, {
        'error': '任务执行失败：$e',
        'status': DownloadTaskStatus.failed.name,
        'progress': 0.0,
      });
    } finally {
      // 必须释放WebView资源
      extractor.dispose();
      _currentActive--;
    }
  }

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

  // 添加下载任务到队列
  void addDownloadTask({
    required TaskType taskType,
    required String coverUrl,
    required String novelAuthor,
    required String novelTitle,
    required List<cwm_NovelVolume> volumes,
    required bool isEpub,
    required String savePath,
  }) {
    final newTask = TaskModel(
      taskType: taskType,
      coverUrl: coverUrl,
      novelAuthor: novelAuthor,
      novelTitle: novelTitle,
      volumes: volumes,
      isEpub: isEpub,
      savePath: savePath,
    );

    tasks.add(newTask);
    _initTaskProgress(newTask);
    _taskChangedController.sink.add(null);

    // 如果守护进程已启动，触发任务处理
    if (_daemonRunning) {
      _processTasks();
    }
  }

  // 初始化任务进度
  void _initTaskProgress(TaskModel task) {
    final total = task.volumes.fold(0, (sum, vol) => sum + vol.chapters.length);
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
          'total': task.volumes.fold(
            0,
            (sum, vol) => sum + vol.chapters.length,
          ),
          'progress': 0.0,
          'currentChapter': '',
          'status': DownloadTaskStatus.pending.name,
          'error': '',
        };
  }

  // 通过ID获取任务进度
  Map<String, dynamic>? getTaskProgressById(String taskId) =>
      _taskProgress[taskId];
}
