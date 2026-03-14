// tools.dart
import 'dart:typed_data';
import 'package:mime/mime.dart';

import 'book_model.dart';

class Tools {
  // 标准化文件名
  static String sanitizeName(String name) {
    return name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '');
  }

  // 检查图片MIME类型
  static Map<String, String> checkImageMIME(Uint8List? img) {
    if (img == null || img.isEmpty) {
      throw Exception("图片数据为空");
    }

    final mimeType = lookupMimeType('', headerBytes: img);
    if (mimeType == null) {
      throw Exception("图片识别Mime失败");
    }

    String ext = '';
    switch (mimeType) {
      case 'image/webp':
        ext = '.webp';
        break;
      case 'image/x-icon':
        ext = '.ico';
        break;
      case 'image/heic':
        ext = '.heic';
        break;
      case 'image/heif':
        ext = '.heif';
        break;
      default:
        // remove spaces around slash and use proper string interpolation
        ext = '.${mimeType.split('/').last}';
    }

    return {'mime': mimeType, 'ext': ext};
  }

  // 处理字符串模板
  static String processString(String originStr, Book dataSource) {
    final Map<String, String> rule = {
      'bookID': dataSource.id.toString(),
      'bookCover': '<img src="${dataSource.coverUrl}" alt="书籍封面">',
      'bookName': dataSource.name ?? '',
      'bookAuthor': dataSource.author ?? '',
      'bookDescription': dataSource.description ?? '',
      'Enter': '　　',
    };

    String result = originStr;
    rule.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}
