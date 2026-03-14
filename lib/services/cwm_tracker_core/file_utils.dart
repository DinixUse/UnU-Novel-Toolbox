// file_utils.dart
import 'dart:io';
import 'dart:convert';
import 'package:path/path.dart' as path;

import 'book_model.dart';

class FileUtils {
  // 转换base64名称的 key 目录下的文件为 chapter id
  // 与 Python 版本行为保持一致，会在处理完成后写入一个名为 `done` 的空文件。
  static void transformFilename(String keyDir) {
    final dir = Directory(keyDir);
    if (!dir.existsSync()) return;

    final doneFile = File(path.join(keyDir, 'done'));
    if (doneFile.existsSync()) {
      PrintUtils.info('[INFO] 已处理过，跳过');
      return;
    }

    for (var entity in dir.listSync()) {
      if (entity is File) {
        try {
          final originName = path.basename(entity.path);
          final decoded = utf8.decode(base64.decode(originName));
          final newName = decoded.length > 9
              ? decoded.substring(0, 9)
              : decoded;
          entity.renameSync(path.join(keyDir, newName));
        } catch (e) {
          PrintUtils.err(
            '[ERR] 处理失败 $keyDir/${path.basename(entity.path)}，原因是： $e',
          );
        }
      }
    }

    doneFile.writeAsStringSync('OK');
  }

  // 移除文件中的换行符
  static void removeNewlinesInEachFile(Directory directory) {
    if (!directory.existsSync()) return;

    for (var file in directory.listSync()) {
      if (file is File) {
        final content = file
            .readAsStringSync()
            .replaceAll('\n', '')
            .replaceAll('\r', '');
        file.writeAsStringSync(content);
      }
    }
  }

  // 检查目录是否存在，不存在则创建
  static void ensureDirectoryExists(String path) {
    final dir = Directory(path);
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
  }
}
