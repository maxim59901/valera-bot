import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/settings_store.dart';
import '../chat/chat_controller.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _url;
  late final TextEditingController _token;
  late final TextEditingController _prompt;
  String? _testResult;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<SettingsStore>();
    _url = TextEditingController(text: s.serverUrl);
    _token = TextEditingController(text: s.apiToken);
    _prompt = TextEditingController(text: s.systemPrompt);
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    _prompt.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final settings = context.read<SettingsStore>();
    await settings.save(
      serverUrl: _url.text,
      apiToken: _token.text,
      systemPrompt: _prompt.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved')),
    );
    await context.read<ChatController>().bootstrap();
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    final settings = context.read<SettingsStore>();
    await settings.save(serverUrl: _url.text, apiToken: _token.text);
    final api = context.read<ApiClient>();
    try {
      await api.checkToken();
      if (!mounted) return;
      setState(() => _testResult = 'OK — token accepted');
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = 'Fail: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final chat = context.watch<ChatController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text('Valera Bot', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Подключение к вашему Linux-шлюзу и Ollama.',
            style: TextStyle(color: Color(0xFF9AA0A6)),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'Server URL',
              hintText: 'http://100.x.x.x:8000',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'API token'),
          ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Web search'),
            subtitle: const Text('SearXNG через шлюз'),
            value: settings.enableSearch,
            onChanged: (v) => settings.save(enableSearch: v),
          ),
          const SizedBox(height: 8),
          Builder(
            builder: (context) {
              final names = chat.models.map((m) => m.name).toSet();
              final current = settings.selectedModel;
              final value = (current != null && names.contains(current)) ? current : '';
              return DropdownButtonFormField<String>(
                initialValue: value,
                decoration: const InputDecoration(labelText: 'Ollama model'),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Server default')),
                  ...chat.models.map(
                    (m) => DropdownMenuItem(value: m.name, child: Text(m.name)),
                  ),
                ],
                onChanged: (v) => settings.save(selectedModel: v ?? ''),
              );
            },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _prompt,
            minLines: 3,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'System prompt (optional override)',
              hintText: 'Оставьте пустым — будет дефолт Valera Bot на сервере',
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              FilledButton(onPressed: _save, child: const Text('Save')),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _testing ? null : _test,
                child: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Test connection'),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 12),
            Text(_testResult!),
          ],
        ],
      ),
    );
  }
}
