import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/follower_repository.dart';
import 'package:education/core/sqlite/follower_table.dart';
import 'package:education/core/utils/logger.dart';
import 'package:education/services/user_service.dart';

final UserApi api = UserApi();

/// 同步拉取关注数据并落库。[userId] 多账号下建议传入，与 switch_user 一致。
/// 使用 getFollowerData 一次请求拿到「我关注的」+「关注我的」，再通过 replaceFollowDataForUser 替换当前用户相关本地数据。
Future<void> getOfflineFollowerList([int? userId]) async {
  final curUserId = userId ?? await UserCache.getUserId();
  if (curUserId == null || curUserId <= 0) {
    AppLogger.w('getOfflineFollowerList: 无当前用户，跳过');
    return;
  }

  try {
    final resp = await api.getFollowerData({});
    final rawFollower = resp['follower'] as List<dynamic>? ?? [];
    final rawFollowers = resp['followers'] as List<dynamic>? ?? [];
    final following = rawFollower
        .map((e) => _followerInfoToFollower(e as Map<String, dynamic>))
        .toList();
    final followers = rawFollowers
        .map((e) => _followerInfoToFollower(e as Map<String, dynamic>))
        .toList();

    await FollowerRepository(Global.db).replaceFollowDataForUser(
      curUserId,
      following: following,
      followers: followers,
    );
    AppLogger.d('✅ 关注数据同步完成(getFollowerData): 我关注=${following.length}, 关注我=${followers.length}');
  } catch (e, st) {
    AppLogger.e('getOfflineFollowerList 失败', e, st);
    rethrow;
  }
}

/// 将 getFollowerData 返回的 FollowerInfo 转成本地 Follower（支持 camelCase / snake_case）。
Follower _followerInfoToFollower(Map<String, dynamic> item) {
  int _int(dynamic v) => (v is num) ? v.toInt() : 0;
  final fromUserId = _int(item['fromUserId'] ?? item['from_user_id']);
  final toUserId = _int(item['toUserId'] ?? item['to_user_id']);
  final name = item['name'] as String?;
  final avatarUrl = item['avatarUrl'] as String? ?? item['avatar_url'] as String?;
  final remark = item['remark'] as String?;
  final address = item['address'] as String?;
  final isRead = _int(item['isRead'] ?? item['is_read']);
  final createdAt = _int(item['createdAt'] ?? item['created_at']);
  final createdAtMs = createdAt > 0 ? createdAt : DateTime.now().millisecondsSinceEpoch;

  return Follower(
    fromUserId: fromUserId,
    toUserId: toUserId,
    name: name,
    avatarUrl: avatarUrl,
    remark: remark,
    address: address,
    isRead: isRead,
    createdAt: createdAtMs,
  );
}
