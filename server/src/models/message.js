const mongoose = require('mongoose');

const messageSchema = new mongoose.Schema({
  chatId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'Chat',
    required: true
  },
  senderId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true
  },
  type: {
    type: String,
    enum: ['text', 'image', 'voice'],
    default: 'text'
  },
  content: {
    type: String,
    required: true
  },
  fileURL: {
    type: String
  },
  duration: {
    type: Number
  },
  read: {
    type: Boolean,
    default: false
  },
  readBy: [{
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User'
  }],
  status: {
    type: String,
    enum: ['sending', 'sent', 'delivered', 'read', 'error'],
    default: 'sent'
  }
}, { timestamps: true });

// Виртуальное поле для совместимости с клиентом
messageSchema.virtual('timestamp').get(function() {
  return this.createdAt;
});

// Включаем виртуальные поля при преобразовании в JSON
messageSchema.set('toJSON', {
  virtuals: true,
  transform: function(doc, ret) {
    ret.id = ret._id;
    delete ret._id;
    delete ret.__v;
    
    // Определяем статус на основе других полей, если он не установлен явно
    if (!ret.status || ret.status === 'sent') {
      if (ret.read) {
        ret.status = 'read';
      } else if (ret.readBy && ret.readBy.length > 0) {
        ret.status = 'delivered';
      } else {
        ret.status = 'sent';
      }
    }
    
    return ret;
  }
});

module.exports = mongoose.model('Message', messageSchema); 