import 'package:project/models/user.dart';

enum MessageType {
  text,
  image,
  voice,
}

class Message {
  final String id;
  final String chatId;
  final String senderId;
  final MessageType type;
  final String content;
  final String? fileURL;
  final int? duration;
  final DateTime timestamp;
  final bool read;
  final List<String> readBy;

  Message({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.type,
    required this.content,
    this.fileURL,
    this.duration,
    required this.timestamp,
    this.read = false,
    this.readBy = const [],
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? json['id'],
      chatId: json['chatId'],
      senderId: json['senderId'],
      type: MessageType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => MessageType.text,
      ),
      content: json['content'],
      fileURL: json['fileURL'],
      duration: json['duration'],
      timestamp: DateTime.parse(json['timestamp'] ?? json['createdAt']),
      read: json['read'] ?? false,
      readBy: List<String>.from(json['readBy'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'type': type.toString().split('.').last,
      'content': content,
      'fileURL': fileURL,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
      'read': read,
      'readBy': readBy,
    };
  }
} 