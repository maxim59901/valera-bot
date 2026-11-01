import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/chat_controller.dart';
import '../features/settings/settings_page.dart';
import 'chat_pane.dart';
import 'sidebar.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    return Scaffold(
      appBar: wide
          ? null
          : AppBar(
              title: const Text('Valera Bot'),
              actions: [
                IconButton(
                  tooltip: 'Settings',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    );
                  },
                  icon: const Icon(Icons.settings_outlined),
                ),
              ],
            ),
      drawer: wide
          ? null
          : Drawer(
              child: Sidebar(
                onOpenSettings: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                },
              ),
            ),
      body: wide
          ? Row(
              children: [
                SizedBox(
                  width: 280,
                  child: Sidebar(
                    onOpenSettings: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                ),
                Container(width: 1, color: Theme.of(context).dividerColor),
                const Expanded(child: ChatPane()),
              ],
            )
          : const ChatPane(),
      floatingActionButton: wide
          ? null
          : FloatingActionButton.extended(
              onPressed: () => context.read<ChatController>().newChat(),
              icon: const Icon(Icons.add),
              label: const Text('New chat'),
            ),
    );
  }
}
