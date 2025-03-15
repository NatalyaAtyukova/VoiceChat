import 'package:cloud_firestore/cloud_firestore.dart';

enum ChatType {
  direct, // Личный чат между двумя пользователями
  group,  // Групповой чат
}

class ChatModel {
  final String id;
  final String name;
  final ChatType type;
  final List<String> participants;
  final String? lastMessageId;
  final String? lastMessageText;
  final DateTime? lastMessageTime;
  final Map<String, int> unreadCount;
  final DateTime createdAt;
  final Map<String, dynamic>? metadata;

  ChatModel({
    required this.id,
    required this.name,
    required this.type,
    required this.participants,
    this.lastMessageId,
    this.lastMessageText,
    this.lastMessageTime,
    Map<String, int>? unreadCount,
    DateTime? createdAt,
    this.metadata,
  }) : 
    this.unreadCount = unreadCount ?? {},
    this.createdAt = createdAt ?? DateTime.now();

  // Создание из Firestore документа
  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return ChatModel(
      id: doc.id,
      name: data['name'] ?? '',
      type: _getChatType(data['type']),
      participants: List<String>.from(data['participants'] ?? []),
      lastMessageId: data['lastMessageId'],
      lastMessageText: data['lastMessageText'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCount: Map<String, int>.from(data['unreadCount'] ?? {}),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      metadata: data['metadata'],
    );
  }

  // Преобразование в Map для сохранения в Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'type': type.toString().split('.').last,
      'participants': participants,
      'lastMessageId': lastMessageId,
      'lastMessageText': lastMessageText,
      'lastMessageTime': lastMessageTime != null ? Timestamp.fromDate(lastMessageTime!) : null,
      'unreadCount': unreadCount,
      'createdAt': Timestamp.fromDate(createdAt),
      'metadata': metadata,
    };
  }

  // Вспомогательный метод для преобразования строки в ChatType
  static ChatType _getChatType(String? type) {
    switch (type) {
      case 'group':
        return ChatType.group;
      case 'direct':
      default:
        return ChatType.direct;
    }
  }

  // Создание копии с обновленными полями
  ChatModel copyWith({
    String? name,
    ChatType? type,
    List<String>? participants,
    String? lastMessageId,
    String? lastMessageText,
    DateTime? lastMessageTime,
    Map<String, int>? unreadCount,
    Map<String, dynamic>? metadata,
  }) {
    return ChatModel(
      id: this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      participants: participants ?? this.participants,
      lastMessageId: lastMessageId ?? this.lastMessageId,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: this.createdAt,
      metadata: metadata ?? this.metadata,
    );
  }
} 