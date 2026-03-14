// book_model.dart

import 'dart:typed_data';
import 'package:http/http.dart' as http;

import 'tools.dart';

class Book {
  int? id;
  String? url;
  String? name;
  String? author;
  Uint8List? cover;
  String? coverUrl;
  String? description;
  List<Chapter> chapters = [];

  /// 安全的书名（用于文件名）
  String get safeName => Tools.sanitizeName(name ?? '未知书籍');

  /// 基础目录（所有内容均落在此目录下）
  String get baseDir => 'D:\\${id}';

  /// 解密后文本的总文件路径
  String get decryptedTxtPath => '$baseDir\\decrypted.txt';

  Book();
}

class Chapter {
  int? bookId; // 父书籍ID，用于路径计算
  int? id;
  String? title;
  String? url;
  bool isVolIntro = false;
  String? content;

  /// 派生值，用于文件名安全处理
  String safeTitle = '';

  // 文件路径相关。调用 [Config.calculateParams] 之后，bookId 应该被设置为正确的值，
  // 并且 safeTitle 也已经填充，这样生成的路径更可读。
  String get keyPath =>
      bookId != null && id != null ? 'key\${id}' : '${id}/key.txt';
  String get encryptedTxtPath => (bookId != null && id != null)
      ? '${bookId}\${id}.txt'
      : '${id}/${id}.txt';
  String get decryptedPath => (bookId != null && id != null)
      ? '${bookId}\${id}_decrypted.txt'
      : '${id}/${id}_decrypted.txt';

  Chapter({
    this.bookId,
    this.id,
    this.title,
    this.url,
    this.isVolIntro = false,
  });
}

enum DownloadTaskStatus { pending, downloading, completed, failed }

// class cwm_NovelChapter {
//   final String title;
//   final String url;
//   final int bookId;
//   final int id;
//   double progress;
//   DownloadTaskStatus status;

//   cwm_NovelChapter({
//     required this.title,
//     required this.url,
//     required this.bookId,
//     required this.id,
//     this.progress = 0.0,
//     this.status = DownloadTaskStatus.pending,
//   });

//   String get decryptedPath => '${bookId}\\${id}_decrypted.txt';
// }

// class cwm_NovelVolume {
//   final String volumeName;
//   final List<cwm_NovelChapter> chapters;

//   cwm_NovelVolume({required this.volumeName, required this.chapters});
// }

// 打印工具类
class PrintUtils {
  static void info(String message) => print('[INFO] $message');
  static void warn(String message) => print('[WARN] $message');
  static void err(String message) => print('[ERR] $message');
  static void opt(String message) => print('[OPT] $message');

  static String processingLabel(String label) => label;
}

// 请求客户端封装
class CustomHttpClient {
  final http.Client _client = http.Client();

  Future<http.Response> post(String url, {Map<String, String>? data}) async {
    return await _client.post(
      Uri.parse(url),
      body: data,
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
    );
  }

  Future<http.Response> get(String url) async {
    return await _client.get(Uri.parse(url));
  }

  void close() => _client.close();
}
