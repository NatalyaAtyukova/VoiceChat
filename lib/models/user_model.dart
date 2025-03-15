import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String username; // Уникальный логин
  final String email;
  final String? displayName;
  final String? photoUrl;
  final String? bio;
  final List<String> friends;
  final List<String> friendRequests;
  final DateTime createdAt;
  final DateTime lastSeen;

  UserModel({
    required this.id,
    required this.username,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.bio,
    List<String>? friends,
    List<String>? friendRequests,
    DateTime? createdAt,
    DateTime? lastSeen,
  }) : 
    this.friends = friends ?? [],
    this.friendRequests = friendRequests ?? [],
    this.createdAt = createdAt ?? DateTime.now(),
    this.lastSeen = lastSeen ?? DateTime.now();

  // Создание из Firestore документа
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      username: data['username'] ?? '',
      email: data['email'] ?? '',
      displayName: data['displayName'],
      photoUrl: data['photoUrl'],
      bio: data['bio'],
      friends: List<String>.from(data['friends'] ?? []),
      friendRequests: List<String>.from(data['friendRequests'] ?? []),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lastSeen: (data['lastSeen'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  // Преобразование в Map для сохранения в Firestore
  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'bio': bio,
      'friends': friends,
      'friendRequests': friendRequests,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastSeen': Timestamp.fromDate(lastSeen),
    };
  }

  // Создание копии с обновленными полями
  UserModel copyWith({
    String? username,
    String? email,
    String? displayName,
    String? photoUrl,
    String? bio,
    List<String>? friends,
    List<String>? friendRequests,
    DateTime? lastSeen,
  }) {
    return UserModel(
      id: this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      bio: bio ?? this.bio,
      friends: friends ?? this.friends,
      friendRequests: friendRequests ?? this.friendRequests,
      createdAt: this.createdAt,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
} 