// request_utils.dart
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

import 'book_model.dart';

class RequestUtils {
  static final CustomHttpClient _client = CustomHttpClient();

  // 获取书籍目录
  static Future<int> getContents(Book book) async {
    const url =
        "https://www.ciweimao.com/chapter/get_chapter_list_in_chapter_detail";
    final data = {
      "book_id": book.id.toString(),
      "chapter_id": "0",
      "orderby": "0",
    };

    try {
      final response = await _client.post(url, data: data);
      final document = parse(response.body);

      final chapterBoxes = document.querySelectorAll("div.book-chapter-box");
      for (var box in chapterBoxes) {
        // 处理卷名
        final volTitle = box.querySelector("h4.sub-tit")?.text.trim() ?? '';
        book.chapters.add(
          Chapter(bookId: book.id, title: volTitle, isVolIntro: true),
        );

        // 处理章节列表
        final chapterLinks = box.querySelectorAll("ul.book-chapter-list li a");
        for (var a in chapterLinks) {
          final url = a.attributes['href'] ?? '';
          final title = a.text.trim();
          final chapterId = int.tryParse(url.split('/').last) ?? 0;

          book.chapters.add(
            Chapter(
              bookId: book.id,
              id: chapterId,
              title: title,
              url: url,
              isVolIntro: false,
            ),
          );
        }
      }
      return 0;
    } catch (e) {
      PrintUtils.err("[ERR] 解析章节列表失败: $e");
      return -1;
    }
  }

  // 获取书籍基本信息
  static Future<int> getName(Book book) async {
    final url = "https://www.ciweimao.com/book/${book.id}";

    try {
      final response = await _client.post(url);
      final document = parse(response.body);

      // 解析meta标签
      String? name, author, coverUrl, description;

      final metaTags = document.querySelectorAll("meta");
      for (var tag in metaTags) {
        final property = tag.attributes['property'];
        final content = tag.attributes['content'];

        if (property == "og:novel:book_name") name = content;
        if (property == "og:novel:author") author = content;
        if (property == "og:image") coverUrl = content;
        if (property == "og:description") description = content;
      }

      if (name == null ||
          author == null ||
          coverUrl == null ||
          description == null) {
        throw Exception("[WARN] 缺失必要的 meta 标签");
      }

      // 获取封面图片
      Uint8List? cover;
      try {
        final coverResponse = await _client.get(coverUrl);
        cover = coverResponse.bodyBytes;
      } catch (e) {
        PrintUtils.warn("[WARN] 封面图片获取失败: $e");
      }

      // 更新书籍信息
      book.name = name;
      book.author = author;
      book.cover = cover;
      book.coverUrl = coverUrl;
      book.description = description;

      return 0;
    } catch (e) {
      PrintUtils.warn("[WARN] 自动获取书籍信息失败: $e");
      return -1;
    }
  }
}

// 异步HTTP客户端
class AsyncHTTP {
  static http.Client? _session;

  static Future<void> init() async {
    if (_session == null) {
      _session = http.Client();
    }
  }

  static Future<Uint8List> get(String url) async {
    if (_session == null) await init();
    final response = await _session!.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('HTTP请求失败: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  static Future<void> close() async {
    _session?.close();
    _session = null;
  }
}
