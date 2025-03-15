import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/api_service.dart';
import '../../models/user.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  bool _isLoading = true;
  List<User> _friendRequests = [];
  String _currentUserId = '';

  @override
  void initState() {
    super.initState();
    _loadFriendRequests();
  }

  Future<void> _loadFriendRequests() async {
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
      
      // Получаем текущего пользователя с запросами в друзья
      final userData = await apiService.getUserById(_currentUserId);
      
      if (userData == null) {
        return;
      }
      
      // Загружаем данные пользователей, отправивших запросы
      final requests = <User>[];
      final user = User.fromJson(userData);
      for (final userId in user.friendRequests) {
        final friendData = await apiService.getUserById(userId);
        if (friendData != null) {
          requests.add(User.fromJson(friendData));
        }
      }
      
      setState(() {
        _friendRequests = requests;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading friend requests: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _acceptFriendRequest(String userId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.acceptFriendRequest(userId);
      
      setState(() {
        _friendRequests.removeWhere((user) => user.id == userId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request accepted!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accepting friend request: ${e.toString()}')),
      );
    }
  }

  Future<void> _rejectFriendRequest(String userId) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.rejectFriendRequest(userId);
      
      setState(() {
        _friendRequests.removeWhere((user) => user.id == userId);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Friend request rejected')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error rejecting friend request: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friend Requests'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _friendRequests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.person_add_disabled,
                        size: 80,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No friend requests',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'When someone sends you a friend request, it will appear here',
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
                  itemCount: _friendRequests.length,
                  itemBuilder: (context, index) {
                    final user = _friendRequests[index];
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
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.check, color: Colors.green),
                            onPressed: () => _acceptFriendRequest(user.id),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: () => _rejectFriendRequest(user.id),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
} 