const express = require('express');
const User = require('../models/user');
const auth = require('../middleware/auth');
const multer = require('multer');
const path = require('path');
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
        fileSize: 5 * 1024 * 1024 // 5MB limit
    }
});

// Search users
router.get('/search', auth, async (req, res) => {
    try {
        const searchTerm = req.query.q;
        if (!searchTerm) {
            return res.status(400).json({ message: 'Search term is required' });
        }

        const users = await User.find({
            $or: [
                { email: { $regex: searchTerm, $options: 'i' } },
                { displayName: { $regex: searchTerm, $options: 'i' } }
            ],
            _id: { $ne: req.user._id } // Exclude current user
        }).select('-password');

        res.json(users);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Update user profile
router.patch('/profile', auth, async (req, res) => {
    const updates = Object.keys(req.body);
    const allowedUpdates = ['displayName'];
    const isValidOperation = updates.every(update => allowedUpdates.includes(update));

    if (!isValidOperation) {
        return res.status(400).json({ message: 'Invalid updates' });
    }

    try {
        updates.forEach(update => req.user[update] = req.body[update]);
        await req.user.save();
        res.json(req.user);
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
});

// Upload profile photo
router.post('/profile/photo', auth, upload.single('photo'), async (req, res) => {
    try {
        if (!req.file) {
            return res.status(400).json({ message: 'No file uploaded' });
        }

        const photoURL = `/uploads/${req.file.filename}`;
        req.user.photoUrl = photoURL;
        await req.user.save();

        res.json({ photoURL });
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
});

// Get user by ID
router.get('/:userId', auth, async (req, res) => {
    try {
        const user = await User.findById(req.params.userId).select('-password');
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        res.json(user);
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Send friend request
router.post('/friends/requests/:userId', auth, async (req, res) => {
    try {
        const userId = req.params.userId;
        
        // Check if user exists
        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        
        // Check if user is trying to add themselves
        if (userId === req.user.id) {
            return res.status(400).json({ message: 'Cannot send friend request to yourself' });
        }
        
        // Check if already friends
        if (req.user.friends.includes(userId)) {
            return res.status(400).json({ message: 'Already friends with this user' });
        }
        
        // Check if friend request already sent
        if (user.friendRequests.includes(req.user.id)) {
            return res.status(400).json({ message: 'Friend request already sent' });
        }
        
        // Add friend request
        user.friendRequests.push(req.user.id);
        await user.save();
        
        res.status(201).json({ message: 'Friend request sent' });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Accept friend request
router.post('/friends/accept/:userId', auth, async (req, res) => {
    try {
        const userId = req.params.userId;
        
        // Check if user exists
        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        
        // Check if friend request exists
        if (!req.user.friendRequests.includes(userId)) {
            return res.status(400).json({ message: 'No friend request from this user' });
        }
        
        // Remove from friend requests and add to friends for both users
        req.user.friendRequests = req.user.friendRequests.filter(id => id.toString() !== userId);
        req.user.friends.push(userId);
        user.friends.push(req.user.id);
        
        await req.user.save();
        await user.save();
        
        res.json({ message: 'Friend request accepted' });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Reject friend request
router.post('/friends/reject/:userId', auth, async (req, res) => {
    try {
        const userId = req.params.userId;
        
        // Check if friend request exists
        if (!req.user.friendRequests.includes(userId)) {
            return res.status(400).json({ message: 'No friend request from this user' });
        }
        
        // Remove from friend requests
        req.user.friendRequests = req.user.friendRequests.filter(id => id.toString() !== userId);
        await req.user.save();
        
        res.json({ message: 'Friend request rejected' });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

// Remove friend
router.delete('/friends/:userId', auth, async (req, res) => {
    try {
        const userId = req.params.userId;
        
        // Check if user exists
        const user = await User.findById(userId);
        if (!user) {
            return res.status(404).json({ message: 'User not found' });
        }
        
        // Check if they are friends
        if (!req.user.friends.includes(userId)) {
            return res.status(400).json({ message: 'Not friends with this user' });
        }
        
        // Remove from friends for both users
        req.user.friends = req.user.friends.filter(id => id.toString() !== userId);
        user.friends = user.friends.filter(id => id.toString() !== req.user.id);
        
        await req.user.save();
        await user.save();
        
        res.json({ message: 'Friend removed' });
    } catch (error) {
        res.status(500).json({ message: error.message });
    }
});

module.exports = router; 