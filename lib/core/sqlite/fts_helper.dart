import 'package:sqflite/sqflite.dart';

class FtsHelper {
  static Future<void> insertMessage(Database db, {
    required String msgId,
    required String content,
    required String senderNickname,
  }) async {
    if (msgId.isEmpty) return;

    try {
      await db.insert('messages_fts', {
        'msg_id': msgId,
        'content': content ?? '',
        'sender_nickname': senderNickname ?? '',
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('FTS insert error: $e');
    }
  }

  static Future<void> updateMessage(Database db, {
    required String msgId,
    required String content,
    required String senderNickname,
  }) async {
    if (msgId.isEmpty) return;

    try {
      // 先删除旧记录 - 需要根据 msg_id 找到对应的 rowid
      final result = await db.rawQuery('''
        SELECT rowid FROM messages_fts 
        WHERE msg_id = ?
      ''', [msgId]);

      if (result.isNotEmpty) {
        final rowid = result.first['rowid'] as int?;
        if (rowid != null) {
          await db.rawInsert('''
            INSERT INTO messages_fts(messages_fts, rowid)
            VALUES('delete', ?)
          ''', [rowid]);
        }
      }

      // 再插入新记录
      await db.insert('messages_fts', {
        'msg_id': msgId,
        'content': content ?? '',
        'sender_nickname': senderNickname ?? '',
      });
    } catch (e) {
      print('FTS update error: $e');
    }
  }

  static Future<void> deleteMessage(Database db, {
    required String msgId,
    required String content,
    required String senderNickname,
  }) async {
    if (msgId.isEmpty) return;

    try {
      // 方法1: 通过 msg_id 查找 rowid 然后删除
      final result = await db.rawQuery('''
        SELECT rowid FROM messages_fts 
        WHERE msg_id = ?
      ''', [msgId]);

      if (result.isNotEmpty) {
        final rowid = result.first['rowid'] as int?;
        if (rowid != null) {
          await db.rawInsert('''
            INSERT INTO messages_fts(messages_fts, rowid)
            VALUES('delete', ?)
          ''', [rowid]);
        }
      }

      // 方法2: 如果你确定 msg_id 就是 rowid（或者可以转换为 rowid）
      // 比如 msgId 是 "1766585975078-0"，取其数字部分
      // try {
      //   final rowid = int.tryParse(msgId.split('-').first);
      //   if (rowid != null) {
      //     await db.rawInsert('''
      //       INSERT INTO messages_fts(messages_fts, rowid)
      //       VALUES('delete', ?)
      //     ''', [rowid]);
      //   }
      // } catch (e) {
      //   print('Alternative delete error: $e');
      // }
    } catch (e) {
      print('FTS delete error: $e');
    }
  }

  // 新增：批量删除方法
  static Future<void> deleteMessages(Database db, List<String> msgIds) async {
    if (msgIds.isEmpty) return;

    try {
      // 构建查询条件
      final placeholders = List.filled(msgIds.length, '?').join(',');

      // 查询所有对应的 rowid
      final results = await db.rawQuery('''
        SELECT rowid FROM messages_fts 
        WHERE msg_id IN ($placeholders)
      ''', msgIds);

      // 批量删除
      final batch = db.batch();
      for (final row in results) {
        final rowid = row['rowid'] as int?;
        if (rowid != null) {
          batch.rawInsert('''
            INSERT INTO messages_fts(messages_fts, rowid)
            VALUES('delete', ?)
          ''', [rowid]);
        }
      }
      await batch.commit();
    } catch (e) {
      print('FTS batch delete error: $e');
    }
  }

  // 新增：清空 FTS 表
  static Future<void> clearAll(Database db) async {
    try {
      await db.rawInsert('''
        INSERT INTO messages_fts(messages_fts)
        VALUES('delete-all')
      ''');
    } catch (e) {
      print('FTS clear all error: $e');
    }
  }

  // 新增：搜索方法
  static Future<List<Map<String, dynamic>>> searchMessages(
      Database db,
      String keyword,
      {int limit = 50}
      ) async {
    try {
      return await db.rawQuery('''
        SELECT * FROM messages_fts 
        WHERE messages_fts MATCH ? 
        ORDER BY rank
        LIMIT ?
      ''', [keyword, limit]);
    } catch (e) {
      print('FTS search error: $e');
      return [];
    }
  }
}