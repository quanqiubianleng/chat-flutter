import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/core/sqlite/message_repository.dart';
import 'package:education/core/global.dart';
import 'package:education/core/notifications/notifications.dart'; // 你的 DbNotification 文件
import 'package:education/modules/chat/models/conversation_info.dart';
import 'package:rxdart/rxdart.dart';

import 'package:education/core/sqlite/database_helper.dart';
import '../pb/protos/chat.pb.dart' as pb;

final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final db = Global.db;
  if (db == null) throw Exception('Database not initialized');
  return MessageRepository(db);
});

// 会话列表 Provider
final conversationListProvider = StreamProvider.family<List<Conversation>, int>((ref, userId) {
  final repo = ref.watch(messageRepositoryProvider);

  return DbNotification()
      .conversationStream
      .startWith(null) // 初始立即触发一次加载
      .switchMap((_) => Stream.fromFuture(repo.getConversations(userId))); // 关键：用 switchMap
});

// 单个会话的消息列表 Provider
final messagesProvider = StreamProvider.family<List<pb.Event>, String>((ref, conversationId) {
  final repo = ref.watch(messageRepositoryProvider);

  return DbNotification()
      .messageStream
      .where((id) => id == conversationId) // 只关心当前会话的变化
      .startWith(conversationId)           // 页面打开时立即加载一次
      .switchMap((_) => Stream.fromFuture(
    repo.getMessagesForConversation(conversationId, limit: 500),
  ));
});