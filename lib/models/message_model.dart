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
  final MessageType type;
  final String? mediaUrl;
  final int? duration; // Длительность голосового сообщения в секундах

  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.read,
    this.type = MessageType.text,
    this.mediaUrl,
    this.duration,
  });

  factory MessageModel.fromMap(Map<String, dynamic> map) {
    return MessageModel(
      id: map['id'] ?? '',
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: map['read'] ?? false,
      type: _getMessageTypeFromString(map['type'] ?? 'text'),
      mediaUrl: map['mediaUrl'],
      duration: map['duration'],
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
      'type': type.toString().split('.').last,
      'mediaUrl': mediaUrl,
      'duration': duration,
    };
  }

  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    DateTime? timestamp,
    bool? read,
    MessageType? type,
    String? mediaUrl,
    int? duration,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      read: read ?? this.read,
      type: type ?? this.type,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      duration: duration ?? this.duration,
    );
  }
  
  static MessageType _getMessageTypeFromString(String typeStr) {
    switch (typeStr) {
      case 'image':
        return MessageType.image;
      case 'voice':
        return MessageType.voice;
      case 'video':
        return MessageType.video;
      case 'text':
      default:
        return MessageType.text;
    }
  }
} 