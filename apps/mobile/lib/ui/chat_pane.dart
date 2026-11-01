import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/settings_store.dart';
import '../features/chat/chat_controller.dart';

class ChatPane extends StatefulWidget {
  const ChatPane({super.key});

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<File> _pendingImages = [];
  bool _imageMode = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null) {
        setState(() {
          for (final f in result.files) {
            if (f.path != null) _pendingImages.add(File(f.path!));
          }
        });
      }
      return;
    }
    setState(() {
      _pendingImages.addAll(files.map((x) => File(x.path)));
    });
  }

  Future<void> _send() async {
    final text = _controller.text;
    final chat = context.read<ChatController>();
    if (_imageMode) {
      await chat.generateImage(text);
    } else if (_pendingImages.isNotEmpty) {
      await chat.sendWithImages(text, List<File>.from(_pendingImages));
      setState(() => _pendingImages.clear());
    } else {
      await chat.sendText(text);
    }
    _controller.clear();
    _scrollToEnd();
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatController>();
    final settings = context.watch<SettingsStore>();
    _scrollToEnd();

    return ColoredBox(
      color: const Color(0xFF0B0C0F),
      child: Column(
        children: [
          Expanded(
            child: chat.activeChatId == null
                ? _EmptyState(onNew: chat.newChat)
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    itemCount: chat.messages.length + (chat.statusText.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (chat.statusText.isNotEmpty && index == chat.messages.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, left: 8),
                          child: Text(
                            chat.statusText,
                            style: const TextStyle(color: Color(0xFF9AA0A6), fontSize: 13),
                          ),
                        );
                      }
                      final msg = chat.messages[index];
                      return _MessageBubble(
                        role: msg.role,
                        content: msg.content,
                        images: msg.images,
                        mediaResolver: settings.mediaUrl,
                        streaming: msg.streaming,
                      );
                    },
                  ),
          ),
          if (_pendingImages.isNotEmpty)
            SizedBox(
              height: 72,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: _pendingImages.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.file(_pendingImages[i], width: 64, height: 64, fit: BoxFit.cover),
                      ),
                      Positioned(
                        right: -4,
                        top: -4,
                        child: IconButton(
                          iconSize: 18,
                          onPressed: () => setState(() => _pendingImages.removeAt(i)),
                          icon: const Icon(Icons.cancel, color: Colors.white70),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 820),
                child: Column(
                  children: [
                    Row(
                      children: [
                        FilterChip(
                          label: const Text('Image gen'),
                          selected: _imageMode,
                          onSelected: (v) => setState(() => _imageMode = v),
                        ),
                        const SizedBox(width: 8),
                        if (!_imageMode)
                          IconButton(
                            tooltip: 'Attach image',
                            onPressed: chat.sending ? null : _pickImages,
                            icon: const Icon(Icons.image_outlined),
                          ),
                        const Spacer(),
                        if (chat.sending)
                          TextButton(
                            onPressed: chat.stop,
                            child: const Text('Stop'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            minLines: 1,
                            maxLines: 6,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _send(),
                            decoration: InputDecoration(
                              hintText: _imageMode
                                  ? 'Describe an image to generate…'
                                  : 'Message Valera Bot…',
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton(
                          onPressed: chat.sending ? null : _send,
                          style: FilledButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(14),
                          ),
                          child: Icon(_imageMode ? Icons.brush : Icons.arrow_upward),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onNew});

  final VoidCallback onNew;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Valera Bot',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5,
                  ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Личный ассистент на вашем Ollama-сервере.\nЧат, vision, поиск и генерация картинок.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF9AA0A6)),
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onNew,
              child: const Text('Начать чат'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.role,
    required this.content,
    required this.mediaResolver,
    this.images,
    this.streaming = false,
  });

  final String role;
  final String content;
  final List<String>? images;
  final String Function(String) mediaResolver;
  final bool streaming;

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            color: isUser ? const Color(0xFF1C1F26) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUser ? 'You' : 'Valera',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9AA0A6),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              if (images != null)
                ...images!.map(
                  (img) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: img.startsWith('/') || img.startsWith('http')
                          ? Image.network(
                              mediaResolver(img),
                              height: 220,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => const Text('[image]'),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              if (content.isNotEmpty)
                MarkdownBody(
                  data: content + (streaming ? ' ▍' : ''),
                  selectable: true,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: const TextStyle(fontSize: 15.5, height: 1.45),
                    code: const TextStyle(
                      backgroundColor: Color(0xFF15171C),
                      fontFamily: 'Consolas',
                    ),
                  ),
                )
              else if (streaming)
                const Text('▍', style: TextStyle(color: Color(0xFF9AA0A6))),
            ],
          ),
        ),
      ),
    );
  }
}
