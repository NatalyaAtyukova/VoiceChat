import 'package:project/models/user.dart';

enum MessageType {
  text,
  image,
  voice,
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  read,
  error,
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
  final MessageStatus status;

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
    this.status = MessageStatus.sent,
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
      status: _getMessageStatus(json),
    );
  }

  static MessageStatus _getMessageStatus(Map<String, dynamic> json) {
    if (json['status'] != null) {
      final statusStr = json['status'].toString();
      return MessageStatus.values.firstWhere(
        (e) => e.toString().split('.').last.toLowerCase() == statusStr.toLowerCase(),
        orElse: () => MessageStatus.sent,
      );
    }
    
    // Определяем статус на основе других полей
    if (json['read'] == true) {
      return MessageStatus.read;
    } else if ((json['readBy'] as List?)?.isNotEmpty == true) {
      return MessageStatus.delivered;
    } else {
      return MessageStatus.sent;
    }
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
      'status': status.toString().split('.').last.toLowerCase(),
    };
  }
  
  Message copyWith({
    String? id,
    String? chatId,
    String? senderId,
    MessageType? type,
    String? content,
    String? fileURL,
    int? duration,
    DateTime? timestamp,
    bool? read,
    List<String>? readBy,
    MessageStatus? status,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      type: type ?? this.type,
      content: content ?? this.content,
      fileURL: fileURL ?? this.fileURL,
      duration: duration ?? this.duration,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      readBy: readBy ?? this.readBy,
      status: status ?? this.status,
    );
  }
} 