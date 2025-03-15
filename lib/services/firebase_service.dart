import 'dart:io';
import 'dart:typed_data';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';
import '../models/user_model.dart';
import '../models/chat_model.dart';
import '../models/message_model.dart';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

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
    print('Getting chats for user: $userId');
    
    try {
      // Сначала пробуем получить чаты с сортировкой по lastMessageTime
      try {
        final query = await firestore
            .collection('chats')
            .where('participants', arrayContains: userId)
            .orderBy('lastMessageTime', descending: true)
            .get();
        
        print('Found ${query.docs.length} chat documents with lastMessageTime');
        
        final chats = query.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();
        print('Converted to ${chats.length} ChatModel objects');
        
        return chats;
      } catch (e) {
        print('Error getting chats with lastMessageTime: $e');
        
        // Если произошла ошибка (возможно, из-за отсутствия поля lastMessageTime),
        // получаем чаты без сортировки
        final query = await firestore
            .collection('chats')
            .where('participants', arrayContains: userId)
            .get();
        
        print('Found ${query.docs.length} chat documents without sorting');
        
        final chats = query.docs.map((doc) => ChatModel.fromFirestore(doc)).toList();
        print('Converted to ${chats.length} ChatModel objects');
        
        return chats;
      }
    } catch (e) {
      print('Error in getUserChats: $e');
      return [];
    }
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

  Future<String> createDirectChat(String userId1, String userId2) async {
    print('Creating direct chat between $userId1 and $userId2');
    
    try {
      // Сначала проверяем, существует ли уже чат между этими пользователями,
      // используя прямой запрос к Firestore
      print('Checking for existing direct chat...');
      final directChatQuery = await firestore
          .collection('chats')
          .where('type', isEqualTo: 'direct')
          .where('participants', arrayContains: userId1)
          .get();
      
      print('Found ${directChatQuery.docs.length} chats containing user $userId1');
      
      // Проверяем каждый чат, содержит ли он обоих пользователей
      for (final doc in directChatQuery.docs) {
        final data = doc.data();
        final participants = List<String>.from(data['participants'] ?? []);
        
        print('Checking chat ${doc.id}, participants: $participants');
        
        if (participants.contains(userId2)) {
          print('Found existing chat: ${doc.id}');
          
          // Проверяем, есть ли поле lastMessageTime, и если нет, добавляем его
          if (data['lastMessageTime'] == null) {
            print('Updating missing lastMessageTime field');
            await firestore.collection('chats').doc(doc.id).update({
              'lastMessageTime': FieldValue.serverTimestamp(),
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
          
          return doc.id;
        }
      }
      
      // Если чат не найден, создаем новый
      final chatId = const Uuid().v4();
      print('No existing chat found. Creating new chat with ID: $chatId');
      
      final timestamp = FieldValue.serverTimestamp();
      await firestore.collection('chats').doc(chatId).set({
        'name': '',
        'type': 'direct',
        'participants': [userId1, userId2],
        'createdAt': timestamp,
        'lastMessageTime': timestamp,
        'updatedAt': timestamp,
        'unreadCount': {},
      });

      print('Chat created successfully');
      return chatId;
    } catch (e) {
      print('Error creating direct chat: $e');
      rethrow;
    }
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
  Future<void> sendMessage(String chatId, String senderId, String text, {
    MessageType type = MessageType.text,
    String? mediaUrl,
    int? duration,
  }) async {
    // Создаем новое сообщение
    final messageRef = firestore.collection('chats').doc(chatId).collection('messages').doc();
    final messageData = {
      'id': messageRef.id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
      'read': false,
      'type': type.toString().split('.').last,
      'mediaUrl': mediaUrl,
      'duration': duration,
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

    // Формируем текст для превью сообщения
    String previewText = text;
    if (type == MessageType.image) {
      previewText = '📷 Image';
    } else if (type == MessageType.voice) {
      previewText = '🎤 Voice message';
    } else if (type == MessageType.video) {
      previewText = '📹 Video';
    }

    // Обновляем информацию о чате
    await firestore.collection('chats').doc(chatId).update({
      'lastMessageText': previewText,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount': unreadCount,
    });

    // Сохраняем сообщение
    await messageRef.set(messageData);
  }

  // Отправка изображения в чат
  Future<void> sendImageMessage(String chatId, String senderId, dynamic imageFile, {String caption = ''}) async {
    try {
      // Загружаем изображение в Firebase Storage
      final imageUrl = await uploadImage(senderId, imageFile);
      
      // Отправляем сообщение с изображением
      await sendMessage(
        chatId,
        senderId,
        caption,
        type: MessageType.image,
        mediaUrl: imageUrl,
      );
    } catch (e) {
      print('Error sending image message: $e');
      rethrow;
    }
  }

  // Отправка голосового сообщения в чат
  Future<void> sendVoiceMessage(String chatId, String senderId, dynamic audioFile, int durationInSeconds) async {
    try {
      // Загружаем аудиофайл в Firebase Storage
      final audioUrl = await uploadVoiceMessage(senderId, audioFile);
      
      // Отправляем голосовое сообщение
      await sendMessage(
        chatId,
        senderId,
        '',
        type: MessageType.voice,
        mediaUrl: audioUrl,
        duration: durationInSeconds,
      );
    } catch (e) {
      print('Error sending voice message: $e');
      rethrow;
    }
  }

  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      print('Marking messages as read for chat $chatId, user $userId');
      
      // Обновляем счетчик непрочитанных сообщений
      await firestore.collection('chats').doc(chatId).update({
        'unreadCount.$userId': 0,
      });
      
      print('Updated unread count for user');

      // Получаем непрочитанные сообщения
      final query = await firestore
          .collection('chats')
          .doc(chatId)
          .collection('messages')
          .where('read', isEqualTo: false)
          .where('senderId', isNotEqualTo: userId)
          .get();
      
      print('Found ${query.docs.length} unread messages to mark as read');

      // Помечаем сообщения как прочитанные
      if (query.docs.isNotEmpty) {
        final batch = firestore.batch();
        for (final doc in query.docs) {
          batch.update(doc.reference, {'read': true});
        }
        await batch.commit();
        print('Marked messages as read');
      }
    } catch (e) {
      print('Error marking messages as read: $e');
      // Не выбрасываем исключение, чтобы не прерывать загрузку сообщений
    }
  }

  // Storage methods for media
  Future<String> uploadFile(String path, dynamic file) async {
    try {
      print('Uploading file to path: $path, file type: ${file.runtimeType}, size: ${file is Uint8List ? "${(file.length / 1024).toStringAsFixed(2)} KB" : "unknown"}');
      final ref = _storage.ref().child(path);
      
      // Для веб-платформы используем упрощенный подход
      if (kIsWeb) {
        print('Running on web platform');
        
        // Для веб-версии
        if (file is XFile) {
          print('File is XFile, reading as bytes');
          try {
            // Читаем файл как массив байтов
            final bytes = await file.readAsBytes();
            print('Successfully read ${bytes.length} bytes from XFile');
            
            // Определяем тип контента
            String contentType = 'image/jpeg';
            if (file.name.toLowerCase().endsWith('.png')) {
              contentType = 'image/png';
            } else if (file.name.toLowerCase().endsWith('.gif')) {
              contentType = 'image/gif';
            }
            
            // Создаем метаданные
            final metadata = SettableMetadata(
              contentType: contentType,
              customMetadata: {'picked-file-path': file.path}
            );
            
            // Эмулируем прогресс загрузки для веб-платформы
            // Запускаем искусственные обновления прогресса
            bool isCompleted = false;
            int progressPercent = 0;
            
            // Запускаем таймер для эмуляции прогресса
            Timer.periodic(const Duration(milliseconds: 500), (timer) {
              if (isCompleted) {
                timer.cancel();
                return;
              }
              
              // Увеличиваем прогресс на случайное значение
              progressPercent += 5 + (DateTime.now().millisecondsSinceEpoch % 5);
              if (progressPercent > 95) progressPercent = 95; // Максимум 95%
              
              print('Simulated upload progress: $progressPercent%');
            });
            
            // Загружаем файл с отслеживанием прогресса
            print('Starting upload...');
            final uploadTask = ref.putData(bytes, metadata);
            
            // Отслеживаем прогресс загрузки
            uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
              final progress = snapshot.bytesTransferred / snapshot.totalBytes;
              print('Real upload progress: ${(progress * 100).toStringAsFixed(2)}%');
            }, onError: (e) {
              print('Error in upload progress stream: $e');
            });
            
            // Ожидаем завершения загрузки
            final snapshot = await uploadTask;
            isCompleted = true;
            print('Upload completed successfully');
            
            // Получаем URL загруженного файла
            final downloadUrl = await snapshot.ref.getDownloadURL();
            print('File uploaded successfully. Download URL: $downloadUrl');
            
            return downloadUrl;
          } catch (e) {
            print('Error uploading XFile: $e');
            rethrow;
          }
        } else if (file is Uint8List) {
          print('File is Uint8List with ${file.length} bytes');
          
          try {
            // Эмулируем прогресс загрузки для веб-платформы
            bool isCompleted = false;
            int progressPercent = 0;
            
            // Запускаем таймер для эмуляции прогресса
            Timer.periodic(const Duration(milliseconds: 500), (timer) {
              if (isCompleted) {
                timer.cancel();
                return;
              }
              
              // Увеличиваем прогресс на случайное значение
              progressPercent += 5 + (DateTime.now().millisecondsSinceEpoch % 5);
              if (progressPercent > 95) progressPercent = 95; // Максимум 95%
              
              print('Simulated upload progress: $progressPercent%');
            });
            
            // Разбиваем большие файлы на части для более надежной загрузки
            final int chunkSize = 1024 * 1024; // 1MB
            
            if (file.length > 5 * 1024 * 1024) {
              print('Large file detected (${(file.length / (1024 * 1024)).toStringAsFixed(2)} MB), using chunked upload approach');
              
              // Для очень больших файлов используем метаданные с пониженным качеством
              final metadata = SettableMetadata(
                contentType: 'image/jpeg',
                customMetadata: {'large-file': 'true'}
              );
              
              // Загружаем файл с отслеживанием прогресса
              final uploadTask = ref.putData(file, metadata);
              
              // Отслеживаем прогресс загрузки
              uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
                final progress = snapshot.bytesTransferred / snapshot.totalBytes;
                print('Real upload progress: ${(progress * 100).toStringAsFixed(2)}%');
              }, onError: (e) {
                print('Error in upload progress stream: $e');
              });
              
              // Ожидаем завершения загрузки с увеличенным таймаутом
              print('Starting large file upload, this may take several minutes...');
              final snapshot = await uploadTask.timeout(
                const Duration(minutes: 10), // Увеличиваем таймаут до 10 минут для очень больших файлов
                onTimeout: () {
                  print('Upload timed out after 10 minutes');
                  throw TimeoutException('Upload timed out after 10 minutes');
                }
              );
              
              isCompleted = true;
              print('Large file upload completed');
              
              // Получаем URL загруженного файла
              final downloadUrl = await snapshot.ref.getDownloadURL();
              print('Large file uploaded successfully. Download URL: $downloadUrl');
              
              return downloadUrl;
            } else {
              // Для файлов обычного размера используем стандартный подход
              final metadata = SettableMetadata(contentType: 'image/jpeg');
              
              // Загружаем файл
              print('Starting upload...');
              final uploadTask = ref.putData(file, metadata);
              
              // Отслеживаем прогресс загрузки
              uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
                final progress = snapshot.bytesTransferred / snapshot.totalBytes;
                print('Real upload progress: ${(progress * 100).toStringAsFixed(2)}%');
              }, onError: (e) {
                print('Error in upload progress stream: $e');
              });
              
              // Ожидаем завершения загрузки
              print('Waiting for upload to complete...');
              final snapshot = await uploadTask.timeout(
                const Duration(minutes: 5), // Увеличиваем таймаут до 5 минут
                onTimeout: () {
                  print('Upload timed out after 5 minutes');
                  throw TimeoutException('Upload timed out after 5 minutes');
                }
              );
              
              isCompleted = true;
              print('Upload completed');
              
              // Получаем URL загруженного файла
              final downloadUrl = await snapshot.ref.getDownloadURL();
              print('File uploaded successfully. Download URL: $downloadUrl');
              
              return downloadUrl;
            }
          } catch (e) {
            print('Error uploading Uint8List: $e');
            if (e is FirebaseException) {
              print('Firebase error code: ${e.code}, message: ${e.message}');
            }
            rethrow;
          }
        } else {
          final error = 'Unsupported file type for web upload: ${file.runtimeType}';
          print(error);
          throw Exception(error);
        }
      } else {
        // Для мобильной версии
        print('Running on mobile platform');
        
        UploadTask? uploadTask;
        
        if (file is File) {
          print('File is File: ${file.path}');
          uploadTask = ref.putFile(file);
        } else if (file is XFile) {
          print('File is XFile: ${file.path}');
          uploadTask = ref.putFile(File(file.path));
        } else if (file is Uint8List) {
          print('File is Uint8List with ${file.length} bytes');
          uploadTask = ref.putData(file);
        } else {
          final error = 'Unsupported file type for mobile upload: ${file.runtimeType}';
          print(error);
          throw Exception(error);
        }
        
        if (uploadTask == null) {
          throw Exception('Failed to create upload task');
        }
        
        print('Starting upload task');
        
        // Отслеживаем прогресс загрузки
        uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
          final progress = snapshot.bytesTransferred / snapshot.totalBytes;
          print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        }, onError: (e) {
          print('Error in upload progress stream: $e');
        });
        
        // Ожидаем завершения загрузки с увеличенным таймаутом
        print('Waiting for upload to complete...');
        final snapshot = await uploadTask.timeout(
          const Duration(minutes: 5), // Увеличиваем таймаут до 5 минут
          onTimeout: () {
            print('Upload timed out after 5 minutes');
            throw TimeoutException('Upload timed out after 5 minutes');
          }
        );
        
        // Получаем URL загруженного файла
        print('Getting download URL...');
        final downloadUrl = await snapshot.ref.getDownloadURL();
        print('File uploaded successfully. Download URL: $downloadUrl');
        
        return downloadUrl;
      }
    } catch (e) {
      print('Error uploading file: $e');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}, message: ${e.message}');
        
        // Обработка специфических ошибок Firebase
        if (e.code == 'unauthorized') {
          throw Exception('Unauthorized access to Firebase Storage');
        } else if (e.code == 'canceled') {
          throw Exception('Upload was canceled');
        } else if (e.code == 'unknown') {
          throw Exception('Unknown error during upload. Check your network connection');
        }
      } else if (e is TimeoutException) {
        throw Exception('Upload timed out. The file may be too large or your connection is slow');
      }
      rethrow;
    }
  }

  Future<String> uploadVoiceMessage(String userId, dynamic audioFile) async {
    try {
      final path = 'voice_messages/$userId/${DateTime.now().millisecondsSinceEpoch}';
      return await uploadFile(path, audioFile);
    } catch (e) {
      print('Error uploading voice message: $e');
      rethrow;
    }
  }

  Future<String> uploadImage(String userId, dynamic imageFile) async {
    try {
      final path = 'images/$userId/${DateTime.now().millisecondsSinceEpoch}';
      return await uploadFile(path, imageFile);
    } catch (e) {
      print('Error uploading image: $e');
      rethrow;
    }
  }
} 