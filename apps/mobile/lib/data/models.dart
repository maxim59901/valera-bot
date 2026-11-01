class ChatSummary {
  ChatSummary({
    required this.id,
    required this.title,
    this.model,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  String title;
  String? model;
  final String createdAt;
  String updatedAt;

  factory ChatSummary.fromJson(Map<String, dynamic> json) => ChatSummary(
        id: json['id'] as String,
        title: json['title'] as String? ?? 'New chat',
        model: json['model'] as String?,
        createdAt: json['created_at'] as String? ?? '',
        updatedAt: json['updated_at'] as String? ?? '',
      );
}

class ChatMessage {
  ChatMessage({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    this.images,
    this.meta,
    required this.createdAt,
    this.streaming = false,
  });

  final String id;
  final String chatId;
  final String role;
  String content;
  List<String>? images;
  Map<String, dynamic>? meta;
  final String createdAt;
  bool streaming;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        id: json['id'] as String,
        chatId: json['chat_id'] as String,
        role: json['role'] as String,
        content: json['content'] as String? ?? '',
        images: (json['images'] as List?)?.map((e) => e.toString()).toList(),
        meta: json['meta'] as Map<String, dynamic>?,
        createdAt: json['created_at'] as String? ?? '',
      );

  ChatMessage copy() => ChatMessage(
        id: id,
        chatId: chatId,
        role: role,
        content: content,
        images: images == null ? null : List<String>.from(images!),
        meta: meta == null ? null : Map<String, dynamic>.from(meta!),
        createdAt: createdAt,
        streaming: streaming,
      );
}

class OllamaModel {
  OllamaModel({required this.name, this.size, this.modifiedAt});

  final String name;
  final int? size;
  final String? modifiedAt;

  factory OllamaModel.fromJson(Map<String, dynamic> json) => OllamaModel(
        name: json['name'] as String,
        size: json['size'] as int?,
        modifiedAt: json['modified_at'] as String?,
      );
}
