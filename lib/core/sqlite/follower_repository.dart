import 'package:sqflite/sqflite.dart';
import 'package:education/core/sqlite/follower_table.dart';

class FollowerRepository {
  final Database db;

  FollowerRepository(this.db);

  Future<void> follow(int fromUserId, int toUserId, {String? remark}) async {
    await db.insert(
      'follower',
      {
        'from_user_id': fromUserId,
        'to_user_id': toUserId,
        'remark': remark,
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
  }

  Future<int> unfollow(int fromUserId, int toUserId) async {
    return await db.delete(
      'follower',
      where: 'from_user_id = ? AND to_user_id = ?',
      whereArgs: [fromUserId, toUserId],
    );
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

  /// 查看 follower 表中所有数据（调试用）
  Future<List<Map<String, dynamic>>> getAllFollowers() async {
    final result = await db.query(
      'follower',
      orderBy: 'created_at DESC', // 可选：按创建时间倒序
    );
    return result;
  }
}
