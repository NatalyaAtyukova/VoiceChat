import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../chat/chat_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _searchController = TextEditingController();
  List<User> _searchResults = [];
  bool _isLoading = false;
  String _currentUserId = '';
  List<String> _sentRequests = [];
  List<String> _friends = [];

  @override
  void initState() {
    super.initState();
    _getCurrentUserData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentUserData() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final currentUser = apiService.currentUser;
    if (currentUser != null) {
      try {
        final userData = await apiService.getUserById(currentUser.id);
        final user = User.fromJson(userData);
        
        setState(() {
          _currentUserId = currentUser.id;
          _friends = user.friends;
          // Здесь нужно получить список отправленных запросов
          // Это может потребовать дополнительного API-метода
        });
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading user data: ${e.toString()}')),
        );
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
      final apiService = Provider.of<ApiService>(context, listen: false);
      final results = await apiService.searchUsers(query);
      setState(() {
        _searchResults = results.map((data) => User.fromJson(data)).toList();
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

  Future<void> _startChat(User user) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final chat = await apiService.createChat(user.id);
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              chatId: chat.id,
              chatName: user.displayName ?? user.username,
              chatType: ChatType.direct,
              otherUser: user,
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

  Future<void> _sendFriendRequest(User user) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.sendFriendRequest(user.id);
      
      setState(() {
        _sentRequests.add(user.id);
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

  Future<void> _cancelFriendRequest(User user) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.cancelFriendRequest(user.id);
      
      setState(() {
        _sentRequests.remove(user.id);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request cancelled')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cancelling friend request: ${e.toString()}')),
      );
    }
  }

  bool _isFriend(String userId) {
    return _friends.contains(userId);
  }

  bool _hasSentRequest(String userId) {
    return _sentRequests.contains(userId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Search Users'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by username or display name',
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
              onChanged: _searchUsers,
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _searchResults.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.search,
                              size: 80,
                              color: Colors.grey,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchController.text.isEmpty
                                  ? 'Start typing to search users'
                                  : 'No users found',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _searchResults.length,
                        itemBuilder: (context, index) {
                          final user = _searchResults[index];
                          final isFriend = _isFriend(user.id);
                          final hasSentRequest = _hasSentRequest(user.id);
                          
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: user.photoUrl?.isNotEmpty == true
                                  ? NetworkImage(user.photoUrl!)
                                  : null,
                              child: user.photoUrl?.isEmpty != false
                                  ? Text(user.displayName?[0] ?? user.username[0])
                                  : null,
                            ),
                            title: Text(user.displayName ?? user.username),
                            subtitle: Text('@${user.username}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.chat),
                                  onPressed: () => _startChat(user),
                                ),
                                if (isFriend)
                                  const Chip(
                                    label: Text('Friend'),
                                    backgroundColor: Colors.green,
                                    labelStyle: TextStyle(color: Colors.white),
                                  )
                                else if (hasSentRequest)
                                  IconButton(
                                    icon: const Icon(Icons.person_remove, color: Colors.orange),
                                    onPressed: () => _cancelFriendRequest(user),
                                    tooltip: 'Cancel request',
                                  )
                                else
                                  IconButton(
                                    icon: const Icon(Icons.person_add),
                                    onPressed: () => _sendFriendRequest(user),
                                    tooltip: 'Send friend request',
                                  ),
                              ],
                            ),
                            onTap: () => _startChat(user),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
} 