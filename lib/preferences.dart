import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:path_provider_windows/path_provider_windows.dart';
import 'dart:io';

class UserPreferences {
  UserPreferences._privateConstructor();

  static final UserPreferences _instance = UserPreferences._privateConstructor();
  static UserPreferences get instance => _instance;

  final applicationPath = Directory.current.path;
  final webWebBrowserPath = path.join(Directory.current.path, "modules", "web_web_browser");

  final Map<String, dynamic> defaultSettingsMap = {
    "scaffold_background_image_url": "",
    "ui_alpha": 128,
    "image_opacity": 0.5,
    "download_root_path": "C:\\UnUDownloads",
    "app_color": 4280391411,
    "dynamic_app_color": false,
    "enable_blur": false
  };

  Map<String, dynamic> currentSettingsMap = {};

  Future<void> resumeDefaultSettings () async {
    Directory _settingsJsonDir = Directory(path.join(applicationPath, "appData"));
    if(!await _settingsJsonDir.exists()) {
      await _settingsJsonDir.create(recursive: true);
    }

    File _settingsJsonFile = File(path.join(applicationPath, "appData\\settings.json"));
    await  _settingsJsonFile.writeAsString(jsonEncode(defaultSettingsMap));
  }

  Future<void> saveSettings () async {
    Directory _settingsJsonDir = Directory(path.join(applicationPath, "appData"));
    if(!await _settingsJsonDir.exists()) {
      await _settingsJsonDir.create(recursive: true);
    }

    File _settingsJsonFile = File(path.join(applicationPath, "appData\\settings.json"));
    await  _settingsJsonFile.writeAsString(jsonEncode(currentSettingsMap));
  }

  Future<void> initializePreferences () async {
    Directory _settingsJsonDir = Directory(path.join(applicationPath, "appData"));
    if(!await _settingsJsonDir.exists()) {
      await _settingsJsonDir.create(recursive: true);
    }

    File _settingsJsonFile = File(path.join(applicationPath, "appData\\settings.json"));
    if(!await _settingsJsonFile.exists()) {
      await _settingsJsonFile.writeAsString(jsonEncode(defaultSettingsMap));

      currentSettingsMap = defaultSettingsMap;
    }else{
      String _settingsString = await _settingsJsonFile.readAsString();
      currentSettingsMap = jsonDecode(_settingsString);
    }
  }
}