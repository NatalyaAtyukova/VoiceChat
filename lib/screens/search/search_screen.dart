import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../chat/chat_screen.dart';
import '../../models/chat_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _searchResults = [];
  bool _isLoading = false;
  String _currentUserId = '';
  UserModel? _currentUser;
  Set<String> _sentFriendRequests = {};

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  Future<void> _getCurrentUserId() async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final user = firebaseService.auth.currentUser;
    if (user != null) {
      setState(() {
        _currentUserId = user.uid;
      });
      
      // Загружаем данные текущего пользователя
      _loadCurrentUserData();
    }
  }
  
  Future<void> _loadCurrentUserData() async {
    if (_currentUserId.isEmpty) return;
    
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final user = await firebaseService.getUserById(_currentUserId);
      
      if (user != null) {
        setState(() {
          _currentUser = user;
          // Инициализируем список отправленных запросов
          _updateSentFriendRequests();
        });
      }
    } catch (e) {
      print('Error loading current user data: $e');
    }
  }
  
  void _updateSentFriendRequests() {
    // Получаем список пользователей, которым текущий пользователь отправил запросы
    _sentFriendRequests = {};
    
    for (final user in _searchResults) {
      if (user.friendRequests.contains(_currentUserId)) {
        _sentFriendRequests.add(user.id);
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final results = await firebaseService.searchUsers(query);
      
      // Фильтруем текущего пользователя из результатов
      results.removeWhere((user) => user.id == _currentUserId);
      
      setState(() {
        _searchResults = results;
        _updateSentFriendRequests();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching users: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sendFriendRequest(String userId) async {
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.sendFriendRequest(_currentUserId, userId);
      
      // Обновляем UI, добавляя пользователя в список отправленных запросов
      setState(() {
        _sentFriendRequests.add(userId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sending friend request: ${e.toString()}')),
      );
    }
  }

  Future<void> _startChat(UserModel user) async {
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      
      // Создаем или получаем существующий чат между пользователями
      final chatId = await firebaseService.createDirectChat(_currentUserId, user.id);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              chatName: user.displayName ?? user.username,
              chatType: ChatType.direct,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Friends'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username or name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _searchUsers('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (value) {
                if (value.length >= 3) {
                  _searchUsers(value);
                } else if (value.isEmpty) {
                  _searchUsers('');
                }
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Text(
                          _searchController.text.isEmpty
                              ? 'Search for users by username or name'
                              : 'No users found',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.photoUrl != null
                                  ? NetworkImage(user.photoUrl!)
                                  : null,
                              child: user.photoUrl == null
                                  ? Text(user.displayName?[0] ?? user.username[0])
                                  : null,
                            ),
                            title: Text(user.displayName ?? user.username),
                            subtitle: Text('@${user.username}'),
                            trailing: _buildActionButton(user),
                            onTap: () {
                              // Если пользователь уже в друзьях, открываем чат
                              if (_currentUser != null && _currentUser!.friends.contains(user.id)) {
                                _startChat(user);
                              }
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(UserModel user) {
    // Если пользователь уже в друзьях
    if (_currentUser != null && _currentUser!.friends.contains(user.id)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Chip(
            label: Text('Friend'),
            backgroundColor: Colors.green,
            labelStyle: TextStyle(color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.chat, color: Colors.blue),
            onPressed: () => _startChat(user),
          ),
        ],
      );
    }
    
    // Если запрос уже отправлен
    if (_sentFriendRequests.contains(user.id)) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Chip(
            label: Text('Request Sent'),
            backgroundColor: Colors.orange,
            labelStyle: TextStyle(color: Colors.white),
          ),
          IconButton(
            icon: const Icon(Icons.cancel, color: Colors.red),
            onPressed: () => _cancelFriendRequest(user.id),
          ),
        ],
      );
    }
    
    // Если пользователь отправил нам запрос
    if (_currentUser != null && _currentUser!.friendRequests.contains(user.id)) {
      return ElevatedButton(
        onPressed: () {
          // TODO: Implement accept friend request
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Go to Friend Requests to accept')),
          );
        },
        child: const Text('Accept'),
      );
    }
    
    // По умолчанию - кнопка добавления в друзья
    return IconButton(
      icon: const Icon(Icons.person_add),
      onPressed: () => _sendFriendRequest(user.id),
    );
  }

  Future<void> _cancelFriendRequest(String userId) async {
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.cancelFriendRequest(_currentUserId, userId);
      
      // Обновляем UI
      setState(() {
        _sentFriendRequests.remove(userId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request canceled')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error canceling friend request: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
} 