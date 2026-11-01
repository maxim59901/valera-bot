import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../data/settings_store.dart';
import '../features/chat/chat_controller.dart';
import 'theme.dart';

class ChatPane extends StatefulWidget {
  const ChatPane({super.key});

  @override
  State<ChatPane> createState() => _ChatPaneState();
}

class _ChatPaneState extends State<ChatPane> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  final List<File> _pendingImages = [];
  bool _imageMode = false;

  static const _suggestions = [
    'Explain this like I’m five',
    'Help me debug an idea',
    'What’s happening in the world?',
    'Write something sharp and short',
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
      );
    });
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 88);
    if (files.isNotEmpty) {
      setState(() => _pendingImages.addAll(files.map((x) => File(x.path))));
      return;
    }
    final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: true);
    if (result != null) {
      setState(() {
        for (final f in result.files) {
          if (f.path != null) _pendingImages.add(File(f.path!));
        }
      });
    }
  }

  Future<void> _send([String? preset]) async {
    final text = preset ?? _controller.text;
    final chat = context.read<ChatController>();
    if ((text.trim().isEmpty && _pendingImages.isEmpty) || chat.sending) return;

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
    final empty = chat.activeChatId == null || (chat.messages.isEmpty && !chat.sending);
    if (chat.messages.isNotEmpty || chat.statusText.isNotEmpty) _scrollToEnd();

    return ColoredBox(
      color: ValeraColors.canvas,
      child: Column(
        children: [
          Expanded(
            child: empty
                ? _EmptyHero(
                    suggestions: _suggestions,
                    onSuggestion: (s) {
                      _controller.text = s;
                      _send(s);
                    },
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    itemCount: chat.messages.length + (chat.statusText.isNotEmpty ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (chat.statusText.isNotEmpty && index == chat.messages.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 10, left: 2),
                          child: Text(
                            chat.statusText,
                            style: const TextStyle(
                              color: ValeraColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }
                      final msg = chat.messages[index];
                      return _TranscriptMessage(
                        role: msg.role,
                        content: msg.content,
                        images: msg.images,
                        mediaResolver: settings.mediaUrl,
                        streaming: msg.streaming,
                      );
                    },
                  ),
          ),
          _Composer(
            controller: _controller,
            focusNode: _focus,
            pendingImages: _pendingImages,
            imageMode: _imageMode,
            sending: chat.sending,
            onToggleImageMode: (v) => setState(() => _imageMode = v),
            onPickImages: _pickImages,
            onRemoveImage: (i) => setState(() => _pendingImages.removeAt(i)),
            onSend: () => _send(),
            onStop: chat.stop,
          ),
        ],
      ),
    );
  }
}

class _EmptyHero extends StatelessWidget {
  const _EmptyHero({required this.suggestions, required this.onSuggestion});

  final List<String> suggestions;
  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Valera',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.4,
                color: ValeraColors.text,
                height: 1,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Ask anything.',
              style: TextStyle(
                fontSize: 16,
                color: ValeraColors.muted,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 36),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in suggestions)
                  _SuggestionChip(label: s, onTap: () => onSuggestion(s)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SuggestionChip extends StatelessWidget {
  const _SuggestionChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: ValeraColors.surface1,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: ValeraColors.divider),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 13, color: ValeraColors.text),
          ),
        ),
      ),
    );
  }
}

class _TranscriptMessage extends StatelessWidget {
  const _TranscriptMessage({
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
    final mdStyle = MarkdownStyleSheet(
      p: const TextStyle(
        fontSize: 16,
        height: 1.45,
        color: ValeraColors.text,
        fontWeight: FontWeight.w400,
      ),
      a: const TextStyle(color: ValeraColors.link),
      code: const TextStyle(
        fontFamily: 'monospace',
        backgroundColor: ValeraColors.surface1,
        color: ValeraColors.text,
        fontSize: 13.5,
      ),
      codeblockDecoration: BoxDecoration(
        color: ValeraColors.surface1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ValeraColors.divider),
      ),
      blockquoteDecoration: const BoxDecoration(
        border: Border(left: BorderSide(color: ValeraColors.divider, width: 3)),
      ),
      h1: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: ValeraColors.text),
      h2: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: ValeraColors.text),
      h3: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: ValeraColors.text),
      listBullet: const TextStyle(color: ValeraColors.text, fontSize: 16),
    );

    final body = Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        if (images != null)
          ...images!.map(
            (img) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: img.startsWith('/') || img.startsWith('http')
                    ? Image.network(
                        mediaResolver(img),
                        height: 240,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        if (content.isNotEmpty || streaming)
          MarkdownBody(
            data: content.isEmpty && streaming ? '▍' : (content + (streaming ? ' ▍' : '')),
            selectable: true,
            styleSheet: mdStyle,
          ),
      ],
    );

    if (isUser) {
      return Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: const BoxDecoration(
            color: ValeraColors.surface1,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
              bottomLeft: Radius.circular(20),
              bottomRight: Radius.circular(6),
            ),
          ),
          child: body,
        ),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 14),
        constraints: const BoxConstraints(maxWidth: 720),
        child: body,
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.pendingImages,
    required this.imageMode,
    required this.sending,
    required this.onToggleImageMode,
    required this.onPickImages,
    required this.onRemoveImage,
    required this.onSend,
    required this.onStop,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<File> pendingImages;
  final bool imageMode;
  final bool sending;
  final ValueChanged<bool> onToggleImageMode;
  final VoidCallback onPickImages;
  final ValueChanged<int> onRemoveImage;
  final VoidCallback onSend;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 0, 12, 10 + bottom),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pendingImages.isNotEmpty)
                SizedBox(
                  height: 70,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: pendingImages.length,
                    separatorBuilder: (context, index) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              pendingImages[i],
                              width: 58,
                              height: 58,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: -6,
                            top: -6,
                            child: GestureDetector(
                              onTap: () => onRemoveImage(i),
                              child: Container(
                                decoration: const BoxDecoration(
                                  color: ValeraColors.surface2,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2),
                                child: const Icon(Icons.close, size: 14, color: ValeraColors.text),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              Container(
                decoration: BoxDecoration(
                  color: ValeraColors.surface1,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: ValeraColors.divider),
                ),
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                child: Column(
                  children: [
                    TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 7,
                      style: const TextStyle(fontSize: 16, color: ValeraColors.text, height: 1.35),
                      cursorColor: ValeraColors.text,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      decoration: InputDecoration(
                        hintText: imageMode ? 'Describe an image…' : 'Ask Valera anything',
                        hintStyle: const TextStyle(color: ValeraColors.muted, fontSize: 16),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          tooltip: imageMode ? 'Chat mode' : 'Imagine',
                          onPressed: () => onToggleImageMode(!imageMode),
                          icon: Icon(
                            imageMode ? Icons.chat_bubble_outline_rounded : Icons.auto_awesome_outlined,
                            size: 20,
                            color: imageMode ? ValeraColors.text : ValeraColors.muted,
                          ),
                        ),
                        if (!imageMode)
                          IconButton(
                            tooltip: 'Attach',
                            onPressed: sending ? null : onPickImages,
                            icon: const Icon(Icons.add_circle_outline, size: 22, color: ValeraColors.muted),
                          ),
                        const Spacer(),
                        if (sending)
                          TextButton(
                            onPressed: onStop,
                            style: TextButton.styleFrom(foregroundColor: ValeraColors.muted),
                            child: const Text('Stop'),
                          ),
                        const SizedBox(width: 4),
                        Material(
                          color: ValeraColors.text,
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: sending ? null : onSend,
                            child: SizedBox(
                              width: 36,
                              height: 36,
                              child: Icon(
                                imageMode ? Icons.brush_rounded : Icons.arrow_upward_rounded,
                                size: 20,
                                color: sending ? ValeraColors.muted : ValeraColors.canvas,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
