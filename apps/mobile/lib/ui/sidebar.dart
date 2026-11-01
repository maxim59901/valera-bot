import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/chat_controller.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    return ColoredBox(
      color: const Color(0xFF15171C),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Valera Bot',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.3,
                        ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: onOpenSettings,
                    icon: const Icon(Icons.settings_outlined, size: 20),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: FilledButton.tonalIcon(
                onPressed: chat.sending ? null : () => chat.newChat(),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('New chat'),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Chats',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: const Color(0xFF9AA0A6),
                    ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: chat.loadingChats && chat.chats.isEmpty
                  ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                  : ListView.builder(
                      itemCount: chat.chats.length,
                      itemBuilder: (context, i) {
                        final c = chat.chats[i];
                        final selected = c.id == chat.activeChatId;
                        return ListTile(
                          dense: true,
                          selected: selected,
                          selectedTileColor: const Color(0xFF1C1F26),
                          title: Text(
                            c.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () {
                            chat.openChat(c.id);
                            if (Scaffold.maybeOf(context)?.isDrawerOpen == true) {
                              Navigator.pop(context);
                            }
                          },
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => chat.deleteChat(c.id),
                          ),
                        );
                      },
                    ),
            ),
            if (chat.error != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  chat.error!,
                  style: const TextStyle(color: Colors.orangeAccent, fontSize: 12),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
