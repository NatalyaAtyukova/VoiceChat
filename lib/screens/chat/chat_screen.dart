import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../services/firebase_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final ChatType chatType;

  const ChatScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    required this.chatType,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  String _currentUserId = '';
  Map<String, UserModel> _usersCache = {};
  bool _isSending = false;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _loadMessages();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _mounted = false;
    super.dispose();
  }

  Future<void> _getCurrentUserId() async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final user = firebaseService.auth.currentUser;
    if (user != null && _mounted) {
      setState(() {
        _currentUserId = user.uid;
      });
    }
  }

  Future<void> _loadMessages() async {
    if (!_mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      
      // Отмечаем сообщения как прочитанные
      await firebaseService.markMessagesAsRead(widget.chatId, _currentUserId);
      
      // Загружаем сообщения
      final messages = await firebaseService.getChatMessagesOnce(widget.chatId);
      if (_mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        
        // Загружаем информацию о пользователях
        _loadUserInfo();
      }
    } catch (e) {
      if (_mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading messages: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _loadUserInfo() async {
    if (!_mounted) return;
    
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    
    // Собираем уникальные ID пользователей из сообщений
    final userIds = _messages.map((message) => message.senderId).toSet();
    
    // Загружаем информацию о пользователях, которых еще нет в кэше
    for (final userId in userIds) {
      if (!_usersCache.containsKey(userId)) {
        final user = await firebaseService.getUserById(userId);
        if (user != null && _mounted) {
          setState(() {
            _usersCache[userId] = user;
          });
        }
      }
    }
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) {
      return;
    }

    final text = _messageController.text.trim();
    _messageController.clear();

    if (!_mounted) return;
    
    setState(() {
      _isSending = true;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.sendMessage(widget.chatId, _currentUserId, text);
      
      // Обновляем список сообщений
      await _loadMessages();
    } catch (e) {
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: ${e.toString()}')),
        );
      }
    } finally {
      if (_mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(time.year, time.month, time.day);

    if (messageDate == today) {
      return DateFormat.Hm().format(time); // Только время для сегодняшних сообщений
    } else if (messageDate == yesterday) {
      return 'Yesterday, ${DateFormat.Hm().format(time)}';
    } else {
      return DateFormat('dd.MM.yy, HH:mm').format(time);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.chatName),
        actions: [
          if (widget.chatType == ChatType.group)
            IconButton(
              icon: const Icon(Icons.group),
              onPressed: () {
                // TODO: Показать информацию о группе
              },
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('No messages yet'))
                    : ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isCurrentUser = message.senderId == _currentUserId;
                          
                          return _buildMessageBubble(message, isCurrentUser);
                        },
                      ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.attach_file),
                  onPressed: () {
                    // TODO: Реализовать отправку файлов
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Coming soon!')),
                    );
                  },
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message',
                      border: InputBorder.none,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: _isSending
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(MessageModel message, bool isCurrentUser) {
    final sender = _usersCache[message.senderId];
    final senderName = sender?.displayName ?? sender?.username ?? 'Unknown';
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: isCurrentUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser && widget.chatType == ChatType.group)
            CircleAvatar(
              radius: 16,
              child: Text(
                senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          if (!isCurrentUser && widget.chatType == ChatType.group)
            const SizedBox(width: 8),
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? Theme.of(context).primaryColor.withOpacity(0.8)
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!isCurrentUser && widget.chatType == ChatType.group)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4.0),
                      child: Text(
                        senderName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(message.timestamp),
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrentUser
                              ? Colors.white.withOpacity(0.7)
                              : Colors.grey,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.read ? Icons.done_all : Icons.done,
                          size: 12,
                          color: Colors.white.withOpacity(0.7),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
} 