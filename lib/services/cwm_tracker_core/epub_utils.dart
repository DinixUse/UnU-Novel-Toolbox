// epub_utils.dart
// 简化版 EPUB 生成器，仅生成基本结构和纯文本章节。
// 这个实现参考了 Python 版本的逻辑，但去掉了图片下载
// 与异步流水线部分，以便在 Flutter 环境下更容易使用。

import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';

import 'book_model.dart';

class EpubUtils {
  /// 生成一个简单的 epub 文件。
  ///
  /// [book] 必须已经经过 [AppConfig.calculateParams]、章节解密等步骤，
  /// 并且每个章节的 content 字段包含要写入 epub 的 HTML/文本。
  static Future<void> generateEpub(Book book, String outputPath) async {
    final archive = Archive();

    // mimetype 必须是第一个而且不压缩
    final mimeBytes = utf8.encode('application/epub+zip');
    final mimeFile = ArchiveFile('mimetype', mimeBytes.length, mimeBytes);
    mimeFile.compress = false;
    archive.addFile(mimeFile);

    // container.xml
    const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
    archive.addFile(
      ArchiveFile(
        'META-INF/container.xml',
        containerXml.length,
        utf8.encode(containerXml),
      ),
    );

    // chapters
    final manifestItems = <String>[];
    final spineItems = <String>[];

    for (var i = 0; i < book.chapters.length; i++) {
      final chap = book.chapters[i];
      if (chap.isVolIntro) continue; // 只将正文章节入 epub
      final filename = 'chap_${i + 1}.xhtml';
      final title = chap.title ?? '章节 ${i + 1}';
      final body = _wrapContent(chap.content ?? '');
      final full = _wrapXhtml(title, body);
      archive.addFile(
        ArchiveFile('OEBPS/$filename', full.length, utf8.encode(full)),
      );
      manifestItems.add(
        '<item id="chap$i" href="$filename" media-type="application/xhtml+xml"/>',
      );
      spineItems.add('<itemref idref="chap$i"/>');
    }

    // content.opf
    final metadata =
        '''<metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
      <dc:title>${book.name ?? ''}</dc:title>
      <dc:language>zh</dc:language>
      <dc:creator>${book.author ?? ''}</dc:creator>
    </metadata>''';

    final manifest = '<manifest>\n${manifestItems.join("\n")}\n</manifest>';
    final spine = '<spine toc="ncx">\n${spineItems.join("\n")}\n</spine>';

    final contentOpf =
        '''<?xml version="1.0" encoding="utf-8"?>
<package version="3.0" xmlns="http://www.idpf.org/2007/opf" unique-identifier="bookid">
$metadata
$manifest
$spine
</package>''';
    archive.addFile(
      ArchiveFile(
        'OEBPS/content.opf',
        contentOpf.length,
        utf8.encode(contentOpf),
      ),
    );

    // nav.xhtml (简单目录)
    final navHtml = _buildNav(book);
    archive.addFile(
      ArchiveFile('OEBPS/nav.xhtml', navHtml.length, utf8.encode(navHtml)),
    );

    // 写出 zip
    final encoder = ZipEncoder();
    final bytes = encoder.encode(archive);
    if (bytes == null) throw Exception('无法创建 epub');
    final outFile = File(outputPath);
    outFile.writeAsBytesSync(bytes);
  }

  static String _wrapXhtml(String title, String body) {
    return '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>$title</title></head>
  <body>$body</body>
</html>''';
  }

  /// 简单将纯文本转换为一段一段的 HTML，按照两个全角空格分割
  static String _wrapContent(String raw) {
    final parts = raw.split('　　');
    return parts
        .where((p) => p.trim().isNotEmpty)
        .map((p) => '<p>${p.trim()}</p>')
        .join();
  }

  static String _buildNav(Book book) {
    final entries = <String>[];
    for (var i = 0; i < book.chapters.length; i++) {
      final chap = book.chapters[i];
      if (chap.isVolIntro) continue;
      final title = chap.title ?? '章节 ${i + 1}';
      entries.add('<li><a href="chap_${i + 1}.xhtml">$title</a></li>');
    }
    return '''<?xml version="1.0" encoding="utf-8"?>
<html xmlns="http://www.w3.org/1999/xhtml">
  <head><title>目录</title></head>
  <body>
    <nav epub:type="toc">
      <ol>
        ${entries.join("\n        ")}
      </ol>
    </nav>
  </body>
</html>''';
  }
}
