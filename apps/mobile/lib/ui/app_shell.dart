import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/chat_controller.dart';
import '../features/settings/settings_page.dart';
import 'chat_pane.dart';
import 'sidebar.dart';
import 'theme.dart';

class AppShell extends StatelessWidget {
  const AppShell({super.key});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 960;
    final chat = context.watch<ChatController>();

    return Scaffold(
      backgroundColor: ValeraColors.canvas,
      drawer: wide
          ? null
          : Drawer(
              width: MediaQuery.sizeOf(context).width * 0.84,
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
                const SizedBox(
                  width: 260,
                  child: Sidebar(embedded: true),
                ),
                Container(width: 0.5, color: ValeraColors.divider),
                const Expanded(child: ChatPane()),
              ],
            )
          : Column(
              children: [
                SafeArea(
                  bottom: false,
                  child: SizedBox(
                    height: 48,
                    child: Row(
                      children: [
                        const SizedBox(width: 4),
                        Builder(
                          builder: (ctx) => IconButton(
                            tooltip: 'History',
                            onPressed: () => Scaffold.of(ctx).openDrawer(),
                            icon: const Icon(Icons.menu_rounded),
                          ),
                        ),
                        const Spacer(),
                        _ModePill(
                          imageMode: false,
                          // visual only in top bar; real toggle lives in composer
                          onChanged: (_) {},
                          staticLabel: true,
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'New chat',
                          onPressed: chat.sending ? null : () => chat.newChat(),
                          icon: const Icon(Icons.edit_square),
                        ),
                        IconButton(
                          tooltip: 'Settings',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SettingsPage()),
                            );
                          },
                          icon: const Icon(Icons.settings_outlined, size: 22),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ),
                ),
                Container(height: 0.5, color: ValeraColors.divider.withValues(alpha: 0.6)),
                const Expanded(child: ChatPane()),
              ],
            ),
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.imageMode,
    required this.onChanged,
    this.staticLabel = false,
  });

  final bool imageMode;
  final ValueChanged<bool> onChanged;
  final bool staticLabel;

  @override
  Widget build(BuildContext context) {
    if (staticLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: ValeraColors.surface1,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: ValeraColors.divider),
        ),
        child: const Text(
          'Valera',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: ValeraColors.text,
            letterSpacing: -0.2,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
