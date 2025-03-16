import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/chat.dart';
import '../models/message.dart';
import 'package:http_parser/http_parser.dart';

class ApiService extends ChangeNotifier {
  static const String baseUrl = 'http://localhost:3001/api';
  String? _token;
  User? _currentUser;

  User? get currentUser => _currentUser;

  // Auth methods
  Future<Map<String, dynamic>> register(String email, String password, String displayName) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'displayName': displayName,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      _currentUser = User.fromJson(data['user']);
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Registration failed');
    }
  }

  Future<Map<String, dynamic>> login(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _token = data['token'];
      _currentUser = User.fromJson(data['user']);
      return data;
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Login failed');
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
  }

  // Check token and load user data
  Future<bool> checkAuth() async {
    if (_token == null) return false;
    
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/auth/me'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _currentUser = User.fromJson(data['user']);
        notifyListeners();
        return true;
      } else {
        _token = null;
        _currentUser = null;
        return false;
      }
    } catch (e) {
      _token = null;
      _currentUser = null;
      return false;
    }
  }

  // User methods
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/search?q=$query'),
      headers: _getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Search failed');
    }
  }

  Future<Map<String, dynamic>> getUserById(String userId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/users/$userId'),
      headers: _getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to get user');
    }
  }

  Future<void> sendFriendRequest(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/friends/requests/$userId'),
      headers: _getAuthHeaders(),
    );

    if (response.statusCode != 201) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to send friend request');
    }
  }

  Future<void> cancelFriendRequest(String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/friends/requests/$userId'),
      headers: _getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to cancel friend request');
    }
  }

  Future<void> acceptFriendRequest(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/friends/accept/$userId'),
      headers: _getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to accept friend request');
    }
  }

  Future<void> rejectFriendRequest(String userId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/friends/reject/$userId'),
      headers: _getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to reject friend request');
    }
  }

  Future<void> removeFriend(String userId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/users/friends/$userId'),
      headers: _getAuthHeaders(),
    );

    if (response.statusCode != 200) {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to remove friend');
    }
  }

  Future<String> uploadProfilePhoto(File photo) async {
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('$baseUrl/users/profile/photo'),
    );

    request.headers.addAll(_getAuthHeaders());
    request.files.add(await http.MultipartFile.fromPath(
      'photo',
      photo.path,
      contentType: MediaType('image', 'jpeg'),
    ));

    final response = await request.send();
    final responseData = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final data = jsonDecode(responseData);
      return data['photoURL'];
    } else {
      throw Exception(jsonDecode(responseData)['message'] ?? 'Upload failed');
    }
  }

  // Chat methods
  Future<List<Chat>> getChats() async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat'),
      headers: _getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Chat.fromJson(json)).toList();
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to get chats');
    }
  }

  Future<Chat> createChat(String participantId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/chat'),
      headers: _getAuthHeaders(),
      body: jsonEncode({
        'participantId': participantId,
      }),
    );

    if (response.statusCode == 201) {
      return Chat.fromJson(jsonDecode(response.body));
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to create chat');
    }
  }

  Future<List<Message>> getChatMessages(String chatId) async {
    final response = await http.get(
      Uri.parse('$baseUrl/chat/$chatId/messages'),
      headers: _getAuthHeaders(),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => Message.fromJson(json)).toList();
    } else {
      throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to get messages');
    }
  }

  Future<Message> sendTextMessage(String chatId, String content) async {
    // Создаем временное сообщение со статусом "отправляется"
    final tempMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: chatId,
      senderId: _currentUser!.id,
      type: MessageType.text,
      content: content,
      timestamp: DateTime.now(),
      status: MessageStatus.sending,
    );
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/$chatId/messages'),
        headers: _getAuthHeaders(),
        body: jsonEncode({
          'content': content,
          'type': 'text',
        }),
      );

      if (response.statusCode == 201) {
        return Message.fromJson(jsonDecode(response.body));
      } else {
        // Возвращаем сообщение с ошибкой
        return tempMessage.copyWith(status: MessageStatus.error);
      }
    } catch (e) {
      // Возвращаем сообщение с ошибкой
      return tempMessage.copyWith(status: MessageStatus.error);
    }
  }

  Future<Message> sendFileMessage(String chatId, File file, String type, {int? duration}) async {
    // Создаем временное сообщение со статусом "отправляется"
    final tempMessage = Message(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      chatId: chatId,
      senderId: _currentUser!.id,
      type: type == 'image' ? MessageType.image : MessageType.voice,
      content: '',
      timestamp: DateTime.now(),
      duration: duration,
      status: MessageStatus.sending,
    );
    
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/chat/$chatId/messages/file'),
      );

      request.headers.addAll(_getAuthHeaders());
      request.fields['type'] = type;
      if (duration != null) {
        request.fields['duration'] = duration.toString();
      }

      request.files.add(await http.MultipartFile.fromPath(
        'file',
        file.path,
        contentType: type == 'image' 
            ? MediaType('image', 'jpeg')
            : MediaType('audio', 'wav'),
      ));

      final response = await request.send();
      final responseData = await response.stream.bytesToString();

      if (response.statusCode == 201) {
        return Message.fromJson(jsonDecode(responseData));
      } else {
        // Возвращаем сообщение с ошибкой
        return tempMessage.copyWith(status: MessageStatus.error);
      }
    } catch (e) {
      // Возвращаем сообщение с ошибкой
      return tempMessage.copyWith(status: MessageStatus.error);
    }
  }

  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/$chatId/messages/read'),
        headers: _getAuthHeaders(),
      );

      if (response.statusCode != 200) {
        throw Exception(jsonDecode(response.body)['message'] ?? 'Failed to mark messages as read');
      }
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }

  // Helper methods
  Map<String, String> _getAuthHeaders() {
    if (_token == null) {
      throw Exception('Not authenticated');
    }
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_token',
    };
  }

  void setToken(String token) {
    _token = token;
  }

  String? getToken() {
    return _token;
  }
} 