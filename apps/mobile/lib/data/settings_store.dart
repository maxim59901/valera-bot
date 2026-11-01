import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsStore extends ChangeNotifier {
  String serverUrl = 'http://127.0.0.1:8000';
  String apiToken = 'dev-local-token-change-me';
  String? selectedModel;
  bool enableSearch = true;
  String systemPrompt = '';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    serverUrl = prefs.getString('serverUrl') ?? serverUrl;
    apiToken = prefs.getString('apiToken') ?? apiToken;
    selectedModel = prefs.getString('selectedModel');
    enableSearch = prefs.getBool('enableSearch') ?? true;
    systemPrompt = prefs.getString('systemPrompt') ?? '';
    notifyListeners();
  }

  Future<void> save({
    String? serverUrl,
    String? apiToken,
    String? selectedModel,
    bool? enableSearch,
    String? systemPrompt,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (serverUrl != null) {
      this.serverUrl = serverUrl.trim().replaceAll(RegExp(r'/$'), '');
      await prefs.setString('serverUrl', this.serverUrl);
    }
    if (apiToken != null) {
      this.apiToken = apiToken.trim();
      await prefs.setString('apiToken', this.apiToken);
    }
    if (selectedModel != null) {
      this.selectedModel = selectedModel.isEmpty ? null : selectedModel;
      if (this.selectedModel == null) {
        await prefs.remove('selectedModel');
      } else {
        await prefs.setString('selectedModel', this.selectedModel!);
      }
    }
    if (enableSearch != null) {
      this.enableSearch = enableSearch;
      await prefs.setBool('enableSearch', enableSearch);
    }
    if (systemPrompt != null) {
      this.systemPrompt = systemPrompt;
      await prefs.setString('systemPrompt', systemPrompt);
    }
    notifyListeners();
  }

  String mediaUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    if (path.startsWith('/')) return '$serverUrl$path';
    return '$serverUrl/$path';
  }
}
