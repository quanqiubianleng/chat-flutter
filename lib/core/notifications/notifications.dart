// lib/core/notifications/db_notification.dart
import 'dart:async';

class DbNotification {
  static final DbNotification _instance = DbNotification._internal();
  factory DbNotification() => _instance;
  DbNotification._internal();

  final _conversationController = StreamController<void>.broadcast();
  final _messageController = StreamController<String>.broadcast(); // 参数为 conversationId

  Stream<void> get conversationStream => _conversationController.stream;
  Stream<String> get messageStream => _messageController.stream;

  void notifyConversationChanged() {
    _conversationController.add(null);
  }

  void notifyMessageChanged(String conversationId) {
    _messageController.add(conversationId);
  }

  void dispose() {
    _conversationController.close();
    _messageController.close();
  }
}