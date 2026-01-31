import 'dart:ffi';

import 'package:sqflite/sqflite.dart';
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'package:education/modules/chat/models/conversation_info.dart';
import '../cache/user_cache.dart';
import '../websocket/ws_event.dart';
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
    print('✅ 消息插入成功，返回ID: $result, "${message.clientMsgId}", timer："${message.timestamp}"');
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

    await db.rawUpdate(
      '''
    UPDATE messages 
    SET status = ?, msg_id = ?, conversation_id = ?, seq = ?
    WHERE client_msg_id = ?
    ''',
      [
        message.status,
        message.msgId,
        message.conversationId,  // 明确是字符串
        message.seq.toInt(),
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
      orderBy: 'timestamp DESC, id DESC',
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

  /// 获取消息游标（优先使用最大 seq 对应的 msg_id）
  Future<String?> getSyncCursor(int userId) async {
    try {
      final result = await db.rawQuery(
        '''
      SELECT msg_id 
      FROM messages
      WHERE from_user = ? or to_user = ?
        AND msg_id IS NOT NULL
      ORDER BY msg_id DESC, timestamp DESC, id DESC
      LIMIT 1
      ''',
        [userId, userId],
      );

      if (result.isNotEmpty) {
        return result.first['msg_id'] as String?;
      }
      return null;
    } catch (e) {
      print('❌ getSyncCursorByConversation error: $e');
      return null;
    }
  }

  /// 批量同步离线消息
  Future<void> syncOfflineMessages(List<pb.Event> messages) async {
    if (messages.isEmpty) return;

    final batch = db.batch();
    final currentUserId = await UserCache.getUserId();

    for (final msg in messages) {
      // 先检查 msg_id 是否已存在
      final exists = await db.query(
        'messages',
        where: 'msg_id = ?',
        whereArgs: [msg.msgId],
        limit: 1,
      );

      if (exists.isNotEmpty) {
        // 已存在，跳过或根据需要更新状态
        continue;
      }

      // 插入消息
      batch.insert(
        'messages',
        msg.toMapForDb(),
        conflictAlgorithm: ConflictAlgorithm.abort,
      );

      // 会话更新
      // 注意这里要异步更新会话，否则 batch 仅处理消息表
      _updateConversationFromMessage(msg, currentUserId!);

      // FTS 索引更新
      FtsHelper.insertMessage(db,
          msgId: msg.msgId, content: msg.content, senderNickname: msg.senderNickname);
    }

    // 提交批量插入
    await batch.commit(noResult: true);

    // 通知前端更新
    DbNotification().notifyConversationChanged();
    for (final msg in messages) {
      DbNotification().notifyMessageChanged(msg.conversationId);
    }

    print('✅ 同步离线消息完成，总条数: ${messages.length}');
  }



  /// ==================== 会话操作 ====================
  /*Future<void> _updateConversationFromMessage(pb.Event message, int currentUserId) async {
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
      'user_id': currentUserId,
      'server_conversation_id': convId,
      'last_msg_id': message.msgId,
      'last_content': message.content,
      'last_timestamp': message.timestamp.toInt(),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
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
        'pinned': 0,
        'muted': 0,
        'draft_text': '',
        'last_read_seq': 0,
        'is_deleted': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      });
      if(message.type == WSEventType.createGroup){
        data['title'] = message.senderNickname;
        data['avatar'] = message.senderAvatar;
      }
      await db.insert('conversations', data);
      print("会话插入");
    }
  }*/

  Future<void> _updateConversationFromMessage(pb.Event message, int currentUserId) async {
    if (message.conversationId == "") {
      print("Warning: message without conversationId, skipped");
      return;
    }

    final convId = message.conversationId;

    // 准备要更新的核心字段（每次消息都要刷）
    final Map<String, dynamic> updateData = {
      'last_msg_id': message.msgId,
      'last_content': message.content ?? '',
      'last_timestamp': message.timestamp.toInt(),
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };

    // 先尝试更新（最重要的一步）
    final rowsAffected = await db.update(
      'conversations',
      updateData,
      where: 'server_conversation_id = ? AND user_id = ?',
      whereArgs: [convId, currentUserId],
    );

    if (rowsAffected > 0) {
      // 已存在 → 只需处理未读数递增
      if (message.fromUser != currentUserId) {
        await db.rawUpdate(
          '''UPDATE conversations 
           SET unread_count = unread_count + 1 
           WHERE server_conversation_id = ? AND user_id = ?''',
          [convId, currentUserId],
        );
      }
      print("会话已更新: $convId");
    } else {
      // 不存在 → 完整插入新会话
      final insertData = Map<String, dynamic>.from(updateData);
      insertData.addAll({
        'user_id': currentUserId,
        'server_conversation_id': convId,
        'type': message.delivery == WSDelivery.group ? WSDelivery.group : WSDelivery.single,
        'unread_count': message.fromUser == currentUserId ? 0 : 1,
        'pinned': 0,
        'muted': 0,
        'draft_text': '',
        'last_read_seq': 0,
        'is_deleted': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        // 'title' 和 'avatar' 建议后面由专门的消息或拉取覆盖，不要在这里硬写
      });

      if (message.type == WSEventType.createGroup) {
        insertData['title'] = message.senderNickname ?? '群聊';
        insertData['avatar'] = message.senderAvatar ?? '';
      }

      await db.insert('conversations', insertData);
      print("会话新建插入: $convId");
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

  /// 更新会话名称
  Future<void> updateConvTitle(String conversationId, String title) async {
    final res = await db.update(
      'conversations',
      {'title': title},
      where: 'server_conversation_id = ?',
      whereArgs: [conversationId],
    );
    print("updateConvTitle");
    print(res);
    print(title);
    print(conversationId);
    DbNotification().notifyConversationChanged();
  }

  /// 更新会话头像
  Future<void> updateConvAvatar(String conversationId, String avatar) async {
    final res = await db.update(
      'conversations',
      {'avatar': avatar},
      where: 'server_conversation_id = ?',
      whereArgs: [conversationId],
    );
    print("updateConvAvatar");
    print(res);
    print(avatar);
    print(conversationId);
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