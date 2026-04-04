import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:file_selector_windows/file_selector_windows.dart';
import 'package:m3e_expandable/m3e_expandable.dart';

import 'widgets/widgets.dart';
import 'preferences.dart';
import 'main.dart';

class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  XTypeGroup typeGroup = const XTypeGroup(
    label: 'ebooks',
    extensions: <String>['epub', 'mobi', 'pdf', 'txt'],
    uniformTypeIdentifiers: <String>[
      'org.idpf.epub',
      'com.amazon.mobi',
      'com.adobe.pdf',
      'text.plain',
    ],
  );

  XTypeGroup imgTypeGroup = const XTypeGroup(
    label: 'images',
    extensions: <String>['jpg', 'png', 'bmp'],
    uniformTypeIdentifiers: <String>[
      'public.jpeg',
      'public.png',
      'com.microsoft.bmp',
    ],
  );

  // Notice: Please change this path to the location of your ebook-convert.exe
  // String ebookConverterDirectory =
  //     "D:\\tmp\\calibrePTB\\Calibre\\ebook-convert.exe";

  TextEditingController _ebookConverterPathController = TextEditingController();

  Format? _selectedFormat;
  Ops _selectedOp = Ops.none;
  XFile? _ebookFile;
  String? _outputFilePath;

  TextEditingController _bookTitle = TextEditingController();
  TextEditingController _bookAuthor = TextEditingController();
  TextEditingController _bookDescription = TextEditingController();
  XFile? _bookCoverUri;

  TextEditingController _volumeDetectRule = TextEditingController();
  TextEditingController _chapterDetectRule = TextEditingController();

  List<String> processOutputs = [];

  Future<void> _processToFormattedHtml(
    String inputTxtPath,
    String outputHtmlPath,
    String bookTitle,
  ) async {
    //final inputTxtPath = 'input.txt';
    //final outputHtmlPath = 'output.html';

    try {
      // 1. 读取TXT内容，按换行分割成行列表
      String txtContent = await File(inputTxtPath).readAsString(encoding: utf8);
      List<String> lines = txtContent.split('\n');

      List<String> processedLines = [];
      for (String line in lines) {
        String trimmedLine = line.trim();

        if (trimmedLine.isEmpty) continue;

        bool isHtmlTagLine =
            trimmedLine.startsWith('<') && trimmedLine.endsWith('>');

        if (isHtmlTagLine) {
          processedLines.add(line);
        } else {
          processedLines.add('<p>$trimmedLine</p>');
        }
      }

      String htmlContent =
          '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>$bookTitle</title>
</head>
<body>
${processedLines.join('\n')}
</body>
</html>
''';

      await File(outputHtmlPath).writeAsString(htmlContent, encoding: utf8);
      print('转换完成！HTML文件已保存至：$outputHtmlPath');
    } catch (e) {
      print('转换失败：$e');
    }
  }

  void _clearState() {
    setState(() {
      _selectedFormat = null;
      _ebookFile = null;
      _outputFilePath = null;
      _bookTitle.text = "";
      _bookAuthor.text = "";
      _bookDescription.text = "";
      _volumeDetectRule.text = "";
      _chapterDetectRule.text = "";
      _bookCoverUri = null;
      _selectedOp = Ops.none;
      processOutputs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          UserPreferences.instance.currentSettingsMap["ebook-converter-path"] !=
              ""
          ? null
          : AppBar(
              titleSpacing: 0,
              surfaceTintColor: Colors.transparent,
              backgroundColor: Colors.transparent,
              scrolledUnderElevation: 0,
              title: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                  
                ),
                color: Theme.of(context).colorScheme.error,
                child: ListTile(
                  leading: Icon(
                    Icons.error,
                    color: Theme.of(context).colorScheme.onError,
                  ),
                  title: Text(
                    "你還未設定ebook-converter.exe的路徑。請填滿 「設定 > Ebook Converter路徑」 。",
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onError,
                    ),
                  ),
                ),
              ),
            ),
      backgroundColor:
          UserPreferences
                  .instance
                  .currentSettingsMap["scaffold_background_image_url"] ==
              ""
          ? Theme.of(context).colorScheme.surface
          : Theme.of(context).colorScheme.surface.withAlpha(
              UserPreferences.instance.currentSettingsMap["ui_alpha"],
            ),
      body: Padding(
        padding: const EdgeInsets.only(
          right: 24,
          left: 24
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // TextField(
              //   controller: _ebookConverterPathController,
              //   decoration: const InputDecoration(
              //     hintText:
              //         "Path to ebook-convert.exe (e.g. D:\\calibre\\ebook-convert.exe)",
              //   ),
              // ),
              const SizedBox(height: 8,),
              Row(
                children: [
                  FilledButton.tonal(
                    child: const Text("選取原始檔案"),
                    onPressed: () async {
                      Function? _closeDialogFunction;

                      showDialog(
                        context: context,
                        builder: (context) {
                          _closeDialogFunction = () =>
                              Navigator.of(context).pop();
                          return const Center(
                            child: ExpressiveLoadingIndicator(contained: true),
                          );
                        },
                      );

                      _ebookFile = await openFile(
                        acceptedTypeGroups: <XTypeGroup>[typeGroup],
                      );

                      if (_closeDialogFunction != null) {
                        _closeDialogFunction!();
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _ebookFile != null ? _ebookFile!.name : "",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text("輸出檔案格式："),
                  const SizedBox(width: 8),
                  DropdownButton<Format>(
                    dropdownColor: Theme.of(
                      context,
                    ).colorScheme.surfaceContainer,
                    underline: const SizedBox(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    borderRadius: BorderRadius.circular(24),
                    items: const [
                      DropdownMenuItem<Format>(
                        child: Text('EPUB'),
                        value: Format.epub,
                      ),
                      DropdownMenuItem<Format>(
                        child: Text('MOBI'),
                        value: Format.mobi,
                      ),
                      DropdownMenuItem<Format>(
                        child: Text('PDF / HTML'),
                        value: Format.expanded,
                      ),
                      DropdownMenuItem<Format>(
                        child: Text('TXT'),
                        value: Format.txt,
                      ),
                    ],
                    onChanged: (Format? format) {
                      setState(() {
                        _selectedFormat = format;
                      });
                    },
                    value: _selectedFormat,
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Row(
                children: [
                  FilledButton.tonal(
                    child: const Text("選取輸出目錄"),
                    onPressed: () async {
                      Function? _closeDialogFunction;

                      showDialog(
                        context: context,
                        builder: (context) {
                          _closeDialogFunction = () =>
                              Navigator.of(context).pop();
                          return const Center(
                            child: ExpressiveLoadingIndicator(contained: true),
                          );
                        },
                      );

                      _outputFilePath = await getDirectoryPath();

                      if (_closeDialogFunction != null) {
                        _closeDialogFunction!();
                      }
                      setState(() {});
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _outputFilePath != null ? _outputFilePath! : "",
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              M3EExpandableCardList(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: 1,
                headerBuilder: (context, index, isExpanded) => Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_fix_high),
                    Text(
                      "  設定 & 額外内容",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                bodyBuilder: (context, index) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SettingsHeader(title: "書籍信息"),
                    Column(
                      children: [
                        SettingsTile(
                          tileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          position: TilePosition.first,
                          title: TextField(
                            controller: _bookTitle,
                            decoration: const InputDecoration(labelText: "標題"),
                          ),
                        ),

                        SettingsTile(
                          tileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          position: TilePosition.middle,
                          title: TextField(
                            controller: _bookAuthor,
                            decoration: const InputDecoration(labelText: "作者"),
                          ),
                        ),

                        SettingsTile(
                          tileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          position: TilePosition.last,
                          title: TextField(
                            controller: _bookDescription,
                            decoration: const InputDecoration(labelText: "描述"),
                          ),
                        ),

                        const SizedBox(height: 8),

                        /*TextBox(
                            placeholder: "Cover Image Path",
                            onChanged: (value) {
                              _bookCoverUri = value;
                            },
                          ),*/
                        Row(
                          children: [
                            OutlinedButton(
                              child: const Text("選取封面圖片"),
                              onPressed: () async {
                                Function? _closeDialogFunction;

                                showDialog(
                                  context: context,
                                  builder: (context) {
                                    _closeDialogFunction = () =>
                                        Navigator.of(context).pop();
                                    return const Center(
                                      child: ExpressiveLoadingIndicator(
                                        contained: true,
                                      ),
                                    );
                                  },
                                );

                                _bookCoverUri = await openFile(
                                  acceptedTypeGroups: <XTypeGroup>[
                                    imgTypeGroup,
                                  ],
                                );

                                if (_closeDialogFunction != null) {
                                  _closeDialogFunction!();
                                }
                                setState(() {});
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _bookCoverUri != null
                                    ? _bookCoverUri!.path
                                    : "",
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const SettingsHeader(title: "偵測器"),
                    Column(
                      children: [
                        SettingsTile(
                          tileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          position: TilePosition.first,
                          title: TextField(
                            controller: _volumeDetectRule,
                            decoration: const InputDecoration(
                              labelText: "卷偵測器",
                            ),
                          ),
                        ),

                        SettingsTile(
                          tileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          position: TilePosition.last,
                          title: TextField(
                            controller: _chapterDetectRule,
                            decoration: const InputDecoration(
                              labelText: "章節偵測器",
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    const SettingsHeader(title: "額外内容"),
                    Column(
                      children: [
                        SettingsTile(
                          tileColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          position: TilePosition.single,
                          title: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              const Text("特定優化："),
                              const SizedBox(width: 8),
                              DropdownButton<Ops>(
                                dropdownColor: Theme.of(
                                  context,
                                ).colorScheme.surfaceContainer,
                                underline: const SizedBox(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                ),
                                borderRadius: BorderRadius.circular(24),
                                items: const [
                                  DropdownMenuItem<Ops>(
                                    child: Text('無'),
                                    value: Ops.none,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Kindle'),
                                    value: Ops.kindle,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Cybook Gen3'),
                                    value: Ops.cybookg3,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Hanlin V3'),
                                    value: Ops.hanlinv3,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Hanlin V5'),
                                    value: Ops.hanlinv5,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Iliad'),
                                    value: Ops.illiad,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('iPad'),
                                    value: Ops.ipad,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('iPad 3'),
                                    value: Ops.ipad3,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('iRex DR1000'),
                                    value: Ops.irexdr1000,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('iRex DR800'),
                                    value: Ops.irexdr800,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Jetbook 5'),
                                    value: Ops.jetbook5,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Kobo'),
                                    value: Ops.kobo,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('MS Reader'),
                                    value: Ops.msreader,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Mobipocket'),
                                    value: Ops.mobipocket,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Nook'),
                                    value: Ops.nook,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Samsung Galaxy'),
                                    value: Ops.galaxy,
                                  ),
                                  DropdownMenuItem<Ops>(
                                    child: Text('Sony PRS-505/700/3000'),
                                    value: Ops.sony,
                                  ),
                                  /*DropdownMenuItem<Ops>(
                                    child: Text(
                                      'Sony PRS-300/600/900/950/960/970/980/1000/6000/6500/9000/9500/',
                                    ),
                                    value: Ops.sony,
                                  ),*/
                                ],

                                onChanged: (Ops? op) {
                                  setState(() {
                                    _selectedOp = op ?? Ops.none;
                                  });
                                },
                                // placeholder: const Text('None'),
                                value: _selectedOp,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    child: const Text("開始轉換"),
                    onPressed:
                        _ebookFile != null &&
                            _selectedFormat != null &&
                            _outputFilePath != null &&
                            UserPreferences
                                    .instance
                                    .currentSettingsMap["ebook-converter-path"] !=
                                ""
                        ? () async {
                            // Show loading dialog
                            Function? _closeDialogFunction;

                            showDialog(
                              context: context,
                              builder: (context) {
                                _closeDialogFunction = () =>
                                    Navigator.of(context).pop();
                                return const Center(
                                  child: ExpressiveLoadingIndicator(
                                    contained: true,
                                  ),
                                );
                              },
                            );

                            String _targetOriginFilePath = _ebookFile!.path;
                            String _ebookString = await _ebookFile!
                                .readAsString(encoding: systemEncoding);
                            String _result = _ebookString;

                            // 1. Apply Text Replacements (Regex)
                            if (_volumeDetectRule.text != "") {
                              try {
                                final RegExp volumeRegex = RegExp(
                                  _volumeDetectRule.text,
                                );
                                _result = _result.replaceAllMapped(
                                  volumeRegex,
                                  (match) => "<h1>${match.group(1)}</h1>",
                                );
                              } catch (e) {
                                print("Regex Error for Volume Rule: $e");
                              }
                            }

                            if (_chapterDetectRule.text != "") {
                              try {
                                final RegExp chapterRegex = RegExp(
                                  _chapterDetectRule.text,
                                );
                                _result = _result.replaceAllMapped(
                                  chapterRegex,
                                  (match) => "<h2>${match.group(1)}</h2>",
                                );
                              } catch (e) {
                                print("Regex Error for Chapter Rule: $e");
                              }
                            }

                            // 2. Write to temp file if changes were made

                            final tempDir = await getTemporaryDirectory();

                            if (_result != _ebookString) {
                              final tempFile = File(
                                p.join(tempDir.path, 'processed_ebook.txt'),
                              );
                              await tempFile.writeAsString(_result);
                              _targetOriginFilePath = tempFile.path;
                            }

                            await _processToFormattedHtml(
                              _targetOriginFilePath,
                              p.join(tempDir.path, 'processed_ebook.html'),
                              _bookTitle.text != ""
                                  ? _bookTitle.text
                                  : "Untitled",
                            );

                            _targetOriginFilePath = p.join(
                              tempDir.path,
                              'processed_ebook.html',
                            );

                            // 3. Build Output Path
                            String extension;
                            switch (_selectedFormat) {
                              case Format.epub:
                                extension = 'epub';
                                break;
                              case Format.mobi:
                                extension = 'mobi';
                                break;
                              case Format.expanded:
                                extension =
                                    ''; // PDF/HTML usually no extension in filename
                                break;
                              case Format.txt:
                                extension = 'txt';
                                break;
                              default:
                                extension = 'out';
                            }

                            String outputFileName = _bookTitle.text != ""
                                ? _bookTitle.text
                                : "output";
                            if (extension.isNotEmpty) {
                              outputFileName += '.$extension';
                            }

                            // Use path.join for safe path construction
                            String finalOutputPath = p.join(
                              _outputFilePath!,
                              outputFileName,
                            );

                            // 4. Build Arguments List (Filter out nulls/empty strings)
                            List<String> arguments = [
                              _targetOriginFilePath,
                              finalOutputPath,
                            ];

                            if (_bookTitle.text != "") {
                              arguments.add('--title=${_bookTitle.text}');
                            }
                            if (_bookAuthor.text != "") {
                              arguments.add('--authors=${_bookAuthor.text}');
                            }
                            if (_bookDescription.text != "") {
                              arguments.add(
                                '--comments=${_bookDescription.text}',
                              );
                            }
                            if (_volumeDetectRule.text != "") {
                              arguments.add('--level1-toc=//h:h1');
                            }
                            if (_chapterDetectRule.text != "") {
                              arguments.add('--level2-toc=//h:h2');
                            }

                            if (_selectedOp != Ops.none) {
                              arguments.add(
                                '--output-profile=${_selectedOp.name.toLowerCase()}',
                              );
                            }

                            if (_bookCoverUri != null) {
                              arguments.add('--cover=${_bookCoverUri!.path}');
                            }

                            // 5. Start Process
                            try {
                              final Process process = await Process.start(
                                _ebookConverterPathController.text,
                                arguments,
                              );

                              // Listen to stdout
                              process.stdout.listen((out) {
                                print(utf8.decode(out));
                                processOutputs.add(utf8.decode(out));
                              });

                              // Listen to stderr (Crucial for debugging errors)
                              process.stderr.listen((err) {
                                print(utf8.decode(err));
                                processOutputs.add(utf8.decode(err));
                              });

                              process.exitCode.then((code) {
                                if (_closeDialogFunction != null) {
                                  _closeDialogFunction!();
                                }
                                _clearState();

                                if (code == 0) {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text("Success"),
                                        content: const Text(
                                          "Ebook converted successfully!",
                                        ),
                                        actions: [
                                          OutlinedButton(
                                            child: const Text("OK"),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  showDialog(
                                    context: context,
                                    builder: (context) {
                                      return AlertDialog(
                                        title: const Text("Error"),
                                        content: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Text(
                                              "Ebook conversion failed. Process output:",
                                            ),
                                            const SizedBox(height: 12),
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              color: Colors.grey[200],
                                              child: SingleChildScrollView(
                                                child: SelectableText(
                                                  processOutputs.join('\n'),
                                                  style: const TextStyle(
                                                    fontFamily: 'Consolas',
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        actions: [
                                          OutlinedButton(
                                            child: const Text("OK"),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }
                              });
                            } catch (e) {
                              if (_closeDialogFunction != null) {
                                _closeDialogFunction!();
                              }
                              showDialog(
                                context: context,
                                builder: (context) {
                                  return AlertDialog(
                                    title: const Text("Error"),
                                    content: Text(
                                      "Failed to start process: $e",
                                    ),
                                    actions: [
                                      OutlinedButton(
                                        child: const Text("OK"),
                                        onPressed: () {
                                          Navigator.of(context).pop();
                                        },
                                      ),
                                    ],
                                  );
                                },
                              );
                            }
                          }
                        : null,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum Format { epub, mobi, expanded, txt, pdf }

enum Ops {
  none,
  kindle,
  cybookg3,
  hanlinv3,
  hanlinv5,
  illiad,
  ipad,
  ipad3,
  irexdr1000,
  irexdr800,
  jetbook5,
  kobo,
  msreader,
  mobipocket,
  nook,
  galaxy,
  sony,
  sony300,
  sony900,
  sonyt3,
  tablet,
}
