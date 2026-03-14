// main.dart
import 'package:flutter/material.dart';
import 'dart:io';
import '../download_manager.dart';

import 'book_model.dart';
import 'request_utils.dart';
import 'ciweimao_downloader.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ciweimao Parser',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final TextEditingController _controller = TextEditingController();
  Map<String, dynamic>? _bookData;
  String _status = '';
  bool _loading = false;
  int? _bookId;

  Future<Map<String, dynamic>> _fetchBook() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return {};

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

    // Build catalogData
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ciweimao 解析器')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(labelText: '输入书籍 URL 或 ID'),
              onSubmitted: (_) async {
                setState(() {
                  _loading = true;
                  _status = '正在获取...';
                  _bookData = null;
                  _bookId = null;
                });
                final result = await _fetchBook();
                if (result.isNotEmpty) {
                  setState(() {
                    _bookData = result;
                    _bookId = result['id'];
                    _status = '加载完成';
                    _loading = false;
                  });
                } else {
                  setState(() {
                    _status = '获取失败';
                    _loading = false;
                  });
                }
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() {
                        _loading = true;
                        _status = '正在获取...';
                        _bookData = null;
                        _bookId = null;
                      });
                      final result = await _fetchBook();
                      if (result.isNotEmpty) {
                        setState(() {
                          _bookData = result;
                          _bookId = result['id'];
                          _status = '加载完成';
                          _loading = false;
                        });
                      } else {
                        setState(() {
                          _status = '获取失败';
                          _loading = false;
                        });
                      }
                    },
              child: const Text('获取信息'),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: (_loading || _bookId == null)
                  ? null
                  : () async {
                      setState(() {
                        _loading = true;
                        _status = '处理书籍中...';
                      });
                      try {
                        await CiweimaoDownloader().processBook(
                          _bookId.toString(),
                        );
                        setState(() {
                          _status = '处理完成';
                        });
                      } catch (e) {
                        setState(() {
                          _status = '处理失败: $e';
                        });
                      } finally {
                        setState(() {
                          _loading = false;
                        });
                      }
                    },
              child: const Text('Process Book'),
            ),
            const SizedBox(height: 12),
            Text(_status),
            const SizedBox(height: 12),
            if (_loading) const Center(child: CircularProgressIndicator()),
            if (_bookData != null) ...[
              if (_bookData!['cover'] != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Image.memory(
                    _bookData!['cover'],
                    height: 150,
                    fit: BoxFit.contain,
                  ),
                ),
              Text('标题：${_bookData!['novelTitle']}'),
              Text('作者：${_bookData!['novelAuthor']}'),
              Text(
                '章节：${(_bookData!['catalogData'] as List<cwm_NovelVolume>).fold(0, (sum, vol) => sum + vol.chapters.length)}',
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Builder(
                  builder: (context) {
                    List<cwm_NovelVolume> catalogData =
                        _bookData!['catalogData'] as List<cwm_NovelVolume>;
                    List<Widget> widgets = [];
                    for (var vol in catalogData) {
                      widgets.add(
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            vol.volumeName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
                      for (var chap in vol.chapters) {
                        widgets.add(
                          ListTile(
                            title: Text(chap.title),
                            subtitle: Text(chap.url),
                          ),
                        );
                      }
                    }
                    return ListView(children: widgets);
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
