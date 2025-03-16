const express = require('express');
const jwt = require('jsonwebtoken');
const User = require('../models/user');
const config = require('../config');
const auth = require('../middleware/auth');

const router = express.Router();

// Register
router.post('/register', async (req, res) => {
    try {
        const { email, password, displayName } = req.body;
        
        // Check if user already exists
        const existingUser = await User.findOne({ email });
        if (existingUser) {
            return res.status(400).json({ message: 'User already exists' });
        }

        // Generate username from email
        const username = email.split('@')[0];

        // Create new user
        const user = new User({
            email,
            username,
            password,
            displayName,
            friends: [],
            friendRequests: []
        });

        await user.save();

        // Generate token
        const token = jwt.sign({ userId: user._id }, config.JWT_SECRET);

        res.status(201).json({
            token,
            user: {
                id: user._id,
                email: user.email,
                username: user.username,
                displayName: user.displayName,
                photoUrl: user.photoUrl,
                friends: user.friends,
                friendRequests: user.friendRequests,
                createdAt: user.createdAt,
                updatedAt: user.updatedAt
            }
        });
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
});

// Login
router.post('/login', async (req, res) => {
    try {
        const { email, password } = req.body;

        // Find user
        const user = await User.findOne({ email });
        if (!user) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        // Check password
        const isMatch = await user.comparePassword(password);
        if (!isMatch) {
            return res.status(401).json({ message: 'Invalid email or password' });
        }

        // Generate token
        const token = jwt.sign({ userId: user._id }, config.JWT_SECRET);

        res.json({
            token,
            user: {
                id: user._id,
                email: user.email,
                username: user.username,
                displayName: user.displayName,
                photoUrl: user.photoUrl,
                friends: user.friends,
                friendRequests: user.friendRequests,
                createdAt: user.createdAt,
                updatedAt: user.updatedAt
            }
        });
    } catch (error) {
        res.status(400).json({ message: error.message });
    }
});

// Get current user
router.get('/me', auth, async (req, res) => {
    res.json({
        user: {
            id: req.user._id,
            email: req.user.email,
            username: req.user.username,
            displayName: req.user.displayName,
            photoUrl: req.user.photoUrl,
            friends: req.user.friends,
            friendRequests: req.user.friendRequests,
            createdAt: req.user.createdAt,
            updatedAt: req.user.updatedAt
        }
    });
});

module.exports = router; 