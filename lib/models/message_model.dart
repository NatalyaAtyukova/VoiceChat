import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  voice,
  video,
}

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool read;

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.read,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: map['read'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'read': read,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    DateTime? timestamp,
    bool? read,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
    );
  }
} 