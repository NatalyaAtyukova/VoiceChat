import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  List<UserModel> _friends = [];
  List<UserModel> _filteredFriends = [];
  bool _isLoading = true;
  String _currentUserId = '';
  
  @override
  void initState() {
    super.initState();
    _loadFriends();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadFriends() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final currentUser = firebaseService.auth.currentUser;
      
      if (currentUser == null) {
        return;
      }
      
      _currentUserId = currentUser.uid;
      
      // Получаем данные текущего пользователя
      final user = await firebaseService.getUserById(_currentUserId);
      
      if (user == null) {
        return;
      }
      
      // Загружаем информацию о друзьях
      final friendsList = <UserModel>[];
      for (final friendId in user.friends) {
        final friend = await firebaseService.getUserById(friendId);
        if (friend != null) {
          friendsList.add(friend);
        }
      }
      
      setState(() {
        _friends = friendsList;
        _filteredFriends = friendsList;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading friends: ${e.toString()}')),
      );
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  void _filterFriends(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredFriends = _friends;
      } else {
        _filteredFriends = _friends.where((friend) {
          final username = friend.username.toLowerCase();
          final displayName = (friend.displayName ?? '').toLowerCase();
          final searchQuery = query.toLowerCase();
          
          return username.contains(searchQuery) || displayName.contains(searchQuery);
        }).toList();
      }
    });
  }
  
  Future<void> _startChat(UserModel friend) async {
    try {
      print('Starting chat with friend: ${friend.id} (${friend.username})');
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      
      if (_currentUserId.isEmpty) {
        print('Error: Current user ID is empty');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Unable to identify current user')),
        );
        return;
      }
      
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Создаем или получаем существующий чат между пользователями
      final chatId = await firebaseService.createDirectChat(_currentUserId, friend.id);
      print('Chat ID received: $chatId');
      
      // Закрываем диалог загрузки
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (chatId.isEmpty) {
        print('Error: Received empty chat ID');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Failed to create or find chat')),
        );
        return;
      }
      
      if (mounted) {
        // Закрываем экран выбора друга
        Navigator.pop(context);
        
        // Открываем экран чата
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chatId,
              chatName: friend.displayName ?? friend.username,
              chatType: ChatType.direct,
            ),
          ),
        );
      }
    } catch (e) {
      // Закрываем диалог загрузки, если он открыт
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context);
      }
      
      print('Error in _startChat: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting chat: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _createGroupChat() async {
    // Здесь можно добавить функциональность создания группового чата
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Group chat creation will be available soon')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _createGroupChat,
            tooltip: 'Create Group Chat',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _filterFriends('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: _filterFriends,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredFriends.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.people_outline,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _friends.isEmpty
                                  ? 'No friends yet'
                                  : 'No friends match your search',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_friends.isEmpty)
                              const Text(
                                'Add friends to start chatting',
                                textAlign: TextAlign.center,
                              ),
                            if (_friends.isEmpty)
                              const SizedBox(height: 24),
                            if (_friends.isEmpty)
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushReplacementNamed(context, '/search');
                                },
                                icon: const Icon(Icons.search),
                                label: const Text('Find Friends'),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredFriends.length,
                        itemBuilder: (context, index) {
                          final friend = _filteredFriends[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: friend.photoUrl != null
                                  ? NetworkImage(friend.photoUrl!)
                                  : null,
                              child: friend.photoUrl == null
                                  ? Text(friend.displayName?[0] ?? friend.username[0])
                                  : null,
                            ),
                            title: Text(friend.displayName ?? friend.username),
                            subtitle: Text('@${friend.username}'),
                            onTap: () => _startChat(friend),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 