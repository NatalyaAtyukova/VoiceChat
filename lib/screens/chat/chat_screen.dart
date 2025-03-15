import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import '../../services/firebase_service.dart';
import '../../models/message_model.dart';
import '../../models/user_model.dart';
import '../../models/chat_model.dart';
import 'dart:async';

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
  final ImagePicker _imagePicker = ImagePicker();
  // final _audioRecorder = Record();
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  List<MessageModel> _messages = [];
  bool _isLoading = true;
  String _currentUserId = '';
  Map<String, UserModel> _usersCache = {};
  bool _isSending = false;
  bool _isRecording = false;
  String? _recordingPath;
  DateTime? _recordingStartTime;
  String? _currentlyPlayingId;
  bool _mounted = true;

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
    _loadMessages();
    _requestPermissions();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _audioPlayer.dispose();
    // _audioRecorder.dispose();
    _mounted = false;
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb) {
      // Запрашиваем разрешения только на мобильных платформах
      // await Permission.microphone.request();
      await Permission.storage.request();
      await Permission.camera.request();
    }
  }

  Future<void> _getCurrentUserId() async {
    final firebaseService = Provider.of<FirebaseService>(context, listen: false);
    final user = firebaseService.auth.currentUser;
    if (user != null && _mounted) {
      setState(() {
        _currentUserId = user.uid;
      });
      print('Current user ID set to: ${user.uid}');
    } else {
      print('Warning: Current user is null or widget is not mounted');
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
      if (_currentUserId.isNotEmpty) {
        await firebaseService.markMessagesAsRead(widget.chatId, _currentUserId);
      }
      
      // Загружаем сообщения
      print('Loading messages for chat: ${widget.chatId}');
      final messages = await firebaseService.getChatMessagesOnce(widget.chatId);
      print('Loaded ${messages.length} messages');
      
      if (_mounted) {
        setState(() {
          _messages = messages;
          _isLoading = false;
        });
        
        // Загружаем информацию о пользователях
        _loadUserInfo();
      }
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

  Future<void> _sendTextMessage() async {
    if (_messageController.text.trim().isEmpty || _isSending) {
      print('Message is empty or already sending, skipping');
      return;
    }

    final text = _messageController.text.trim();
    print('Preparing to send message: "$text"');
    _messageController.clear();

    if (!_mounted) {
      print('Widget is not mounted, skipping send');
      return;
    }
    
    // Проверяем, что ID пользователя установлен
    if (_currentUserId.isEmpty) {
      print('Error: Current user ID is not set');
      await _getCurrentUserId();
      if (_currentUserId.isEmpty) {
        print('Still unable to get current user ID');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: Unable to identify current user')),
        );
        return;
      }
    }
    
    setState(() {
      _isSending = true;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      print('Sending message to chat ${widget.chatId} from user $_currentUserId: $text');
      
      // Устанавливаем таймаут для операции отправки
      bool isCompleted = false;
      
      // Создаем таймер для отслеживания зависания
      Future.delayed(const Duration(seconds: 15), () {
        if (!isCompleted && _mounted) {
          print('Message sending timeout reached');
          setState(() {
            _isSending = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Message sending is taking too long. Please try again.')),
          );
        }
      });
      
      await firebaseService.sendMessage(
        widget.chatId, 
        _currentUserId, 
        text
      );
      
      isCompleted = true;
      print('Message sent successfully');
      
      // Обновляем список сообщений
      await _loadMessages();
    } catch (e) {
      if (_mounted) {
        print('Error sending message: $e');
        
        String errorMessage = 'Error sending message';
        
        // Более информативные сообщения об ошибках
        if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Permission denied. Please check your permissions.';
        } else if (e.toString().contains('not found')) {
          errorMessage = 'Chat not found. It may have been deleted.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
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

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (image != null) {
        // Сжимаем изображение перед отправкой
        final compressedImage = await _compressImage(image);
        _sendImageMessage(compressedImage);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: ${e.toString()}')),
      );
    }
  }

  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      
      if (photo != null) {
        // Сжимаем изображение перед отправкой
        final compressedPhoto = await _compressImage(photo);
        _sendImageMessage(compressedPhoto);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: ${e.toString()}')),
      );
    }
  }

  // Метод для сжатия изображения
  Future<XFile> _compressImage(XFile file) async {
    print('Compressing image: ${file.path}');
    
    try {
      // Читаем байты изображения
      final bytes = await file.readAsBytes();
      final fileSize = bytes.length;
      print('Original image size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
      
      // Максимальный размер изображения (800 KB для веб, 500 KB для мобильных)
      final maxSize = kIsWeb ? 800 * 1024 : 500 * 1024;
      
      // Если изображение уже меньше максимального размера, возвращаем его как есть
      if (fileSize <= maxSize) {
        print('Image already smaller than max size, no compression needed');
        return file;
      }
      
      // Вычисляем необходимое качество сжатия на основе размера файла
      int quality;
      if (fileSize > 10 * 1024 * 1024) { // > 10 MB
        quality = 20; // Очень сильное сжатие для очень больших изображений
      } else if (fileSize > 5 * 1024 * 1024) { // > 5 MB
        quality = 25; // Очень сильное сжатие для очень больших изображений
      } else if (fileSize > 3 * 1024 * 1024) { // > 3 MB
        quality = 30; // Сильное сжатие для больших изображений
      } else if (fileSize > 2 * 1024 * 1024) { // > 2 MB
        quality = 40; // Сильное сжатие для больших изображений
      } else if (fileSize > 1024 * 1024) { // > 1 MB
        quality = 50; // Среднее сжатие
      } else if (fileSize > maxSize) {
        quality = 60; // Легкое сжатие
      } else {
        quality = 70; // Минимальное сжатие
      }
      
      print('Compressing with quality: $quality');
      
      if (kIsWeb) {
        // На веб-платформе используем другой подход для сжатия
        // Для очень больших изображений на веб-платформе
        if (fileSize > 5 * 1024 * 1024) {
          print('Very large image on web platform, applying special compression');
          
          // Для веб-платформы возвращаем оригинальный файл,
          // но с пометкой о необходимости сильного сжатия
          // Сжатие будет выполнено при загрузке в Firebase Storage
          return file;
        } else {
          // Для файлов среднего размера на веб-платформе
          // просто возвращаем оригинальный файл
          print('Web platform detected, returning original file');
          return file;
        }
      }
      
      // Для мобильных платформ используем flutter_image_compress
      Uint8List? compressedBytes;
      
      if (file.path.toLowerCase().endsWith('.png')) {
        // Для PNG файлов
        compressedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          quality: quality,
          format: CompressFormat.png,
        );
      } else {
        // Для JPEG и других форматов
        compressedBytes = await FlutterImageCompress.compressWithList(
          bytes,
          quality: quality,
          format: CompressFormat.jpeg,
        );
      }
      
      if (compressedBytes == null) {
        print('Compression failed, returning original file');
        return file;
      }
      
      print('Compressed image size: ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
      
      // Если сжатие не дало значительного эффекта, пробуем еще раз с более низким качеством
      if (compressedBytes.length > maxSize && quality > 20) {
        print('Compression not effective enough, trying again with lower quality');
        quality = quality - 20;
        
        if (file.path.toLowerCase().endsWith('.png')) {
          compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            quality: quality,
            format: CompressFormat.png,
          );
        } else {
          compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            quality: quality,
            format: CompressFormat.jpeg,
          );
        }
        
        print('Compressed image size (second attempt): ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
      }
      
      // Если и второе сжатие не помогло, пробуем уменьшить размер изображения
      if (compressedBytes.length > maxSize) {
        print('Compression still not effective enough, reducing image dimensions');
        
        if (file.path.toLowerCase().endsWith('.png')) {
          compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            quality: quality,
            format: CompressFormat.png,
            minWidth: 1024, // Ограничиваем ширину
            minHeight: 1024, // Ограничиваем высоту
          );
        } else {
          compressedBytes = await FlutterImageCompress.compressWithList(
            bytes,
            quality: quality,
            format: CompressFormat.jpeg,
            minWidth: 1024, // Ограничиваем ширину
            minHeight: 1024, // Ограничиваем высоту
          );
        }
        
        print('Compressed image size (with dimension reduction): ${(compressedBytes.length / 1024).toStringAsFixed(2)} KB');
      }
      
      // Создаем временный файл для сжатого изображения
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempPath = '${tempDir.path}/compressed_$timestamp.jpg';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(compressedBytes);
      
      print('Compressed image saved to: $tempPath');
      
      return XFile(tempPath);
    } catch (e) {
      print('Error compressing image: $e');
      // В случае ошибки возвращаем оригинальный файл
      return file;
    }
  }

  Future<void> _sendImageMessage(XFile imageFile) async {
    if (!_mounted) {
      print('Widget is not mounted, skipping image send');
      return;
    }
    
    final fileSize = await imageFile.length();
    print('Preparing to send image: ${imageFile.path}, size: ${(fileSize / 1024).toStringAsFixed(2)} KB');
    
    // Проверяем размер файла и уменьшаем его, если он слишком большой
    XFile fileToSend = imageFile;
    if (fileSize > 1024 * 1024) { // Больше 1 МБ
      // Показываем сообщение о сжатии изображения
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Compressing image...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Сжимаем изображение
      fileToSend = await _compressImage(imageFile);
      print('Image compressed to: ${(await fileToSend.length() / 1024).toStringAsFixed(2)} KB');
    }
    
    setState(() {
      _isSending = true;
    });

    // Создаем переменную для отслеживания прогресса загрузки
    double _uploadProgress = 0.0;
    
    // Создаем контроллер для SnackBar, чтобы можно было его обновлять
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // Функция для обновления индикатора прогресса
    void updateProgressIndicator(double progress) {
      if (!_mounted) return;
      
      // Скрываем предыдущий SnackBar
      scaffoldMessenger.hideCurrentSnackBar();
      
      // Показываем новый SnackBar с обновленным прогрессом
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text('Uploading image... ${(progress * 100).toStringAsFixed(0)}%'),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.white24,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ],
          ),
          duration: const Duration(days: 1), // Очень долгий срок, мы сами закроем
        ),
      );
    }
    
    // Показываем начальный индикатор прогресса
    updateProgressIndicator(0.01); // Начинаем с 1%
    
    // Запускаем таймер для эмуляции прогресса загрузки
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!_mounted || _uploadProgress >= 0.99) {
        timer.cancel();
        return;
      }
      
      // Увеличиваем прогресс на небольшое значение
      // Для больших файлов прогресс увеличивается медленнее
      final fileKB = fileSize / 1024;
      double increment = 0.05; // Базовый инкремент
      
      if (fileKB > 5000) { // > 5 MB
        increment = 0.01;
      } else if (fileKB > 2000) { // > 2 MB
        increment = 0.02;
      } else if (fileKB > 1000) { // > 1 MB
        increment = 0.03;
      }
      
      _uploadProgress += increment;
      if (_uploadProgress > 0.95) _uploadProgress = 0.95; // Максимум 95%
      
      updateProgressIndicator(_uploadProgress);
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      print('Starting image upload to Firebase Storage');
      
      // Устанавливаем таймаут для операции отправки
      bool isCompleted = false;
      
      // Создаем таймер для отслеживания зависания
      // Увеличиваем таймаут до 5 минут для больших файлов
      Future.delayed(const Duration(minutes: 5), () {
        if (!isCompleted && _mounted) {
          print('Image sending timeout reached after 5 minutes');
          setState(() {
            _isSending = false;
          });
          scaffoldMessenger.hideCurrentSnackBar();
          scaffoldMessenger.showSnackBar(
            const SnackBar(content: Text('Image upload is taking too long. Please try again with a smaller image or check your network connection.')),
          );
        }
      });
      
      // Для веб-платформы используем другой подход
      if (kIsWeb) {
        print('Using web approach for sending image');
        
        // Читаем файл как массив байтов
        final bytes = await fileToSend.readAsBytes();
        print('Read ${bytes.length} bytes from file');
        
        // Отправляем изображение
        await firebaseService.sendImageMessage(widget.chatId, _currentUserId, bytes);
      } else {
        // Для мобильной платформы используем обычный подход
        await firebaseService.sendImageMessage(widget.chatId, _currentUserId, fileToSend);
      }
      
      isCompleted = true;
      _uploadProgress = 1.0; // 100%
      updateProgressIndicator(1.0);
      
      print('Image sent successfully');
      
      if (_mounted) {
        // Небольшая задержка, чтобы пользователь увидел 100%
        await Future.delayed(const Duration(milliseconds: 500));
        
        scaffoldMessenger.hideCurrentSnackBar();
        scaffoldMessenger.showSnackBar(
          const SnackBar(
            content: Text('Image sent successfully'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      // Обновляем список сообщений
      await _loadMessages();
    } catch (e) {
      print('Error sending image: $e');
      if (_mounted) {
        scaffoldMessenger.hideCurrentSnackBar();
        
        String errorMessage = 'Error sending image';
        
        // Более информативные сообщения об ошибках
        if (e.toString().contains('too large')) {
          errorMessage = 'Image is too large. Please use a smaller image.';
        } else if (e.toString().contains('network')) {
          errorMessage = 'Network error. Please check your connection and try again.';
        } else if (e.toString().contains('permission')) {
          errorMessage = 'Permission denied. Please check your storage permissions.';
        } else if (e.toString().contains('timeout')) {
          errorMessage = 'Upload timed out. Please try again with a smaller image or check your network connection.';
        } else if (e.toString().contains('unauthorized')) {
          errorMessage = 'Unauthorized access to storage. Please log in again.';
        } else if (e.toString().contains('canceled')) {
          errorMessage = 'Upload was canceled.';
        }
        
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text(errorMessage)),
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

  // Временно отключаем запись голосовых сообщений
  /*
  Future<void> _startRecording() async {
    try {
      // Проверяем разрешение на запись
      if (await _audioRecorder.hasPermission()) {
        // Создаем временный файл для записи
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
        
        // Начинаем запись
        await _audioRecorder.start(
          path: path,
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          samplingRate: 44100,
        );
        
        if (_mounted) {
          setState(() {
            _isRecording = true;
            _recordingPath = path;
            _recordingStartTime = DateTime.now();
          });
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied')),
        );
      }
    } catch (e) {
      print('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error starting recording: ${e.toString()}')),
      );
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording || _recordingPath == null) return;
    
    try {
      final path = await _audioRecorder.stop();
      
      if (path != null && _mounted) {
        setState(() {
          _isRecording = false;
        });
        
        // Вычисляем длительность записи
        final now = DateTime.now();
        final duration = _recordingStartTime != null 
            ? now.difference(_recordingStartTime!).inSeconds 
            : 0;
        
        // Отправляем голосовое сообщение
        _sendVoiceMessage(File(path), duration);
      }
    } catch (e) {
      print('Error stopping recording: $e');
      if (_mounted) {
        setState(() {
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error stopping recording: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _sendVoiceMessage(File audioFile, int durationInSeconds) async {
    if (!_mounted) return;
    
    setState(() {
      _isSending = true;
    });

    try {
      final firebaseService = Provider.of<FirebaseService>(context, listen: false);
      await firebaseService.sendVoiceMessage(widget.chatId, _currentUserId, audioFile, durationInSeconds);
      
      // Обновляем список сообщений
      await _loadMessages();
    } catch (e) {
      print('Error sending voice message: $e');
      if (_mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending voice message: ${e.toString()}')),
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
  */

  Future<void> _playVoiceMessage(String url, String messageId) async {
    try {
      if (_currentlyPlayingId == messageId) {
        // Если это то же сообщение, которое сейчас воспроизводится, останавливаем его
        await _audioPlayer.stop();
        if (_mounted) {
          setState(() {
            _currentlyPlayingId = null;
          });
        }
      } else {
        // Останавливаем текущее воспроизведение, если есть
        if (_currentlyPlayingId != null) {
          await _audioPlayer.stop();
        }
        
        // Начинаем воспроизведение нового сообщения
        await _audioPlayer.play(UrlSource(url));
        
        if (_mounted) {
          setState(() {
            _currentlyPlayingId = messageId;
          });
        }
        
        // Слушаем событие окончания воспроизведения
        _audioPlayer.onPlayerComplete.listen((event) {
          if (_mounted && _currentlyPlayingId == messageId) {
            setState(() {
              _currentlyPlayingId = null;
            });
          }
        });
      }
    } catch (e) {
      print('Error playing voice message: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error playing voice message: ${e.toString()}')),
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
          _buildInputArea(),
        ],
      ),
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
            icon: const Icon(Icons.add),
            onPressed: () {
              _showAttachmentOptions();
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
              onSubmitted: (_) => _sendTextMessage(),
            ),
          ),
          // Временно отключаем запись голосовых сообщений
          /*
          _isRecording
              ? Row(
                  children: [
                    Text(_recordingStartTime != null 
                        ? _formatDuration(DateTime.now().difference(_recordingStartTime!).inSeconds) 
                        : '0:00'),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.stop, color: Colors.red),
                      onPressed: _stopRecording,
                    ),
                  ],
                )
              : Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.mic),
                      onPressed: _startRecording,
                    ),
                    IconButton(
                      icon: _isSending
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send),
                      onPressed: _sendTextMessage,
                    ),
                  ],
                ),
          */
          IconButton(
            icon: _isSending
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            onPressed: _sendTextMessage,
          ),
        ],
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
          ],
        ),
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
                  _buildMessageContent(message, isCurrentUser),
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

  Widget _buildMessageContent(MessageModel message, bool isCurrentUser) {
    switch (message.type) {
      case MessageType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: message.mediaUrl ?? '',
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
              ),
            ),
            if (message.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  message.text,
                  style: TextStyle(
                    color: isCurrentUser ? Colors.white : null,
                  ),
                ),
              ),
          ],
        );
      
      case MessageType.voice:
        return InkWell(
          onTap: () {
            if (message.mediaUrl != null) {
              _playVoiceMessage(message.mediaUrl!, message.id);
            }
          },
          child: Row(
            children: [
              Icon(
                _currentlyPlayingId == message.id ? Icons.pause : Icons.play_arrow,
                color: isCurrentUser ? Colors.white : Theme.of(context).primaryColor,
                size: 24,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice message',
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : null,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (message.duration != null)
                    Text(
                      _formatDuration(message.duration!),
                      style: TextStyle(
                        color: isCurrentUser ? Colors.white70 : Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      
      case MessageType.text:
      default:
        return Text(
          message.text,
          style: TextStyle(
            color: isCurrentUser ? Colors.white : null,
          ),
        );
    }
  }
} 