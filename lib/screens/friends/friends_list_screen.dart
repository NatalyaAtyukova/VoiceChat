import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/user_model.dart';
import '../chat/chat_screen.dart';
import '../../models/chat_model.dart';
import '../../models/user.dart';
import '../../models/chat.dart';

class FriendsListScreen extends StatefulWidget {
  const FriendsListScreen({super.key});

  @override
  State<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends State<FriendsListScreen> {
  bool _isLoading = true;
  List<User> _friends = [];
  String _currentUserId = '';
  
  @override
  void initState() {
    super.initState();
    _loadFriends();
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
  
  Future<void> _removeFriend(String friendId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.removeFriend(friendId);
      
      // Обновляем список друзей
      await _loadFriends();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend removed successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error removing friend: ${e.toString()}')),
      );
    }
  }
  
  Future<void> _startChat(User friend) async {
    try {
      print('Starting chat with friend: ${friend.id} (${friend.username})');
      final apiService = Provider.of<ApiService>(context, listen: false);
      
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
      final chatData = await apiService.createChat(friend.id);
      final chat = Chat.fromJson(chatData);
      print('Chat ID received: ${chat.id}');
      
      // Закрываем диалог загрузки
      if (mounted) {
        Navigator.pop(context);
      }
      
      if (chat.id.isEmpty) {
        print('Error: Received empty chat ID');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Failed to create or find chat')),
        );
        return;
      }
      
      if (mounted) {
        print('Navigating to chat screen with ID: ${chat.id}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadFriends,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friends.isEmpty
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
                      const Text(
                        'No friends yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Search for users to add them as friends',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/search');
                        },
                        icon: const Icon(Icons.search),
                        label: const Text('Find Friends'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _friends.length,
                  itemBuilder: (context, index) {
                    final friend = _friends[index];
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chat),
                            onPressed: () => _startChat(friend),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _showRemoveConfirmation(friend),
                          ),
                        ],
                      ),
                      onTap: () => _startChat(friend),
                    );
                  },
                ),
    );
  }
  
  void _showRemoveConfirmation(User friend) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Friend'),
        content: Text('Are you sure you want to remove ${friend.displayName ?? friend.username} from your friends?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _removeFriend(friend.id);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
} 