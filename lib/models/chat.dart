import 'package:project/models/message.dart';
import 'package:project/models/user.dart';

enum ChatType {
  direct,
  group,
}

class Chat {
  final String id;
  final List<User> participants;
  final Message? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isGroup;
  final String? name;
  final String? photoUrl;
  final User? owner;

  Chat({
    required this.id,
    required this.participants,
    this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
    this.isGroup = false,
    this.name,
    this.photoUrl,
    this.owner,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['_id'] ?? json['id'],
      participants: (json['participants'] as List)
          .map((p) => User.fromJson(p))
          .toList(),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      isGroup: json['isGroup'] ?? false,
      name: json['name'],
      photoUrl: json['photoUrl'] ?? json['photoURL'],
      owner: json['owner'] != null ? User.fromJson(json['owner']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'participants': participants.map((p) => p.toJson()).toList(),
      'lastMessage': lastMessage?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'isGroup': isGroup,
      'name': name,
      'photoUrl': photoUrl,
      'owner': owner?.toJson(),
    };
  }

  User getOtherParticipant(String currentUserId) {
    return participants.firstWhere(
      (user) => user.id != currentUserId,
      orElse: () => participants.first,
    );
  }

  String getDisplayName(String currentUserId) {
    if (isGroup) {
      return name ?? 'Group Chat';
    }
    final other = getOtherParticipant(currentUserId);
    return other.displayName ?? other.username;
  }

  String? getPhotoUrl(String currentUserId) {
    if (isGroup) {
      return photoUrl;
    }
    return getOtherParticipant(currentUserId).photoUrl;
  }
} 