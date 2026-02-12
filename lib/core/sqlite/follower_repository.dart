import 'package:sqflite/sqflite.dart';
import 'package:education/core/sqlite/follower_table.dart';

import '../notifications/notifications.dart';
import '../utils/logger.dart';

class FollowerRepository {
  final Database db;

  FollowerRepository(this.db) {
    AppLogger.d('🧪 FollowerRepository db path = ${db.path}');
  }

  Future<void> follow(int fromUserId, int toUserId, {String? remark, String? name, String? avatar, String? address}) async {
    final resp =  await db.insert(
      'follower',
      {
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'remark': remark,
        'name': name,
        'avatar_url': avatar,
        'address': address,
        'is_read': 0,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    DbNotification().notifyFollowerChanged();
  }

  Future<int> unfollow(int fromUserId, int toUserId) async {
    final resp =  await db.delete(
      'follower',
      where: 'from_user_id = ? AND to_user_id = ?',
      whereArgs: [fromUserId, toUserId],
    );
    DbNotification().notifyFollowerChanged();
    return resp;
  }

  Future<bool> isFollowing(int fromUserId, int toUserId) async {
    final result = await db.query(
      'follower',
      where: 'from_user_id = ? AND to_user_id = ?',
      whereArgs: [fromUserId, toUserId],
      limit: 1,
    );
    return result.isNotEmpty;
  }

  Future<bool> isFriend(int userA, int userB) async {
    final aFollowB = await isFollowing(userA, userB);
    if (!aFollowB) return false;
    final bFollowA = await isFollowing(userB, userA);
    return bFollowA;
  }

  /// 获取【我的好友列表】—— 互关的用户
  Future<List<Follower>> getMyFriends(int myUserId) async {
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
    SELECT 
      f2.from_user_id   AS user_id,          -- 好友的 ID
      f2.name           AS name,             -- 直接从 follower 表取冗余的昵称
      f2.avatar_url     AS avatar_url,       -- 直接取冗余的头像
      f2.remark         AS remark,
      f2.created_at     AS follow_time
    FROM follower f1
    JOIN follower f2 
      ON f1.to_user_id = f2.from_user_id   -- 我关注的 → 对方 ID == 对方关注的 → 我 ID
     AND f1.from_user_id = ?              -- 我关注了对方
    WHERE f2.to_user_id = ?               -- 对方关注了我
    ORDER BY f2.created_at DESC
  ''', [myUserId, myUserId]);

    return maps.map((map) => Follower(
      fromUserId: myUserId,                 // 当前用户（我）
      toUserId: map['user_id'] as int,       // 好友 ID
      name: map['name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      remark: map['remark'] as String?,
      address: map['address'] as String?,
      createdAt: map['follow_time'] as int,
    )).toList();
  }

  /// 可选：获取【我关注的人】（单向关注）
  Future<List<Follower>> getMyFollowing(int myUserId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'follower',
      where: 'from_user_id = ?',
      whereArgs: [myUserId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Follower.fromMap(m)).toList();
  }

  /// 可选：获取【关注我的人】（粉丝）
  Future<List<Follower>> getMyFollowers(int myUserId) async {
    final List<Map<String, dynamic>> maps = await db.query(
      'follower',
      where: 'to_user_id = ?',
      whereArgs: [myUserId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Follower.fromMap(m)).toList();
  }

  /// 获取未读关注数（有人新关注我，但还没点开看过）
  Future<int> getUnreadFollowCount(int myUserId) async {
    final result = await db.rawQuery('''
    SELECT COUNT(*) as count 
    FROM follower 
    WHERE to_user_id = ? AND (is_read = 0 OR is_read IS NULL)
  ''', [myUserId]);

    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// 获取「关注我的」且未读的列表（新增关注页与角标统一数据源）
  Future<List<Follower>> getUnreadFollowers(int myUserId) async {
    final maps = await db.query(
      'follower',
      where: 'to_user_id = ? AND (is_read = 0 OR is_read IS NULL)',
      whereArgs: [myUserId],
      orderBy: 'created_at DESC',
    );
    return maps.map((m) => Follower.fromMap(m)).toList();
  }

  /// 用户打开朋友页面时，标记所有关注为已读（清角标）
  Future<void> markAllFollowAsRead(int myUserId) async {
    await db.update(
      'follower',
      {'is_read': 1},
      where: 'to_user_id = ? AND is_read = 0',
      whereArgs: [myUserId],
    );
    DbNotification().notifyFollowerChanged();
  }

  /// 查看 follower 表中所有数据（调试用）
  Future<List<Map<String, dynamic>>> getAllFollowers() async {
    final result = await db.query(
      'follower',
      orderBy: 'created_at DESC', // 可选：按创建时间倒序
    );
    return result;
  }

  /// 多账号：用服务端下发的关注数据替换「当前用户」相关行。
  /// 同步时保留本地已读状态：若某条「关注我的」本地已是已读，替换后仍为已读，避免切 Tab 后角标复现。
  Future<void> replaceFollowDataForUser(int myUserId, {required List<Follower> following, required List<Follower> followers,}) async {
    final alreadyReadFromIds = <int>{};
    final localRead = await db.query(
      'follower',
      columns: ['from_user_id'],
      where: 'to_user_id = ? AND is_read = 1',
      whereArgs: [myUserId],
    );
    for (final row in localRead) {
      final id = row['from_user_id'];
      if (id != null) alreadyReadFromIds.add(id is int ? id : (id as num).toInt());
    }

    await db.delete(
      'follower',
      where: 'from_user_id = ? OR to_user_id = ?',
      whereArgs: [myUserId, myUserId],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final f in following) {
      await db.insert(
        'follower',
        {
          'from_user_id': f.fromUserId,
          'to_user_id': f.toUserId,
          'name': f.name,
          'avatar_url': f.avatarUrl,
          'remark': f.remark,
          'address': f.address,
          'is_read': 0,
          'created_at': f.createdAt,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    for (final f in followers) {
      final keepRead = alreadyReadFromIds.contains(f.fromUserId);
      await db.insert(
        'follower',
        {
          'from_user_id': f.fromUserId,
          'to_user_id': f.toUserId,
          'name': f.name,
          'avatar_url': f.avatarUrl,
          'remark': f.remark,
          'address': f.address,
          'is_read': keepRead ? 1 : (f.isRead == 1 ? 1 : 0),
          'created_at': f.createdAt,
          'updated_at': now,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    DbNotification().notifyFollowerChanged();
  }
}
