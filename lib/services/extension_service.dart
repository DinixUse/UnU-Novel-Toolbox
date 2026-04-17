import 'dart:convert';

import 'package:http/http.dart' as http;

class ExtensionService {
  ExtensionService._PrivateConstructor();
  static final ExtensionService _instance =
      ExtensionService._PrivateConstructor();

  static ExtensionService get instance => _instance;

  final Map<String, String> extensionSources = {
    "Github": "https://raw.githubusercontent.com",
    "Gh-Proxy": "https://gh-proxy.org/https://raw.githubusercontent.com"
  };

  Future<dynamic> fetchExtensionFromSource(String source) async {
    if (!extensionSources.containsKey(source)) {
      throw Exception("Unsupported extension source: $source");
    }

    String url = "${extensionSources[source]!}/Sbqmyy/UnU-Novel-Toolbox-Extensions/refs/heads/main/repo.json";

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
}