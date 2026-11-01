import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/api_client.dart';
import '../../data/settings_store.dart';
import '../../ui/theme.dart';
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
      const SnackBar(content: Text('Saved'), backgroundColor: ValeraColors.surface2),
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
      setState(() => _testResult = 'Connected');
    } catch (e) {
      if (!mounted) return;
      setState(() => _testResult = 'Failed: $e');
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  InputDecoration _field(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: const TextStyle(color: ValeraColors.muted),
      hintStyle: const TextStyle(color: ValeraColors.muted),
      filled: true,
      fillColor: ValeraColors.surface1,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ValeraColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: ValeraColors.muted),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsStore>();
    final chat = context.watch<ChatController>();

    return Scaffold(
      backgroundColor: ValeraColors.canvas,
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: ValeraColors.divider),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          const Text(
            'Connection',
            style: TextStyle(
              color: ValeraColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _url,
            style: const TextStyle(color: ValeraColors.text),
            decoration: _field('Server URL', hint: 'http://100.x.x.x:8000'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _token,
            obscureText: true,
            style: const TextStyle(color: ValeraColors.text),
            decoration: _field('API token'),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Web search', style: TextStyle(color: ValeraColors.text)),
            subtitle: const Text('SearXNG via gateway', style: TextStyle(color: ValeraColors.muted, fontSize: 13)),
            activeThumbColor: ValeraColors.canvas,
            activeTrackColor: ValeraColors.text,
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
                dropdownColor: ValeraColors.surface2,
                style: const TextStyle(color: ValeraColors.text),
                decoration: _field('Model'),
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
            style: const TextStyle(color: ValeraColors.text),
            decoration: _field('System prompt', hint: 'Leave empty for server default'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: ValeraColors.text,
                  foregroundColor: ValeraColors.canvas,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                child: const Text('Save'),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: _testing ? null : _test,
                style: OutlinedButton.styleFrom(
                  foregroundColor: ValeraColors.text,
                  side: const BorderSide(color: ValeraColors.divider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
                child: _testing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 1.6, color: ValeraColors.muted),
                      )
                    : const Text('Test'),
              ),
            ],
          ),
          if (_testResult != null) ...[
            const SizedBox(height: 14),
            Text(
              _testResult!,
              style: TextStyle(
                color: _testResult == 'Connected' ? const Color(0xFF00BA7C) : const Color(0xFFF4212E),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
