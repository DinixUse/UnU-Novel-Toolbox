import 'dart:io';
import 'book_model.dart';
import 'request_utils.dart';
import '../download_manager.dart';

class BookFetcher {
  /// 公共静态方法，用于获取书籍信息
  /// [input]：书籍URL或ID字符串
  /// 返回值：包含书籍信息的Map，如果获取失败返回空Map
  static Future<Map<String, dynamic>> fetchBook(String input) async {
    if (input.isEmpty) return {};

    // 解析书籍ID
    int id = 0;
    if (input.startsWith('http')) {
      try {
        final uri = Uri.parse(input);
        id = int.tryParse(uri.pathSegments.last) ?? 0;
      } catch (_) {}
    } else {
      id = int.tryParse(input) ?? 0;
    }

    if (id <= 0) {
      return {};
    }

    // 获取书籍基础信息
    final book = Book();
    book.id = id;

    final nameResult = await RequestUtils.getName(book);
    if (nameResult != 0) {
      return {};
    }

    final contentsResult = await RequestUtils.getContents(book);
    if (contentsResult != 0) {
      return {};
    }

    // 构建目录数据
    List<cwm_NovelVolume> volumes = [];
    String currentVolumeName = '';
    List<cwm_NovelChapter> currentChapters = [];
    for (var chapter in book.chapters) {
      if (chapter.isVolIntro) {
        if (currentChapters.isNotEmpty) {
          volumes.add(
            cwm_NovelVolume(
              volumeName: currentVolumeName,
              chapters: currentChapters,
            ),
          );
          currentChapters = [];
        }
        currentVolumeName = chapter.title ?? '';
      } else {
        currentChapters.add(
          cwm_NovelChapter(
            title: chapter.title ?? '',
            url: chapter.url ?? '',
          ),
        );
      }
    }
    if (currentChapters.isNotEmpty) {
      volumes.add(
        cwm_NovelVolume(
          volumeName: currentVolumeName,
          chapters: currentChapters,
        ),
      );
    }

    return {
      'id': id,
      'novelTitle': book.name ?? '',
      'novelAuthor': book.author ?? '',
      'novelCover': book.coverUrl ?? '',
      'cover': book.cover,
      'catalogData': volumes,
    };
  }
}
