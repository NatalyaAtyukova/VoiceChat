import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/firebase_service.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import '../search/search_screen.dart';
import '../friends/friend_requests_screen.dart';
import '../chat/chat_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentUserId = '';
  UserModel? _currentUser;
  List<ChatModel> _chats = [];
  bool _isLoading = true;
  Map<String, UserModel> _usersCache = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      final user = firebaseService.auth.currentUser;
      
      if (user == null) {
        return;
      }
      
      _currentUserId = user.uid;
      
      // Загружаем данные пользователя
      _currentUser = await firebaseService.getUserById(_currentUserId);
      
      // Загружаем чаты пользователя
      _chats = await firebaseService.getUserChats(_currentUserId);
      
      // Загружаем информацию о пользователях в чатах
      for (final chat in _chats) {
        if (chat.type == ChatType.direct) {
          // Для личных чатов загружаем данные собеседника
          final otherUserId = chat.participants.firstWhere(
            (id) => id != _currentUserId,
            orElse: () => '',
          );
          
          if (otherUserId.isNotEmpty && !_usersCache.containsKey(otherUserId)) {
            final otherUser = await firebaseService.getUserById(otherUserId);
            if (otherUser != null) {
              setState(() {
                _usersCache[otherUserId] = otherUser;
              });
            }
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: ${e.toString()}')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  String _getChatName(ChatModel chat) {
    if (chat.type == ChatType.group) {
      return chat.name;
    } else {
      // Для личных чатов используем имя собеседника
      final otherUserId = chat.participants.firstWhere(
        (id) => id != _currentUserId,
        orElse: () => '',
      );
      
      if (otherUserId.isNotEmpty && _usersCache.containsKey(otherUserId)) {
        final otherUser = _usersCache[otherUserId]!;
        return otherUser.displayName ?? otherUser.username;
      }
      
      return 'Chat';
    }
  }

  void _navigateToChat(ChatModel chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          chatId: chat.id,
          chatName: _getChatName(chat),
          chatType: chat.type,
        ),
      ),
    ).then((_) => _loadUserData());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Voice Chat'),
        actions: [
          if (_currentUser != null && _currentUser!.friendRequests.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FriendRequestsScreen(),
                      ),
                    ).then((_) => _loadUserData());
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
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
                      _currentUser!.friendRequests.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            )
          else
            IconButton(
              icon: const Icon(Icons.notifications),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const FriendRequestsScreen(),
                  ),
                ).then((_) => _loadUserData());
              },
            ),
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              Navigator.pushNamed(context, '/friends').then((_) => _loadUserData());
            },
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const SearchScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<FirebaseService>(context, listen: false).signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth >= 600) {
                  return _buildDesktopLayout(context);
                } else {
                  return _buildMobileLayout(context);
                }
              },
            ),
      floatingActionButton: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const SearchScreen(),
                  ),
                );
              },
              child: const Icon(Icons.add),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildDesktopLayout(BuildContext context) {
    return Row(
      children: [
        // Левая панель с списком чатов
        Container(
          width: 300,
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: Theme.of(context).dividerColor,
              ),
            ),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search chats...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: _chats.isEmpty
                    ? const Center(
                        child: Text('No chats yet'),
                      )
                    : ListView.builder(
                        itemCount: _chats.length,
                        itemBuilder: (context, index) {
                          final chat = _chats[index];
                          return ListTile(
                            leading: CircleAvatar(
                              child: Icon(
                                chat.type == ChatType.direct
                                    ? Icons.person
                                    : Icons.group,
                              ),
                            ),
                            title: Text(_getChatName(chat)),
                            subtitle: Text(
                              chat.lastMessageText ?? 'No messages yet',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: chat.unreadCount[_currentUserId] != null &&
                                    chat.unreadCount[_currentUserId]! > 0
                                ? Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      chat.unreadCount[_currentUserId].toString(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : null,
                            onTap: () => _navigateToChat(chat),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        // Правая панель с основным контентом
        Expanded(
          child: Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 100,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome to Voice Chat!',
                    style: TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SearchScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Start New Chat'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            decoration: InputDecoration(
              hintText: 'Search chats...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        Expanded(
          child: _chats.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline,
                        size: 80,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No chats yet',
                        style: TextStyle(fontSize: 18),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SearchScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Find Friends'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _chats.length,
                  itemBuilder: (context, index) {
                    final chat = _chats[index];
                    return ListTile(
                      leading: CircleAvatar(
                        child: Icon(
                          chat.type == ChatType.direct
                              ? Icons.person
                              : Icons.group,
                        ),
                      ),
                      title: Text(_getChatName(chat)),
                      subtitle: Text(
                        chat.lastMessageText ?? 'No messages yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: chat.unreadCount[_currentUserId] != null &&
                              chat.unreadCount[_currentUserId]! > 0
                          ? Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Theme.of(context).primaryColor,
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                chat.unreadCount[_currentUserId].toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                ),
                              ),
                            )
                          : null,
                      onTap: () => _navigateToChat(chat),
                    );
                  },
                ),
        ),
      ],
    );
  }
} 