import 'dart:io';

import 'package:flutter/material.dart';
import 'package:unu_novel_toolbox/preferences.dart';
import 'package:window_manager/window_manager.dart';
import 'services/download_manager.dart';
import 'package:progress_indicator_m3e/progress_indicator_m3e.dart';

class MainDownloadScreen extends StatefulWidget {
  const MainDownloadScreen({super.key});

  @override
  State<MainDownloadScreen> createState() => _MainDownloadScreenState();
}

class _MainDownloadScreenState extends State<MainDownloadScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("下載項目"),
        flexibleSpace: GestureDetector(
          onPanStart: (_) => windowManager.startDragging(),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView.builder(
          itemBuilder: (context, index) {
            return ValueListenableBuilder<double>(
              valueListenable:
                  DownloadManager.instance.tasks[index].progressNotifier,
              builder: (context, progress, child) {
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  clipBehavior: Clip.hardEdge, // 防止子组件溢出卡片
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: SizedBox(
                            width: 100,
                            height: 145,
                            child: Image.network(
                              // 空值校验：防止 URL 为空导致崩溃
                              DownloadManager.instance.tasks[index]?.coverUrl ??
                                  '',
                              fit: BoxFit.cover,
                              // 加载中占位
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                              // 加载失败占位
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey[200],
                                  child: const Icon(
                                    Icons.broken_image,
                                    color: Colors.grey,
                                    size: 40,
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // 优化：文本过长省略，增加样式
                              Row(
                                children: [
                                  Text(
                                    DownloadManager
                                            .instance
                                            .tasks[index]
                                            ?.novelTitle ??
                                        '未知标题',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    DownloadManager
                                        .instance
                                        .tasks[index]
                                        .taskType
                                        .name
                                        .toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                DownloadManager
                                        .instance
                                        .tasks[index]
                                        ?.novelAuthor ??
                                    '未知作者',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                ),
                              ),

                              const SizedBox(height: 8),

                              SizedBox(
                                height: 8, // 设置进度条高度
                                child: LinearProgressIndicatorM3E(
                                  size: LinearProgressM3ESize.s,
                                  value: progress ?? 0.0, // 空值校验
                                ),
                              ),
                              const SizedBox(height: 6),

                              Row(
                                children: [
                                  Text(
                                    '${((progress ?? 0.0) * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    DownloadManager.instance.tasks[index].isEpub
                                        ? " · EPUB"
                                        : " · TXT",
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[400],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              if (progress < 1.0)
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    OutlinedButton(
                                      onPressed: () async {
                                        await DownloadManager.instance
                                            .cancelDownloadTask(
                                              taskId:
                                                  DownloadManager
                                                      .instance
                                                      .tasks[index]
                                                      ?.taskId ??
                                                  '',
                                              deleteFiles: false,
                                            );

                                        setState(() {});
                                      },
                                      child: const Text("取消"),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
          itemCount: DownloadManager.instance.tasks.length,
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.folder),
        onPressed: () async {
          final result = await Process.run('explorer.exe', [
            UserPreferences.instance.currentSettingsMap["download_root_path"],
          ], runInShell: true);
        },
        label: const Text("打開下載目錄"),
      ),
    );
  }
}

/*
Column(
                  children: [
                    Image.network(DownloadManager.instance.tasks[index].coverUrl),
                    Text(DownloadManager.instance.tasks[index].novelTitle),
                    Text(DownloadManager.instance.tasks[index].novelAuthor),
                    LinearProgressIndicator(value: progress),
                    Text('下载进度：${(progress * 100).toStringAsFixed(1)}%'),
                    OutlinedButton(
                      onPressed: () async {
                        await DownloadManager.instance.cancelDownloadTask(
                          taskId: DownloadManager.instance.tasks[index].taskId,
                          deleteFiles: false,
                        );

                        setState(() {
                          
                        });
                      },
                      child: Text("Cancel"),
                    ),
                  ],
                )
*/
