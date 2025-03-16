import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../services/api_service.dart';
import '../../models/message.dart';
import '../../models/user.dart';
import '../../models/chat.dart';
import 'dart:async';
import 'package:path/path.dart' as path;

class ChatScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final ChatType chatType;
  final User? otherUser;

  const ChatScreen({
    Key? key,
    required this.chatId,
    required this.chatName,
    required this.chatType,
    this.otherUser,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _imagePicker = ImagePicker();
  final audioPlayer = AudioPlayer();
  final recorder = AudioRecorder();
  String? _recordingPath;
  bool _isRecording = false;
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  List<Message> _messages = [];
  bool _isLoading = true;
  bool _isSending = false;
  String? _currentlyPlayingId;
  bool _mounted = true;
  String? _currentUserId;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeRecorder();
    _getCurrentUserId();
    _loadMessages();
    _requestPermissions();
    
    // Отмечаем сообщения как прочитанные при открытии чата
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markMessagesAsRead();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    audioPlayer.dispose();
    recorder.dispose();
    _recordingTimer?.cancel();
    _refreshTimer?.cancel();
    _mounted = false;
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb) {
      await Permission.microphone.request();
      await Permission.storage.request();
      await Permission.camera.request();
    }
  }

  Future<void> _getCurrentUserId() async {
    final apiService = Provider.of<ApiService>(context, listen: false);
    if (mounted) {
      setState(() {
        _currentUserId = apiService.currentUser?.id;
      });
    }
  }

  Future<void> _loadMessages() async {
    if (!_mounted) return;
    
    setState(() {
      _isLoading = true;
    });

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final messages = await apiService.getChatMessages(widget.chatId);
      
      if (_mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
      
      _setupMessageRefresh();
    } catch (e) {
      print('Error loading messages: $e');
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

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    final content = _messageController.text;
    _messageController.clear();

    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Создаем временное сообщение для отображения
      final tempMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: widget.chatId,
        senderId: _currentUserId!,
        type: MessageType.text,
        content: content,
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(tempMessage);
        });
        _scrollToBottom();
      }
      
      // Отправляем сообщение
      final message = await apiService.sendTextMessage(widget.chatId, content);
      
      if (mounted) {
        setState(() {
          // Заменяем временное сообщение на полученное от сервера
          final index = _messages.indexWhere((m) => m.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = message;
          } else {
            _messages.add(message);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending message: $e')),
        );
      }
    }
  }

  Future<void> _sendImageMessage(File imageFile) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Создаем временное сообщение для отображения
      final tempMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: widget.chatId,
        senderId: _currentUserId!,
        type: MessageType.image,
        content: '',
        timestamp: DateTime.now(),
        status: MessageStatus.sending,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(tempMessage);
        });
        _scrollToBottom();
      }
      
      // Отправляем сообщение
      final message = await apiService.sendFileMessage(widget.chatId, imageFile, 'image');
      
      if (mounted) {
        setState(() {
          // Заменяем временное сообщение на полученное от сервера
          final index = _messages.indexWhere((m) => m.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = message;
          } else {
            _messages.add(message);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending image: $e')),
        );
      }
    }
  }

  Future<void> _sendVoiceMessage(File audioFile, int duration) async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      
      // Создаем временное сообщение для отображения
      final tempMessage = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        chatId: widget.chatId,
        senderId: _currentUserId!,
        type: MessageType.voice,
        content: '',
        timestamp: DateTime.now(),
        duration: duration,
        status: MessageStatus.sending,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(tempMessage);
        });
        _scrollToBottom();
      }
      
      // Отправляем сообщение
      final message = await apiService.sendFileMessage(
        widget.chatId,
        audioFile,
        'voice',
        duration: duration,
      );
      
      if (mounted) {
        setState(() {
          // Заменяем временное сообщение на полученное от сервера
          final index = _messages.indexWhere((m) => m.id == tempMessage.id);
          if (index != -1) {
            _messages[index] = message;
          } else {
            _messages.add(message);
          }
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending voice message: $e')),
        );
      }
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await recorder.hasPermission()) {
        Directory tempDir = await getTemporaryDirectory();
        _recordingPath = '${tempDir.path}/audio_message_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        await recorder.start(
          RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: _recordingPath!,
        );
        
        setState(() {
          _isRecording = true;
          _recordingDuration = 0;
        });

        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: $e')),
      );
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await recorder.stop();
      _recordingTimer?.cancel();
      
      setState(() {
        _isRecording = false;
      });

      if (path != null) {
        await _sendVoiceMessage(File(path), _recordingDuration);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error stopping recording: $e')),
      );
    }
  }

  Future<void> _playVoiceMessage(String url) async {
    try {
      if (_currentlyPlayingId == url) {
        await audioPlayer.stop();
        if (_mounted) {
          setState(() {
            _currentlyPlayingId = null;
          });
        }
      } else {
        await audioPlayer.play(UrlSource(url));
        if (_mounted) {
          setState(() {
            _currentlyPlayingId = url;
          });
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing voice message: $e')),
      );
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

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '$minutes:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final apiService = Provider.of<ApiService>(context, listen: false);
    final currentUser = apiService.currentUser!;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            CircleAvatar(
              backgroundImage: widget.otherUser?.photoUrl != null
                  ? NetworkImage(widget.otherUser!.photoUrl!)
                  : null,
              child: widget.otherUser?.photoUrl == null
                  ? Text(widget.otherUser!.displayName?[0] ?? widget.otherUser!.username[0])
                  : null,
            ),
            const SizedBox(width: 8),
            Text(widget.chatName),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];
                      final isCurrentUser = message.senderId == currentUser.id;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 4.0,
                        ),
                        child: Row(
                          mainAxisAlignment: isCurrentUser
                              ? MainAxisAlignment.end
                              : MainAxisAlignment.start,
                          children: [
                            if (!isCurrentUser) ...[
                              CircleAvatar(
                                backgroundImage: widget.otherUser?.photoUrl != null
                                    ? NetworkImage(widget.otherUser!.photoUrl!)
                                    : null,
                                child: widget.otherUser?.photoUrl == null
                                    ? Text(widget.otherUser!.displayName?[0] ?? widget.otherUser!.username[0])
                                    : null,
                              ),
                              const SizedBox(width: 8),
                            ],
                            Flexible(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isCurrentUser
                                      ? Theme.of(context).primaryColor
                                      : Colors.grey[300],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildMessageContent(message, isCurrentUser),
                                    const SizedBox(height: 4),
                                    Text(
                                      _formatTime(message.timestamp),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isCurrentUser
                                            ? Colors.white70
                                            : Colors.black54,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (isCurrentUser) const SizedBox(width: 40),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.photo),
                    onPressed: _pickAndSendImage,
                  ),
                  IconButton(
                    icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                    onPressed: _isRecording ? _stopRecording : _startRecording,
                  ),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: const InputDecoration(
                        hintText: 'Type a message',
                        border: InputBorder.none,
                      ),
                      onSubmitted: (text) {
                        if (text.isNotEmpty) {
                          _sendMessage();
                        }
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: () {
                      if (_messageController.text.isNotEmpty) {
                        _sendMessage();
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageContent(Message message, bool isCurrentUser) {
    switch (message.type) {
      case MessageType.text:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              message.content,
              style: TextStyle(
                color: isCurrentUser ? Colors.white : Colors.black,
              ),
            ),
            if (isCurrentUser)
              _buildMessageStatus(message),
          ],
        );
      
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: message.fileURL != null
                ? CachedNetworkImage(
                    imageUrl: message.fileURL!,
                    placeholder: (context, url) => const SizedBox(
                      height: 200,
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => const SizedBox(
                      height: 200,
                      child: Center(child: Icon(Icons.error)),
                    ),
                    fit: BoxFit.cover,
                    width: 200,
                  )
                : Container(
                    height: 200,
                    width: 200,
                    color: Colors.grey[300],
                    child: Center(
                      child: message.status == MessageStatus.sending
                          ? const CircularProgressIndicator()
                          : const Icon(Icons.error),
                    ),
                  ),
            ),
            if (message.content.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  message.content,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : Colors.black,
                  ),
                ),
              ),
            if (isCurrentUser)
              _buildMessageStatus(message),
          ],
        );
      
      case MessageType.voice:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: Icon(
                    _currentlyPlayingId == message.fileURL
                        ? Icons.stop
                        : Icons.play_arrow,
                    color: isCurrentUser ? Colors.white : Colors.black,
                  ),
                  onPressed: message.fileURL != null
                      ? () => _playVoiceMessage(message.fileURL!)
                      : null,
                ),
                if (message.duration != null)
                  Text(
                    _formatDuration(message.duration!),
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : Colors.black,
                    ),
                  ),
                if (message.status == MessageStatus.sending)
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isCurrentUser ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
              ],
            ),
            if (isCurrentUser)
              _buildMessageStatus(message),
          ],
        );
    }
  }

  Widget _buildMessageStatus(Message message) {
    IconData? icon;
    Color color = Colors.white70;
    
    switch (message.status) {
      case MessageStatus.sending:
        return const SizedBox(
          width: 12,
          height: 12,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white70,
          ),
        );
      case MessageStatus.sent:
        icon = Icons.check;
        break;
      case MessageStatus.delivered:
        icon = Icons.done_all;
        break;
      case MessageStatus.read:
        icon = Icons.done_all;
        color = Colors.blue;
        break;
      case MessageStatus.error:
        icon = Icons.error_outline;
        color = Colors.red;
        break;
    }
    
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _formatTime(message.timestamp),
            style: TextStyle(
              fontSize: 10,
              color: color,
            ),
          ),
          const SizedBox(width: 4),
          Icon(
            icon,
            size: 14,
            color: color,
          ),
        ],
      ),
    );
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _initializeRecorder() async {
    if (!await recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission not granted')),
        );
      }
    }
  }

  Future<void> _pickAndSendImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      await _sendImageMessage(File(image.path));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  void _setupMessageRefresh() {
    _refreshTimer?.cancel();
    
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (!_mounted) {
        timer.cancel();
        return;
      }
      
      _refreshMessages();
    });
  }
  
  Future<void> _refreshMessages() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      final messages = await apiService.getChatMessages(widget.chatId);
      
      if (_mounted && messages.length != _messages.length) {
        setState(() {
          _messages = messages;
        });
        
        if (messages.length > _messages.length) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToBottom();
          });
        }
      }
    } catch (e) {
      print('Error refreshing messages: $e');
    }
  }

  Future<void> _markMessagesAsRead() async {
    try {
      final apiService = Provider.of<ApiService>(context, listen: false);
      await apiService.markMessagesAsRead(widget.chatId);
    } catch (e) {
      print('Error marking messages as read: $e');
    }
  }
} 