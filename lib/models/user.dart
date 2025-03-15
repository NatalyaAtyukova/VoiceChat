class User {
  final String id;
  final String email;
  final String username;
  final String? displayName;
  final String? photoUrl;
  final List<String> friends;
  final List<String> friendRequests;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.username,
    this.displayName,
    this.photoUrl,
    this.friends = const [],
    this.friendRequests = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['_id'] ?? json['id'],
      email: json['email'],
      username: json['username'],
      displayName: json['displayName'],
      photoUrl: json['photoUrl'] ?? json['photoURL'],
      friends: List<String>.from(json['friends'] ?? []),
      friendRequests: List<String>.from(json['friendRequests'] ?? []),
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'friends': friends,
      'friendRequests': friendRequests,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
} 