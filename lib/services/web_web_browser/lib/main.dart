import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:args/args.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart'; // 导入URL启动器

import 'download_manager.dart';

late final String tasktype;
late final String jsonfilepath;
late final String taskmergestart;
late final String taskmergeend;

// 添加重试间隔常量（秒）
const int retryIntervalSeconds = 5;
// 最大重试次数（防止无限循环，可根据需要调整）
const int maxRetryCount = 300;

void logToFile(String message) {
  try {
    File logFile = File('E:/flutterapplog.log');
    logFile
        .writeAsString('${DateTime.now()}: $message\n', mode: FileMode.append)
        .then((_) {})
        .catchError((e) {
          print('Failed to write log: $e');
        });
  } catch (e) {
    print('Failed to write log: $e');
  }
}

void main(List<String> arguments) async {
  WidgetsFlutterBinding.ensureInitialized();
  // logToFile('Application started');

  final parser = ArgParser();
  parser.addOption('tasktype', abbr: 't');
  parser.addOption('jsonfilepath', abbr: 'p');
  parser.addOption('taskmergestart', abbr: 's');
  parser.addOption('taskmergeend', abbr: 'e');

  final results = parser.parse(arguments);

  tasktype = results['tasktype'].toString();
  jsonfilepath = results['jsonfilepath'].toString();
  taskmergestart = results['taskmergestart'].toString();
  taskmergeend = results['taskmergeend'].toString();

  if(tasktype == "" || jsonfilepath == "" || taskmergestart == "" || taskmergeend == "") {
    windowManager.destroy();
    exit(0);
  }

  // logToFile(
  //   'Parsed arguments: tasktype=$tasktype, jsonfilepath=$jsonfilepath, taskmergestart=$taskmergestart, taskmergeend=$taskmergeend',
  // );

  await windowManager.ensureInitialized();
  windowManager.setAlwaysOnBottom(true);

  WindowOptions windowOptions = WindowOptions(
    size: Size(90, 80),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );
  //await windowManager.hide();
  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.hide();
    //logToFile('Window shown');
  });

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Web Browser',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: MyWidget(),
    );
  }
}

class MyWidget extends StatefulWidget {
  const MyWidget({super.key});

  @override
  State<MyWidget> createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      //logToFile('Starting task processing');
      if (tasktype == "cwm") {
        cwm_NovelExtractor extractor = cwm_NovelExtractor();
        await extractor.initialize();

        //logToFile("Initialized.");

        File taskJsonFile = File(jsonfilepath);
        if (await taskJsonFile.exists()) {
          //logToFile("Start processing...");
          String _content = await taskJsonFile.readAsString();
          Map<String, dynamic> taskData = jsonDecode(_content);

          //logToFile("Got decoded json: $taskData");

          List<Map<String, String>> taskList =
              (taskData["tasks"] as List<dynamic>)
                  .map((item) => Map<String, String>.from(item))
                  .toList();
          //logToFile("Tasklist Initialized: $taskList");

          

          int _start = int.parse(taskmergestart);
          int _end = int.parse(taskmergeend);

          //logToFile(taskmergestart);
          //logToFile(taskmergeend);

          for (int i = _start; i <= _end; i++) {

            // 调用带重试机制的提取方法
            String _nvcontent = await extractNovelWithRetry(
              extractor,
              taskList[i]["url"]!,
              taskList[i]["savepath"]!,
              i,
            );

            // 保存成功提取的内容
            File _saveFile = File(taskList[i]["savepath"]!);
            await Directory(_saveFile.parent.path).create(recursive: true);

            await _saveFile.writeAsString(_nvcontent);

            // logToFile("gonna finish!: $_nvcontent");
          }

          extractor.dispose();
          Future.delayed(Duration(seconds: 1), () {
            windowManager.destroy();
            exit(0);
          });
        }
      }
    });
  }

  /// 带重试机制的小说提取方法
  /// [extractor] 提取器实例
  /// [url] 章节URL
  /// [savePath] 保存路径
  /// [index] 章节索引
  Future<String> extractNovelWithRetry(
    cwm_NovelExtractor extractor,
    String url,
    String savePath,
    int index,
  ) async {
    int retryCount = 0;
    String content = "";

    while (retryCount < maxRetryCount) {
      // 尝试提取内容
      content = await extractor.getNovelContent(url);

      // 检查是否提取成功
      if (!content.contains("提取失败")) {
        // logToFile("章节 $index 提取成功");
        return content;
      }

      // 提取失败，记录日志
      retryCount++;
      // logToFile("章节 $index 提取失败（第 $retryCount 次重试）: $content");
      // logToFile("正在打开URL: $url");

      try {
        // 使用URL Launcher打开失败的链接
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(
            uri,
            mode: LaunchMode.externalApplication, // 使用系统默认浏览器打开
          );
        } else {
          // logToFile("无法打开URL: $url");
        }
      } catch (e) {
        // logToFile("打开URL失败: $e");
      }

      // 等待一段时间后重试
      // logToFile("等待 $retryIntervalSeconds 秒后重试...");
      await Future.delayed(Duration(seconds: retryIntervalSeconds));
    }

    // 达到最大重试次数，抛出异常
    final errorMsg = "章节 $index 提取失败，已重试 $maxRetryCount 次，URL: $url";
    // logToFile(errorMsg);
    throw Exception(errorMsg);
  }

  @override
  Widget build(BuildContext context) {
    return const Placeholder();
  }
}
