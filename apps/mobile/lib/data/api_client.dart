import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';
import 'settings_store.dart';

typedef SseHandler = void Function(String event, Map<String, dynamic> data);

class CancelToken {
  bool _cancelled = false;
  Future<void> Function()? _onCancel;

  bool get isCancelled => _cancelled;

  void attach(Future<void> Function() onCancel) {
    _onCancel = onCancel;
  }

  Future<void> cancel() async {
    _cancelled = true;
    final fn = _onCancel;
    if (fn != null) await fn();
  }
}

class ApiClient {
  ApiClient(this.settings);

  final SettingsStore settings;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${settings.apiToken}',
        'X-API-Token': settings.apiToken,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };

  Uri _u(String path) {
    final base = settings.serverUrl.replaceAll(RegExp(r'/$'), '');
    return Uri.parse('$base$path');
  }

  Future<void> checkToken() async {
    final resp = await http.post(_u('/auth/token'), headers: _headers);
    if (resp.statusCode != 200) {
      throw Exception('Auth failed (${resp.statusCode}): ${resp.body}');
    }
  }

  Future<List<ChatSummary>> listChats() async {
    final resp = await http.get(_u('/chats'), headers: _headers);
    _ensureOk(resp);
    final list = jsonDecode(resp.body) as List;
    return list.map((e) => ChatSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatSummary> createChat({String title = 'New chat', String? model}) async {
    final resp = await http.post(
      _u('/chats'),
      headers: _headers,
      body: jsonEncode({'title': title, 'model': model}),
    );
    _ensureOk(resp);
    return ChatSummary.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> deleteChat(String id) async {
    final resp = await http.delete(_u('/chats/$id'), headers: _headers);
    _ensureOk(resp);
  }

  Future<List<ChatMessage>> listMessages(String chatId) async {
    final resp = await http.get(_u('/chats/$chatId/messages'), headers: _headers);
    _ensureOk(resp);
    final list = jsonDecode(resp.body) as List;
    return list.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<OllamaModel>> listModels() async {
    final resp = await http.get(_u('/models'), headers: _headers);
    _ensureOk(resp);
    final list = jsonDecode(resp.body) as List;
    return list.map((e) => OllamaModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<ChatMessage> generateImage({
    required String prompt,
    String? chatId,
  }) async {
    final resp = await http.post(
      _u('/images/generate'),
      headers: _headers,
      body: jsonEncode({
        'prompt': prompt,
        'chat_id': chatId,
      }),
    );
    _ensureOk(resp);
    return ChatMessage.fromJson(jsonDecode(resp.body) as Map<String, dynamic>);
  }

  Future<void> sendMessageStream({
    required String chatId,
    required String content,
    String? model,
    bool? enableSearch,
    String? systemPrompt,
    required SseHandler onEvent,
    void Function(Object error)? onError,
    void Function()? onDone,
    CancelToken? cancelToken,
  }) async {
    final client = http.Client();
    StreamSubscription<List<int>>? sub;
    cancelToken?.attach(() async {
      await sub?.cancel();
      client.close();
    });

    try {
      final req = http.Request('POST', _u('/chats/$chatId/messages'));
      req.headers.addAll(_headers);
      req.headers['Accept'] = 'text/event-stream';
      req.body = jsonEncode({
        'content': content,
        'model': model,
        'enable_search': enableSearch,
        if (systemPrompt != null && systemPrompt.isNotEmpty) 'system_prompt': systemPrompt,
      });

      final resp = await client.send(req);
      if (resp.statusCode >= 400) {
        throw Exception('HTTP ${resp.statusCode}');
      }

      final buffer = StringBuffer();
      final completer = Completer<void>();
      sub = resp.stream.listen(
        (chunk) {
          if (cancelToken?.isCancelled == true) return;
          buffer.write(utf8.decode(chunk));
          var raw = buffer.toString();
          while (true) {
            final idx = raw.indexOf('\n\n');
            if (idx < 0) break;
            final block = raw.substring(0, idx);
            raw = raw.substring(idx + 2);
            _parseSseBlock(block, onEvent);
          }
          buffer
            ..clear()
            ..write(raw);
        },
        onError: (e) {
          onError?.call(e);
          if (!completer.isCompleted) completer.complete();
        },
        onDone: () {
          if (!completer.isCompleted) completer.complete();
        },
        cancelOnError: true,
      );
      await completer.future;
      onDone?.call();
    } catch (e) {
      onError?.call(e);
      onDone?.call();
    } finally {
      client.close();
    }
  }

  Future<void> sendVisionStream({
    required String chatId,
    required String content,
    required List<http.MultipartFile> files,
    String? model,
    bool? enableSearch,
    String? systemPrompt,
    required SseHandler onEvent,
    void Function(Object error)? onError,
    void Function()? onDone,
  }) async {
    final uri = _u('/chats/$chatId/vision');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer ${settings.apiToken}';
    req.headers['X-API-Token'] = settings.apiToken;
    req.headers['Accept'] = 'text/event-stream';
    req.fields['content'] = content;
    if (model != null) req.fields['model'] = model;
    if (enableSearch != null) req.fields['enable_search'] = enableSearch.toString();
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      req.fields['system_prompt'] = systemPrompt;
    }
    req.files.addAll(files);

    final client = http.Client();
    try {
      final resp = await client.send(req);
      if (resp.statusCode >= 400) {
        throw Exception('HTTP ${resp.statusCode}');
      }
      final buffer = StringBuffer();
      await for (final chunk in resp.stream) {
        buffer.write(utf8.decode(chunk));
        var raw = buffer.toString();
        while (true) {
          final idx = raw.indexOf('\n\n');
          if (idx < 0) break;
          final block = raw.substring(0, idx);
          raw = raw.substring(idx + 2);
          _parseSseBlock(block, onEvent);
        }
        buffer
          ..clear()
          ..write(raw);
      }
      onDone?.call();
    } catch (e) {
      onError?.call(e);
      onDone?.call();
    } finally {
      client.close();
    }
  }

  void _parseSseBlock(String block, SseHandler onEvent) {
    String event = 'message';
    final dataLines = <String>[];
    for (final line in block.split('\n')) {
      if (line.startsWith('event:')) {
        event = line.substring(6).trim();
      } else if (line.startsWith('data:')) {
        dataLines.add(line.substring(5).trim());
      }
    }
    if (dataLines.isEmpty) return;
    final raw = dataLines.join('\n');
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      onEvent(event, data);
    } catch (_) {
      onEvent(event, {'raw': raw});
    }
  }

  void _ensureOk(http.Response resp) {
    if (resp.statusCode >= 400) {
      throw Exception('HTTP ${resp.statusCode}: ${resp.body}');
    }
  }
}
