import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/chat.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import '../chat/chat_screen.dart';
import '../chat/new_chat_screen.dart';
import '../friends/friend_requests_screen.dart';
import '../search/search_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  User? _currentUser;
  List<Chat> _chats = [];
  bool _isLoading = true;
  int _friendRequestsCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _loadChats();
    _checkFriendRequests();
  }

  Future<void> _loadCurrentUser() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    setState(() {
      _currentUser = apiService.currentUser;
    });
  }

  Future<void> _loadChats() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final chatsData = await apiService.getChats();
      if (mounted) {
        setState(() {
          _chats = chatsData;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading chats: $e')),
        );
      }
    }
  }

  Future<void> _checkFriendRequests() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      if (apiService.currentUser != null) {
        final userData = await apiService.getUserById(apiService.currentUser!.id);
        final user = User.fromJson(userData);
        
        setState(() {
          _friendRequestsCount = user.friendRequests.length;
        });
      }
    } catch (e) {
      print('Error checking friend requests: $e');
    }
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    
    final apiService = Provider.of<ApiService>(context, listen: false);
    await apiService.logout();
    
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    _currentUser = apiService.currentUser;

    if (_currentUser == null) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.pushNamed(context, '/search');
            },
          ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.pushNamed(context, '/friends');
            },
            tooltip: 'Friends',
          ),
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.person_add),
                onPressed: () {
                  Navigator.pushNamed(context, '/friend_requests').then((_) {
                    _checkFriendRequests();
                  });
                },
              ),
              if (_friendRequestsCount > 0)
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _friendRequestsCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/new_chat');
        },
        child: const Icon(Icons.chat),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chats.isEmpty
              ? const Center(child: Text('No chats yet'))
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    final otherUser = chat.getOtherParticipant(_currentUser!.id);

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: otherUser.photoUrl != null
                            ? NetworkImage(otherUser.photoUrl!)
                            : null,
                        child: otherUser.photoUrl == null
                            ? Text(otherUser.displayName?[0] ?? otherUser.username[0])
                            : null,
                      ),
                      title: Text(otherUser.displayName ?? otherUser.username),
                      subtitle: chat.lastMessage != null
                          ? Text(
                              chat.lastMessage!.type == MessageType.text
                                  ? chat.lastMessage!.content
                                  : chat.lastMessage!.type == MessageType.image
                                      ? '📷 Image'
                                      : '🎤 Voice message',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          : null,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              chatId: chat.id,
                              chatName: otherUser.displayName ?? otherUser.username,
                              chatType: ChatType.direct,
                              otherUser: otherUser,
                            ),
                          ),
                        ).then((_) => _loadChats());
                      },
                    );
                  },
                ),
    );
  }
} 