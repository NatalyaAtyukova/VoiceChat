import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'package:flutter/foundation.dart';

class FirebaseService extends ChangeNotifier {
  final FirebaseAuth auth = FirebaseAuth.instance;
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Auth state stream
  Stream<User?> get authStateChanges => auth.authStateChanges();

  // Auth methods
  Future<UserCredential> signInWithEmailAndPassword(String email, String password) async {
    try {
      print('FirebaseService: Attempting to sign in with email: $email');
      final result = await auth.signInWithEmailAndPassword(email: email, password: password);
      print('FirebaseService: Sign in successful for user: ${result.user?.uid}');
      
      // Обновляем lastSeen пользователя
      if (result.user != null) {
        await firestore.collection('users').doc(result.user!.uid).update({
          'lastSeen': FieldValue.serverTimestamp(),
        });
      }
      
      return result;
    } catch (e) {
      print('FirebaseService: Sign in error: $e');
      rethrow;
    }
  }

  Future<UserCredential> createUserWithEmailAndPassword(String email, String password) async {
    try {
      print('FirebaseService: Attempting to create user with email: $email');
      final result = await auth.createUserWithEmailAndPassword(email: email, password: password);
      print('FirebaseService: User creation successful for user: ${result.user?.uid}');
      return result;
    } catch (e) {
      print('FirebaseService: User creation error: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    await auth.signOut();
  }

  // User profile methods
  Future<bool> isUsernameAvailable(String username) async {
    final result = await firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    return result.docs.isEmpty;
  }

  Future<void> createUserProfile(String userId, String username, String email, {String? displayName}) async {
    try {
      print('FirebaseService: Creating user profile for userId: $userId, username: $username');
      
      // Проверяем, существует ли уже профиль
      final userDoc = await firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        print('FirebaseService: User profile already exists, updating instead');
        await firestore.collection('users').doc(userId).update({
          'username': username,
          'email': email,
          'displayName': displayName ?? username,
          'lastSeen': FieldValue.serverTimestamp(),
        });
      } else {
        // Создаем новый профиль
        await firestore.collection('users').doc(userId).set({
          'username': username,
          'email': email,
          'displayName': displayName ?? username,
          'createdAt': FieldValue.serverTimestamp(),
          'lastSeen': FieldValue.serverTimestamp(),
          'friends': [],
          'friendRequests': [],
        });
      }
      
      print('FirebaseService: User profile created/updated successfully');
    } catch (e) {
      print('FirebaseService: Error creating user profile: $e');
      rethrow;
    }
  }

  Future<void> updateUserProfile(String userId, Map<String, dynamic> data) async {
    await firestore.collection('users').doc(userId).update({
      ...data,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  Future<UserModel?> getUserById(String userId) async {
    final doc = await firestore.collection('users').doc(userId).get();
    if (doc.exists) {
      return UserModel.fromFirestore(doc);
    }
    return null;
  }

  Future<UserModel?> getUserByUsername(String username) async {
    final query = await firestore
        .collection('users')
        .where('username', isEqualTo: username)
        .limit(1)
        .get();
    if (query.docs.isNotEmpty) {
      return UserModel.fromFirestore(query.docs.first);
    }
    return null;
  }

  Stream<UserModel?> userStream(String userId) {
    return firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // Friend methods
  Future<void> sendFriendRequest(String senderId, String receiverId) async {
    try {
      print('FirebaseService: Sending friend request from $senderId to $receiverId');
      
      // Проверяем, не отправлен ли уже запрос
      final receiverDoc = await firestore.collection('users').doc(receiverId).get();
      if (!receiverDoc.exists) {
        throw Exception('User not found');
      }
      
      final receiverData = receiverDoc.data()!;
      final friendRequests = List<String>.from(receiverData['friendRequests'] ?? []);
      
      if (friendRequests.contains(senderId)) {
        print('FirebaseService: Friend request already sent');
        return; // Запрос уже отправлен
      }
      
      // Добавляем запрос
      await firestore.collection('users').doc(receiverId).update({
        'friendRequests': FieldValue.arrayUnion([senderId]),
      });
      
      print('FirebaseService: Friend request sent successfully');
      
      // Уведомляем слушателей об изменении
      notifyListeners();
    } catch (e) {
      print('FirebaseService: Error sending friend request: $e');
      rethrow;
    }
  }

  Future<void> acceptFriendRequest(String userId, String friendId) async {
    // Добавляем друг друга в список друзей
    await firestore.collection('users').doc(userId).update({
      'friends': FieldValue.arrayUnion([friendId]),
      'friendRequests': FieldValue.arrayRemove([friendId]),
    });

    await firestore.collection('users').doc(friendId).update({
      'friends': FieldValue.arrayUnion([userId]),
    });

    // Создаем чат между пользователями
    final chatId = const Uuid().v4();
    await firestore.collection('chats').doc(chatId).set({
      'name': '', // Имя будет формироваться на клиенте
      'type': 'direct',
      'participants': [userId, friendId],
      'createdAt': FieldValue.serverTimestamp(),
      'unreadCount': {},
    });
  }

  Future<void> rejectFriendRequest(String userId, String friendId) async {
    await firestore.collection('users').doc(userId).update({
      'friendRequests': FieldValue.arrayRemove([friendId]),
    });
  }

  Future<void> removeFriend(String userId, String friendId) async {
    // Удаляем друг друга из списка друзей
    await firestore.collection('users').doc(userId).update({
      'friends': FieldValue.arrayRemove([friendId]),
    });

    await firestore.collection('users').doc(friendId).update({
      'friends': FieldValue.arrayRemove([userId]),
    });

    // Находим и удаляем чат между пользователями
    final chats = await firestore
        .collection('chats')
        .where('type', isEqualTo: 'direct')
        .where('participants', arrayContainsAny: [userId, friendId])
        .get();

    for (final chat in chats.docs) {
      final participants = List<String>.from(chat.data()['participants'] ?? []);
      if (participants.contains(userId) && participants.contains(friendId)) {
        await firestore.collection('chats').doc(chat.id).delete();
      }
    }
  }

  Future<void> cancelFriendRequest(String senderId, String receiverId) async {
    try {
      print('FirebaseService: Canceling friend request from $senderId to $receiverId');
      
      // Удаляем запрос из списка запросов получателя
      await firestore.collection('users').doc(receiverId).update({
        'friendRequests': FieldValue.arrayRemove([senderId]),
      });
      
      print('FirebaseService: Friend request canceled successfully');
      
      // Уведомляем слушателей об изменении
      notifyListeners();
    } catch (e) {
      print('FirebaseService: Error canceling friend request: $e');
      rethrow;
    }
  }

  // Search methods
  Future<List<UserModel>> searchUsers(String query, {int limit = 20}) async {
    // Поиск по username
    final usernameQuery = await firestore
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: query)
        .where('username', isLessThanOrEqualTo: query + '\uf8ff')
        .limit(limit)
        .get();

    // Поиск по displayName
    final displayNameQuery = await firestore
        .collection('users')
        .where('displayName', isGreaterThanOrEqualTo: query)
        .where('displayName', isLessThanOrEqualTo: query + '\uf8ff')
        .limit(limit)
        .get();

    // Объединяем результаты
    final Map<String, UserModel> results = {};
    for (final doc in usernameQuery.docs) {
      results[doc.id] = UserModel.fromFirestore(doc);
    }
    for (final doc in displayNameQuery.docs) {
      results[doc.id] = UserModel.fromFirestore(doc);
    }

    return results.values.toList();
  }

  // Chat methods
  Future<List<ChatModel>> getUserChats(String userId) async {
    final query = await firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .get();

    return query.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();
  }

  Stream<List<ChatModel>> userChatsStream(String userId) {
    return firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) => 
            snapshot.docs.map((doc) => ChatModel.fromFirestore(doc)).toList());
  }

  Future<ChatModel?> getChatById(String chatId) async {
    final doc = await firestore.collection('chats').doc(chatId).get();
    if (doc.exists) {
      return ChatModel.fromFirestore(doc);
    }
    return null;
  }

  Future<String> createGroupChat(String creatorId, String name, List<String> participants) async {
    final chatId = const Uuid().v4();
    final allParticipants = [creatorId, ...participants];
    
    await firestore.collection('chats').doc(chatId).set({
      'name': name,
      'type': 'group',
      'participants': allParticipants,
      'createdAt': FieldValue.serverTimestamp(),
      'unreadCount': {},
    });

    return chatId;
  }

  // Message methods
  Stream<List<MessageModel>> getChatMessages(String chatId) {
    return firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MessageModel.fromMap(doc.data()))
            .toList());
  }

  Future<List<MessageModel>> getChatMessagesOnce(String chatId) async {
    final querySnapshot = await firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('timestamp', descending: true)
        .get();

    return querySnapshot.docs
        .map((doc) => MessageModel.fromMap(doc.data()))
        .toList();
  }

  // Отправка сообщения в чат
  Future<void> sendMessage(String chatId, String senderId, String text) async {
    // Создаем новое сообщение
    final messageRef = firestore.collection('chats').doc(chatId).collection('messages').doc();
    final messageData = {
      'id': messageRef.id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
    };

    // Получаем информацию о чате
    final chatDoc = await firestore.collection('chats').doc(chatId).get();
    if (!chatDoc.exists) {
      throw Exception('Chat not found');
    }

    final chatData = chatDoc.data()!;
    final participants = List<String>.from(chatData['participants']);
    final unreadCount = Map<String, int>.from(chatData['unreadCount'] ?? {});

    // Обновляем счетчики непрочитанных сообщений для всех участников, кроме отправителя
    for (final userId in participants) {
      if (userId != senderId) {
        unreadCount[userId] = (unreadCount[userId] ?? 0) + 1;
      }
    }

    // Обновляем информацию о чате
    await firestore.collection('chats').doc(chatId).update({
      'lastMessageText': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount': unreadCount,
    });

    // Сохраняем сообщение
    await messageRef.set(messageData);
  }

  Future<void> markMessagesAsRead(String chatId, String userId) async {
    // Обновляем счетчик непрочитанных сообщений
    await firestore.collection('chats').doc(chatId).update({
      'unreadCount.$userId': 0,
    });

    // Получаем непрочитанные сообщения
    final query = await firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .where('senderId', isNotEqualTo: userId)
        .get();

    // Помечаем сообщения как прочитанные
    final batch = firestore.batch();
    for (final doc in query.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  // Storage methods for media
  Future<String> uploadFile(String path, File file) async {
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(file);
    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> uploadVoiceMessage(String userId, String filePath) async {
    final file = File(filePath);
    final path = 'voice_messages/$userId/${DateTime.now().millisecondsSinceEpoch}';
    return await uploadFile(path, file);
  }

  Future<String> uploadImage(String userId, String filePath) async {
    final file = File(filePath);
    final path = 'images/$userId/${DateTime.now().millisecondsSinceEpoch}';
    return await uploadFile(path, file);
  }
} 