require('dotenv').config();

module.exports = {
    PORT: process.env.PORT || 3000,
    MONGODB_URI: process.env.MONGODB_URI || 'mongodb://localhost:27017/voicechat',
    JWT_SECRET: process.env.JWT_SECRET || 'your-secret-key',
    UPLOADS_DIR: process.env.UPLOADS_DIR || 'uploads'
}; 