import 'package:sqflite/sqflite.dart';
import '../cache/user_cache.dart';
import '../notifications/notifications.dart';
import '../utils/conversation.dart';
import 'user_table.dart';
import 'package:education/core/sqlite/message_repository.dart'; // 假设你的 repo

class UserRepository {
  final Database db;

  UserRepository(this.db) {
    print('🧪 UserRepository db path = ${db.path}');
  }

  /// 新增 / 覆盖用户资料
  Future<void> upsertUser(UserProfile user) async {
    await db.insert(
      'user',
      user.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    DbNotification().notifyUserChanged(user.userId);
  }

  /// 删除用户缓存
  Future<int> deleteUser(int userId) async {
    final rows = await db.delete(
      'user',
      where: 'userId = ?',
      whereArgs: [userId],
    );
    DbNotification().notifyUserChanged(userId);
    return rows;
  }

  /// 查询单个用户
  Future<UserProfile?> getUser(int userId) async {
    final result = await db.query(
      'user',
      where: 'userId = ? AND deleted = 0',
      whereArgs: [userId],
      limit: 1,
    );
    if (result.isEmpty) return null;
    return UserProfile.fromMap(result.first);
  }

  /// 批量查询用户
  Future<List<UserProfile>> getUsers(List<int> userIds) async {
    if (userIds.isEmpty) return [];

    final placeholders = List.filled(userIds.length, '?').join(',');
    final result = await db.rawQuery(
      'SELECT * FROM user WHERE userId IN ($placeholders) AND deleted = 0',
      userIds,
    );

    return result.map((e) => UserProfile.fromMap(e)).toList();
  }

  // =========================
  // 单字段更新（高频使用）
  // =========================

  /// 更新昵称
  Future<void> updateUsername(int userId, String username, bool isGroup) async {
    await _updateFields(userId, {
      'username': username,
    });
    // 同步更新会话表（单聊会话的显示名）
    final uidA = await UserCache.getUserId();
    final conv = generateTempConversationId(userIdA: uidA!, userIdB: userId, isGroup: isGroup);
    await MessageRepository(db).updateConvTitle(conv, username);
  }

  /// 更新头像
  Future<void> updateAvatar(int userId, String avatarUrl, bool isGroup) async {
    await _updateFields(userId, {
      'avatar_url': avatarUrl,
    });
    // 同步更新会话表（单聊会话的显示名）
    final uidA = await UserCache.getUserId();
    final conv = generateTempConversationId(userIdA: uidA!, userIdB: userId, isGroup: isGroup);
    await MessageRepository(db).updateConvAvatar(conv, avatarUrl);
  }

  /// 更新备注
  Future<void> updateRemark(int userId, String remark) async {
    await _updateFields(userId, {
      'remark': remark,
    });
  }

  /// 更新 version（服务端同步时使用）
  Future<void> updateVersion(int userId, int version) async {
    await _updateFields(userId, {
      'version': version,
    });
  }

  /// 软删除（推荐）
  Future<void> softDelete(int userId) async {
    await _updateFields(userId, {
      'deleted': 1,
    });
  }

  // =========================
  // 内部统一更新方法
  // =========================

  Future<void> _updateFields(int userId, Map<String, Object?> fields) async {
    fields['updated_at'] = DateTime.now().millisecondsSinceEpoch;

    await db.update(
      'user',
      fields,
      where: 'userId = ?',
      whereArgs: [userId],
    );

    DbNotification().notifyUserChanged(userId);
  }
}
