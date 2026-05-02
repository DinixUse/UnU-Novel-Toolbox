import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as path;

class ExtensionService {
  ExtensionService._PrivateConstructor();
  static final ExtensionService _instance =
      ExtensionService._PrivateConstructor();

  static ExtensionService get instance => _instance;

  late Directory modulesFolderDir;

  final Map<String, String> extensionSources = {
    "Github": "https://raw.githubusercontent.com",
    "Gh-Proxy": "https://gh-proxy.org/https://raw.githubusercontent.com",
  };

  List<UnUExtension> extensions = [];
  List<(String, Object)> errorExtensions = [];

  Future<dynamic> fetchExtensionFromSource(String source) async {
    if (!extensionSources.containsKey(source)) {
      throw Exception("Unsupported extension source: $source");
    }

    String url =
        "${extensionSources[source]!}/Sbqmyy/UnU-Novel-Toolbox-Extensions/refs/heads/main/repo.json";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        return response.body;
      }
    } catch (e) {
      return "$e";
    }
  }

  Future<void> loadLocalExtensionsToList({
    required void Function(String dirPath, Object error) onLoadError,
  }) async {
    await for (final entity in modulesFolderDir.list(recursive: false)) {
      if (entity is Directory) {
        try {
          String infoJsonPath = path.join(entity.path, 'info.json');
          File infoJsonFile = File(infoJsonPath);

          Map<String, dynamic> infoMap = jsonDecode(
            await infoJsonFile.readAsString(),
          );
          extensions.add(
            UnUExtension(
              name: infoMap["name"],
              version: infoMap["version"],
              description: infoMap["description"],
              main: path.join(entity.path ,infoMap["main"]),
              applyForATab: infoMap["apply-for-a-tab"],
              tabTitle: infoMap["apply-for-a-tab"]
                  ? infoMap["tab-title"]
                  : null,
              tabIcon: infoMap["apply-for-a-tab"] ? infoMap["tab-icon"] : null,
            ),
          );
        } catch (e) {
          onLoadError(entity.path, e.toString());
        }
      }
    }
  }

  Future<void> initExtensionService() async {
    modulesFolderDir = Directory(path.join(Directory.current.path, "modules"));
    if (!await modulesFolderDir.exists()) {
      modulesFolderDir.create(recursive: true);
    }

    await loadLocalExtensionsToList(
      onLoadError: (errorExt, err) {
        errorExtensions.add((errorExt, err));
      },
    );
  }
}

class UnUExtension {
  final String name;
  final String version;
  final String description;
  final String main;
  final bool applyForATab;
  final String? tabTitle;
  final String? tabIcon;

  UnUExtension({
    required this.name,
    required this.version,
    required this.description,
    required this.main,
    required this.applyForATab,
    this.tabTitle,
    this.tabIcon,
  });
}
