import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/chat/chat_controller.dart';
import '../features/settings/settings_page.dart';
import 'theme.dart';

class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    this.onOpenSettings,
    this.embedded = false,
  });

  final VoidCallback? onOpenSettings;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();

    return ColoredBox(
      color: ValeraColors.canvas,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
              child: Row(
                children: [
                  const Text(
                    'Valera',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                      color: ValeraColors.text,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Settings',
                    onPressed: onOpenSettings ??
                        () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsPage()),
                          );
                        },
                    icon: const Icon(Icons.settings_outlined, size: 20, color: ValeraColors.muted),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Material(
                color: ValeraColors.surface1,
                borderRadius: BorderRadius.circular(999),
                child: InkWell(
                  borderRadius: BorderRadius.circular(999),
                  onTap: chat.sending ? null : () => chat.newChat(),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Icon(Icons.edit_square, size: 18, color: ValeraColors.text),
                        SizedBox(width: 10),
                        Text(
                          'New chat',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: ValeraColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'History',
                style: TextStyle(
                  color: ValeraColors.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: chat.loadingChats && chat.chats.isEmpty
                  ? const Center(
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          color: ValeraColors.muted,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      itemCount: chat.chats.length,
                      separatorBuilder: (context, index) => const Divider(
                        height: 1,
                        thickness: 0.5,
                        color: ValeraColors.divider,
                        indent: 10,
                        endIndent: 10,
                      ),
                      itemBuilder: (context, i) {
                        final c = chat.chats[i];
                        final selected = c.id == chat.activeChatId;
                        return Material(
                          color: selected ? ValeraColors.surface1 : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () {
                              chat.openChat(c.id);
                              if (!embedded && Scaffold.maybeOf(context)?.isDrawerOpen == true) {
                                Navigator.pop(context);
                              }
                            },
                            onLongPress: () => chat.deleteChat(c.id),
                            child: SizedBox(
                              height: 52,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        c.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                                          color: ValeraColors.text,
                                        ),
                                      ),
                                    ),
                                    if (selected)
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        iconSize: 16,
                                        color: ValeraColors.muted,
                                        onPressed: () => chat.deleteChat(c.id),
                                        icon: const Icon(Icons.close_rounded),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            if (chat.error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                child: Text(
                  chat.error!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Color(0xFFF4212E), fontSize: 12),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
