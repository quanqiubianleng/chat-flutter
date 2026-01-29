// lib/core/notifications/db_notification.dart
import 'dart:async';

class DbNotification {
  static final DbNotification _instance = DbNotification._internal();
  factory DbNotification() => _instance;
  DbNotification._internal();

  final _conversationController = StreamController<void>.broadcast();
  final _messageController = StreamController<String>.broadcast(); // 参数为 conversationId
  final _followerController = StreamController<void>.broadcast();
  final _userController = StreamController<void>.broadcast();
  final _groupMuteController = StreamController<int>.broadcast();

  Stream<void> get conversationStream => _conversationController.stream;
  Stream<String> get messageStream => _messageController.stream;
  Stream<void> get followerStream => _followerController.stream;
  Stream<void> get userStream => _userController.stream;
  Stream<int> get groupMuteStream => _groupMuteController.stream;

  void notifyConversationChanged() {
    _conversationController.add(null);
  }

  void notifyMessageChanged(String conversationId) {
    _messageController.add(conversationId);
  }

  void notifyFollowerChanged() {
    _followerController.add(null);
  }

  void notifyUserChanged(int userID) {
    _userController.add(userID);
  }

  void notifyGroupMuteChanged(int groupID) {
    _groupMuteController.add(groupID);
  }

  void dispose() {
    _conversationController.close();
    _messageController.close();
    _followerController.close();
    _userController.close();
    _groupMuteController.close();
  }
}