const express = require('express');
const multer = require('multer');
const path = require('path');
const Chat = require('../models/chat');
const auth = require('../middleware/auth');
const config = require('../config');

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

// Send text message
router.post('/:chatId/messages', auth, async (req, res) => {
    try {
        const { content } = req.body;
        const chat = await Chat.findOne({
            _id: req.params.chatId,
            participants: req.user._id
        });

        if (!chat) {
            return res.status(404).json({ message: 'Chat not found' });
        }

        const message = {
            sender: req.user._id,
            type: 'text',
            content
        };

        chat.messages.push(message);
        chat.lastMessage = message;
        await chat.save();

        await chat.populate('messages.sender', 'displayName email photoURL');
        res.status(201).json(message);
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
});

// Send file message (image or voice)
router.post('/:chatId/messages/file', auth, upload.single('file'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }

        const chat = await Chat.findOne({
            _id: req.params.chatId,
            participants: req.user._id
        });

        if (!chat) {
            return res.status(404).json({ message: 'Chat not found' });
        }

        const fileURL = `/uploads/${req.file.filename}`;
        const message = {
            sender: req.user._id,
            type: req.body.type || 'image',
            content: req.body.content || 'File message',
            fileURL,
            duration: req.body.duration
        };

        chat.messages.push(message);
        chat.lastMessage = message;
        await chat.save();

        await chat.populate('messages.sender', 'displayName email photoURL');
        res.status(201).json(message);
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
});

module.exports = router; 