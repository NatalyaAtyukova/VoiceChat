import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';
import '../../models/chat.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final _searchController = TextEditingController();
  List<User> _friends = [];
  List<User> _filteredFriends = [];
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
      final apiService = Provider.of<ApiService>(context, listen: false);
      final currentUser = apiService.currentUser;
      
      if (currentUser == null) {
        return;
      }
      
      _currentUserId = currentUser.id;
      
      // Получаем данные текущего пользователя
      final userData = await apiService.getUserById(_currentUserId);
      
      if (userData == null) {
        return;
      }
      
      final user = User.fromJson(userData);
      
      // Загружаем информацию о друзьях
      final friendsList = <User>[];
      for (final friendId in user.friends) {
        final friendData = await apiService.getUserById(friendId);
        if (friendData != null) {
          friendsList.add(User.fromJson(friendData));
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
  
  Future<void> _startChat(User friend) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final chat = await apiService.createChat(friend.id);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chat.id,
              chatName: friend.displayName ?? friend.username,
              chatType: ChatType.direct,
              otherUser: friend,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating chat: $e')),
        );
      }
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