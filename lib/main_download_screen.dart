import 'package:flutter/material.dart';
import 'services/download_manager.dart';

class MainDownloadScreen extends StatefulWidget {
  const MainDownloadScreen({super.key});

  @override
  State<MainDownloadScreen> createState() => _MainDownloadScreenState();
}

class _MainDownloadScreenState extends State<MainDownloadScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("下载管理")),
      body: ListView.builder(
        itemBuilder: (context, index) {
          return ListTile(
            title: Text("下载项 $index"),
            subtitle: ValueListenableBuilder<double>(
              valueListenable:
                  DownloadManager.instance.tasks[index].progressNotifier,
              builder: (context, progress, child) {
                return Column(
                  children: [
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
                );
              },
            ),
          );
        },
        itemCount: DownloadManager.instance.tasks.length,
      ),
    );
  }
}
