const express = require('express');
const multer = require('multer');
const path = require('path');
const Chat = require('../models/chat');
const auth = require('../middleware/auth');
const config = require('../config');
const Message = require('../models/message');

const router = express.Router();

// Configure multer for file uploads
const storage = multer.diskStorage({
    destination: (req, file, cb) => {
        cb(null, path.join(__dirname, '../../', config.UPLOADS_DIR));
    },
    filename: (req, file, cb) => {
        const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
        cb(null, uniqueSuffix + path.extname(file.originalname));
    }
});

const upload = multer({
    storage,
    limits: {
        fileSize: 10 * 1024 * 1024 // 10MB limit
    }
});

// Get all chats for current user
router.get('/', auth, async (req, res) => {
    try {
        const chats = await Chat.find({
            participants: req.user._id
        })
        .populate('participants', 'displayName email photoURL')
        .populate('lastMessage')
        .sort({ updatedAt: -1 });

        res.json(chats);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Create new chat
router.post('/', auth, async (req, res) => {
    try {
        const { participantId } = req.body;

        // Check if chat already exists
        const existingChat = await Chat.findOne({
            participants: {
                $all: [req.user._id, participantId],
                $size: 2
            }
        });

        if (existingChat) {
            return res.json(existingChat);
        }

        const chat = new Chat({
            participants: [req.user._id, participantId]
        });

        await chat.save();
        await chat.populate('participants', 'displayName email photoURL');

        res.status(201).json(chat);
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
});

// Get chat messages
router.get('/:chatId/messages', auth, async (req, res) => {
    try {
        const chat = await Chat.findOne({
            _id: req.params.chatId,
            participants: req.user._id
        }).populate('messages.sender', 'displayName email photoURL');

        if (!chat) {
            return res.status(404).json({ message: 'Chat not found' });
        }

        res.json(chat.messages);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Отправить текстовое сообщение в чат
router.post('/:chatId/messages', auth, async (req, res) => {
  try {
    const { content, type = 'text' } = req.body;
    const chatId = req.params.chatId;
    const userId = req.user.id;

    // Проверяем, существует ли чат
    const chat = await Chat.findById(chatId);
    if (!chat) {
      return res.status(404).json({ message: 'Chat not found' });
    }

    // Проверяем, является ли пользователь участником чата
    if (!chat.participants.includes(userId)) {
      return res.status(403).json({ message: 'You are not a participant of this chat' });
    }

    // Создаем новое сообщение
    const message = new Message({
      chatId,
      senderId: userId,
      type,
      content,
      status: 'sent',
      readBy: [userId], // Отправитель автоматически считается прочитавшим сообщение
    });

    await message.save();

    // Обновляем последнее сообщение в чате
    chat.lastMessage = message._id;
    await chat.save();

    // Получаем обновленное сообщение с заполненными полями
    const populatedMessage = await Message.findById(message._id);

    res.status(201).json(populatedMessage);
  } catch (error) {
    console.error('Error sending message:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Отправить файловое сообщение в чат
router.post('/:chatId/messages/file', auth, upload.single('file'), async (req, res) => {
  try {
    const { type = 'image', duration } = req.body;
    const chatId = req.params.chatId;
    const userId = req.user.id;
    const file = req.file;

    if (!file) {
      return res.status(400).json({ message: 'No file uploaded' });
    }

    // Проверяем, существует ли чат
    const chat = await Chat.findById(chatId);
    if (!chat) {
      return res.status(404).json({ message: 'Chat not found' });
    }

    // Проверяем, является ли пользователь участником чата
    if (!chat.participants.includes(userId)) {
      return res.status(403).json({ message: 'You are not a participant of this chat' });
    }

    // Загружаем файл в хранилище
    const fileURL = `${config.serverUrl}/uploads/${file.filename}`;

    // Создаем новое сообщение
    const message = new Message({
      chatId,
      senderId: userId,
      type,
      content: '',
      fileURL,
      duration: duration ? parseInt(duration) : undefined,
      status: 'sent',
      readBy: [userId], // Отправитель автоматически считается прочитавшим сообщение
    });

    await message.save();

    // Обновляем последнее сообщение в чате
    chat.lastMessage = message._id;
    await chat.save();

    // Получаем обновленное сообщение с заполненными полями
    const populatedMessage = await Message.findById(message._id);

    res.status(201).json(populatedMessage);
  } catch (error) {
    console.error('Error sending file message:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

// Отметить сообщения в чате как прочитанные
router.post('/:chatId/messages/read', auth, async (req, res) => {
  try {
    const chatId = req.params.chatId;
    const userId = req.user.id;

    // Проверяем, существует ли чат
    const chat = await Chat.findById(chatId);
    if (!chat) {
      return res.status(404).json({ message: 'Chat not found' });
    }

    // Проверяем, является ли пользователь участником чата
    if (!chat.participants.includes(userId)) {
      return res.status(403).json({ message: 'You are not a participant of this chat' });
    }

    // Обновляем все сообщения, отправленные не текущим пользователем
    await Message.updateMany(
      { 
        chatId: chatId, 
        senderId: { $ne: userId },
        readBy: { $ne: userId }
      },
      { 
        $addToSet: { readBy: userId },
        $set: { read: true }
      }
    );

    return res.status(200).json({ message: 'Messages marked as read' });
  } catch (error) {
    console.error('Error marking messages as read:', error);
    res.status(500).json({ message: 'Server error' });
  }
});

module.exports = router; 