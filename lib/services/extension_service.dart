import 'dart:convert';

import 'package:http/http.dart' as http;

class ExtensionService {
  ExtensionService._PrivateConstructor();
  static final ExtensionService _instance =
      ExtensionService._PrivateConstructor();

  static ExtensionService get instance => _instance;

  final Map<String, String> extensionSources = {
    "github.com": "https://github.com",
    "gh-proxy.org": "https://gh-proxy.org/https://github.com",

  };

  Future<dynamic> fetchExtensionFromSource(String source) async {
    if (!extensionSources.containsKey(source)) {
      throw Exception("Unsupported extension source: $source");
    }

    String url = extensionSources[source]! + "/Sbqmyy/UnU-Novel-Toolbox-Extensions/blob/main/repo.json";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to load extensions from $source");
      }
    } catch (e) {
      throw Exception("Error fetching extensions from $source: $e");
    }
  }
}