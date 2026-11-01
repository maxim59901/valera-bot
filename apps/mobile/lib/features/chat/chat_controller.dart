import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import '../../data/api_client.dart';
import '../../data/models.dart';
import '../../data/settings_store.dart';

class ChatController extends ChangeNotifier {
  ChatController(this.api, this.settings);

  final ApiClient api;
  final SettingsStore settings;

  List<ChatSummary> chats = [];
  List<ChatMessage> messages = [];
  List<OllamaModel> models = [];
  String? activeChatId;
  bool loadingChats = false;
  bool loadingMessages = false;
  bool sending = false;
  String statusText = '';
  String? error;
  CancelToken? _cancel;

  Future<void> bootstrap() async {
    await refreshChats();
    try {
      models = await api.listModels();
      notifyListeners();
    } catch (_) {
      // Ollama may be offline during first launch
    }
  }

  Future<void> refreshChats() async {
    loadingChats = true;
    error = null;
    notifyListeners();
    try {
      chats = await api.listChats();
      if (activeChatId == null && chats.isNotEmpty) {
        await openChat(chats.first.id);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      loadingChats = false;
      notifyListeners();
    }
  }

  Future<void> openChat(String id) async {
    activeChatId = id;
    loadingMessages = true;
    notifyListeners();
    try {
      messages = await api.listMessages(id);
    } catch (e) {
      error = e.toString();
    } finally {
      loadingMessages = false;
      notifyListeners();
    }
  }

  Future<void> newChat() async {
    try {
      final chat = await api.createChat(model: settings.selectedModel);
      chats.insert(0, chat);
      activeChatId = chat.id;
      messages = [];
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> deleteChat(String id) async {
    try {
      await api.deleteChat(id);
      chats.removeWhere((c) => c.id == id);
      if (activeChatId == id) {
        activeChatId = chats.isEmpty ? null : chats.first.id;
        messages = activeChatId == null ? [] : await api.listMessages(activeChatId!);
      }
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  void _handleSse(String event, Map<String, dynamic> data) {
    switch (event) {
      case 'user_message':
        messages.add(ChatMessage.fromJson(data));
        break;
      case 'assistant_start':
        messages.add(
          ChatMessage(
            id: data['id'] as String,
            chatId: activeChatId ?? '',
            role: 'assistant',
            content: '',
            createdAt: DateTime.now().toIso8601String(),
            streaming: true,
          ),
        );
        statusText = 'Thinking…';
        break;
      case 'token':
        if (messages.isNotEmpty && messages.last.role == 'assistant') {
          messages.last.content += data['content'] as String? ?? '';
        }
        break;
      case 'status':
        final state = data['state'] as String? ?? '';
        if (state == 'searching') {
          statusText = 'Searching: ${data['query'] ?? ''}';
        } else if (state == 'thinking') {
          statusText = 'Thinking…';
        } else {
          statusText = state;
        }
        break;
      case 'search':
        statusText = 'Got web results';
        break;
      case 'chat_updated':
        final id = data['id'] as String?;
        final title = data['title'] as String?;
        if (id != null && title != null) {
          final idx = chats.indexWhere((c) => c.id == id);
          if (idx >= 0) chats[idx].title = title;
        }
        break;
      case 'done':
        if (messages.isNotEmpty && messages.last.role == 'assistant') {
          messages.last.streaming = false;
          messages.last.content = data['content'] as String? ?? messages.last.content;
          messages.last.meta = data['meta'] as Map<String, dynamic>?;
        }
        statusText = '';
        break;
      case 'error':
        error = data['message']?.toString() ?? 'Unknown error';
        statusText = '';
        break;
    }
    notifyListeners();
  }

  Future<void> sendText(String text) async {
    if (text.trim().isEmpty || sending) return;
    if (activeChatId == null) await newChat();
    final chatId = activeChatId;
    if (chatId == null) return;

    sending = true;
    error = null;
    statusText = 'Sending…';
    notifyListeners();

    _cancel = CancelToken();
    await api.sendMessageStream(
      chatId: chatId,
      content: text.trim(),
      model: settings.selectedModel,
      enableSearch: settings.enableSearch,
      systemPrompt: settings.systemPrompt.isEmpty ? null : settings.systemPrompt,
      onEvent: _handleSse,
      onError: (e) {
        error = e.toString();
        statusText = '';
        notifyListeners();
      },
      onDone: () {
        sending = false;
        statusText = '';
        notifyListeners();
        refreshChats();
      },
      cancelToken: _cancel,
    );
  }

  Future<void> sendWithImages(String text, List<File> files) async {
    if (sending) return;
    if (activeChatId == null) await newChat();
    final chatId = activeChatId;
    if (chatId == null) return;

    sending = true;
    error = null;
    statusText = 'Uploading…';
    notifyListeners();

    final multipart = <http.MultipartFile>[];
    for (final f in files) {
      multipart.add(
        await http.MultipartFile.fromPath(
          'files',
          f.path,
          filename: p.basename(f.path),
        ),
      );
    }

    await api.sendVisionStream(
      chatId: chatId,
      content: text.trim().isEmpty ? 'Describe this image.' : text.trim(),
      files: multipart,
      model: settings.selectedModel,
      enableSearch: settings.enableSearch,
      systemPrompt: settings.systemPrompt.isEmpty ? null : settings.systemPrompt,
      onEvent: _handleSse,
      onError: (e) {
        error = e.toString();
        statusText = '';
        notifyListeners();
      },
      onDone: () {
        sending = false;
        statusText = '';
        notifyListeners();
        refreshChats();
      },
    );
  }

  Future<void> generateImage(String prompt) async {
    if (prompt.trim().isEmpty || sending) return;
    if (activeChatId == null) await newChat();
    final chatId = activeChatId;
    if (chatId == null) return;

    sending = true;
    statusText = 'Drawing…';
    error = null;
    notifyListeners();
    try {
      final msg = await api.generateImage(prompt: prompt.trim(), chatId: chatId);
      // Reload to get both user + assistant messages consistently
      messages = await api.listMessages(chatId);
      if (!messages.any((m) => m.id == msg.id)) {
        messages.add(msg);
      }
    } catch (e) {
      error = e.toString();
    } finally {
      sending = false;
      statusText = '';
      notifyListeners();
      await refreshChats();
    }
  }

  Future<void> stop() async {
    await _cancel?.cancel();
    sending = false;
    statusText = '';
    notifyListeners();
  }
}
