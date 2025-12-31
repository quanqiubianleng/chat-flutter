import 'dart:ffi';

import 'package:sqflite/sqflite.dart';
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'package:education/modules/chat/models/conversation_info.dart';
import '../cache/user_cache.dart';
import 'database_helper.dart'; // 假设这里定义了 Conversation 类
import 'package:education/core/notifications/notifications.dart';

import 'fts_helper.dart';

class MessageRepository {
  final Database db;

  MessageRepository(this.db);

  /// 保存消息（同时更新会话）
  Future<void> saveMessage(pb.Event message) async {
    // 1. 插入消息
    final result = await db.insert(
      'messages',
      message.toMapForDb(),
      conflictAlgorithm: ConflictAlgorithm.abort,
    );
    print('✅ 消息插入成功，返回ID: $result, "${message.clientMsgId}", senderNickname："${message.senderNickname}"');
    // 2. 更新会话
    final currentUserId = await UserCache.getUserId();
    await _updateConversationFromMessage(message, currentUserId!);

    // 3. 插入FTS
    await FtsHelper.insertMessage(db, msgId: message.msgId, content: message.content, senderNickname: message.senderNickname);
    print('✅ FTS索引插入完成');

    // 关键：通知 Riverpod 更新
    DbNotification().notifyConversationChanged();
    DbNotification().notifyMessageChanged(message.conversationId);
    print('✅ 通知发送完成');
  }

  /// 更新消息状态
  Future<void> updateMessageStatus(String msgId, String newStatus) async {
    await db.update(
      'messages',
      {'status': newStatus},
      where: 'msg_id = ?',
      whereArgs: [msgId],
    );
  }

  /// 更新消息状态
  Future<void> updateMessageByClientMsgId(pb.Event message) async {
    if (message.clientMsgId.isEmpty) return;

    // 方法2：直接查询是否存在 conversation_id 列
    try {
      await db.rawQuery('SELECT conversation_id FROM messages LIMIT 1');
      print('✅ conversation_id 字段可查询');
    } catch (e) {
      print('❌ conversation_id 字段查询失败: $e');
    }

    await db.rawUpdate(
      '''
    UPDATE messages 
    SET status = ?, msg_id = ?, conversation_id = ?
    WHERE client_msg_id = ?
    ''',
      [
        message.status,
        message.msgId,
        message.conversationId,  // 明确是字符串
        message.clientMsgId,
      ],
    );
    print('✅ messages 更新成功 client_msg_id="${message.clientMsgId}"');

    await FtsHelper.updateMessage(db, msgId: message.msgId, content: message.content, senderNickname: message.senderNickname);
    print('FTS 调用参数: msgId="${message.msgId}", content="${message.content}", nickname="${message.senderNickname}"');

    final result = await db.rawQuery('SELECT id,client_msg_id,conversation_id,status FROM messages');
    print(result);
  }

  /// 获取会话ID（单聊）
  Future<String?> getConversationId(int userA, int userB, bool isGroup) async {
    try {
      if (isGroup) {
        // 群聊逻辑：通常群聊有 group_id
        final result = await db.rawQuery(
          '''
        SELECT conversation_id 
        FROM messages 
        WHERE group_id > 0
        AND (from_user = ? OR to_user = ?)
        ORDER BY timestamp DESC
        LIMIT 1
        ''',
          [userA, userA],
        );

        if (result.isNotEmpty && result.first['conversation_id'] != null) {
          return result.first['conversation_id'].toString();
        }
        return null;
      } else {
        // 单聊逻辑：查询两人之间的最近一条消息
        final result = await db.rawQuery(
          '''
        SELECT conversation_id 
        FROM messages 
        WHERE (
          (from_user = ? AND to_user = ?)
          OR (from_user = ? AND to_user = ?)
        )
        AND conversation_id IS NOT NULL 
        AND conversation_id != ''
        ORDER BY timestamp DESC
        LIMIT 1
        ''',
          [userA, userB, userB, userA],
        );

        if (result.isNotEmpty && result.first['conversation_id'] != null) {
          return result.first['conversation_id'].toString();
        }
        return null;
      }
    } catch (e) {
      print('获取会话ID失败: $e');
      return null;
    }
  }

  /// 获取某会话的消息列表（优先使用服务端 conversation_id）
  Future<List<pb.Event>> getMessagesForConversation(String conversationId, {int limit = 30, int offset = 0,}) async {
    final maps = await db.query(
      'messages',
      where: 'conversation_id = ?',
      whereArgs: [conversationId],
      orderBy: 'timestamp ASC, id ASC',
      limit: limit,
      offset: offset,
    );

    return maps.map((m) => pb.Event()..fillFromMap(m)).toList();
  }

  /// 搜索消息（支持服务端 conversation_id）
  Future<List<pb.Event>> searchMessages({required String keyword, int limit = 50, String? conversationId,}) async {
    if (keyword.trim().isEmpty) return [];
    final term = keyword.trim().replaceAll("'", "''");

    String sql = '''
      SELECT m.* FROM messages m
      INNER JOIN messages_fts fts ON m.msg_id = fts.msg_id
      WHERE messages_fts MATCH ?
      ORDER BY m.timestamp DESC
      LIMIT ?
    ''';
    List<dynamic> args = [term, limit];

    if (conversationId != "") {
      sql = '''
      SELECT m.* FROM messages m
      INNER JOIN messages_fts fts ON m.msg_id = fts.msg_id
      WHERE messages_fts MATCH ? AND m.conversation_id = ?
      ORDER BY m.timestamp DESC LIMIT ?
    ''';
      args = [term, conversationId, limit];
    }

    final maps = await db.rawQuery(sql, args);
    return maps.map((m) => pb.Event()..fillFromMap(m)).toList();
  }

  /// 高亮关键字
  String highlightText(String text, String keyword) {
    if (keyword.isEmpty) return text;
    return text.replaceAll(
        RegExp(RegExp.escape(keyword), caseSensitive: false), '**$keyword**');
  }

  /// ==================== 会话操作 ====================
  Future<void> _updateConversationFromMessage(pb.Event message, int currentUserId) async {
    // 必须有服务端 conversationId，否则不处理（或抛异常）
    if (message.conversationId == "") {
      print("Warning: message without conversationId, skipped updating conversation");
      return;
    }

    final convId = message.conversationId;

    final existing = await db.query(
      'conversations',
      where: 'server_conversation_id = ?',
      whereArgs: [convId],
    );

    final Map<String, dynamic> data = {
      'server_conversation_id': convId,
      'last_msg_id': message.msgId,
      'last_content': message.content,
      'last_timestamp': message.timestamp.toInt(),
      'title': message.senderNickname,
      'avatar': message.senderAvatar,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    print(data);
    if (existing.isNotEmpty) {
      final oldUnread = existing.first['unread_count'] as int? ?? 0;
      // 简单判断：如果不是自己发的，+1 未读（实际应结合 last_read_seq）
      data['unread_count'] = message.fromUser == currentUserId ? 0 : oldUnread + 1;

      await db.update(
        'conversations',
        data,
        where: 'server_conversation_id = ?',
        whereArgs: [convId],
      );
      print("会话更新");
    } else {
      data.addAll({
        'type': message.delivery == 'group' ? 'group' : 'single',
        'unread_count': message.fromUser == currentUserId ? 0 : 1,
        'last_msg_id': message.msgId,
        'last_content': message.content,
        'title': message.senderNickname,
        'avatar': message.senderAvatar,
        'user_id': currentUserId,
        'pinned': 0,
        'muted': 0,
        'draft_text': '',
        'last_read_seq': 0,
        'is_deleted': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      await db.insert('conversations', data);
      print("会话插入");
    }
  }

  /// 获取会话列表（按最后消息时间降序，置顶的排前面）
  Future<List<Conversation>> getConversations(int userId) async {
    final maps = await db.query(
      'conversations',
      where: 'is_deleted = 0 AND user_id = ?',
      whereArgs: [userId],
      orderBy: 'pinned DESC, last_timestamp DESC',
    );
    return maps.map(Conversation.fromMap).toList();
  }

  /// 重置未读数
  Future<void> resetUnreadCount(String conversationId) async {
    await db.update(
      'conversations',
      {'unread_count': 0},
      where: 'server_conversation_id = ?',
      whereArgs: [conversationId],
    );

    DbNotification().notifyConversationChanged();
  }

  // 额外建议方法（可按需添加）
  // 更新置顶、免打扰、草稿等
  Future<void> updateConversationSettings({
    required int conversationId,
    bool? pinned,
    bool? muted,
    String? draftText,
  }) async {
    final Map<String, dynamic> data = {};
    if (pinned != null) data['pinned'] = pinned ? 1 : 0;
    if (muted != null) data['muted'] = muted ? 1 : 0;
    if (draftText != null) data['draft_text'] = draftText;

    if (data.isEmpty) return;

    await db.update(
      'conversations',
      data,
      where: 'server_conversation_id = ?',
      whereArgs: [conversationId],
    );

    DbNotification().notifyConversationChanged();
  }

  // 在你的 MessageRepository 类中添加这个方法
  Future<void> syncConversationList(List<ConversationInfo> list) async {
    final batch = db.batch();

    for (final conv in list) {
      final map = conv.toMap();
      map['last_timestamp'] = map['updated_at']; // 用于排序

      // 使用 replace：有则更新，无则插入
      batch.insert(
        'conversations',
        map,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);

    DbNotification().notifyConversationChanged();
  }


  /// 根据服务端 conversation_id（字符串）查询单个会话信息
  /// 返回 Conversation 对象，如果不存在返回 null
  Future<Conversation?> getConversationById(String serverConversationId) async {
    if (serverConversationId.isEmpty) return null;

    final List<Map<String, dynamic>> maps = await db.query(
      'conversations',
      where: 'server_conversation_id = ? AND is_deleted = 0',
      whereArgs: [serverConversationId],
      limit: 1,
    );

    if (maps.isNotEmpty) {
      return Conversation.fromMap(maps.first);
    }

    return null;
  }
}