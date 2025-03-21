# VoiceChat

Мобильное приложение для обмена сообщениями с функциями голосового чата, разработанное на Flutter.

## Функциональность

- Аутентификация пользователей (регистрация, вход)
- Поиск пользователей
- Управление друзьями (отправка запросов, принятие/отклонение запросов)
- Личные и групповые чаты
- Обмен текстовыми сообщениями
- Индикация прочтения сообщений
- Счетчики непрочитанных сообщений

## Технологии

- Flutter для кроссплатформенной разработки
- Firebase Authentication для аутентификации
- Cloud Firestore для хранения данных
- Firebase Storage для хранения медиафайлов

## Установка

1. Клонировать репозиторий:
```
git clone https://github.com/NatalyaAtyukova/VoiceChat.git
```

2. Перейти в директорию проекта:
```
cd VoiceChat
```

3. Установить зависимости:
```
flutter pub get
```

4. Запустить приложение:
```
flutter run
```

## Структура проекта

- `lib/models/` - Модели данных
- `lib/screens/` - Экраны приложения
- `lib/services/` - Сервисы для работы с Firebase
- `lib/widgets/` - Многоразовые виджеты

## Автор

Наталья Атюкова
