
import 'dart:convert';

import '../../../core/cache/user_cache.dart';
import '../../../core/global.dart';
import '../../../core/sqlite/message_repository.dart';
import '../../../services/group_service.dart';
import 'message.dart';

final GroupApi api = GroupApi();
final int limit = 200;
final bool includeRead = true;

/// 获取当前用户用于拉取离线消息的游标。[userId] 多账号下建议传入，与 switch_user 一致。
/// 优先用 sync_cursor 表（服务端下发的 nextCursor），无记录时兜底用 messages 表推导。
Future<String?> getLastCursorId([int? userId]) async {
  final curUserId = userId ?? await UserCache.getUserId();
  if (curUserId == null) return "0";
  final repo = MessageRepository(Global.db);
  String? cursor = await repo.getStoredSyncCursor(curUserId);
  if (cursor == null || cursor.isEmpty) {
    cursor = await repo.getSyncCursor(curUserId);
  }
  return cursor ?? "0";
}


/// 获取离线、同步消息。[userId] 多账号下建议传入。
Future<void> getOfflineMessageList([int? userId]) async {
  final cursor = await getLastCursorId(userId);

  final response = await api.getOfflineMessageList({"cursor": cursor, "limit": limit, "include_read": includeRead});
  final info = OfflineMessageResp.fromJson(response);

  final messages = info.list.map((m) => m.toPbEvent()).toList();
  await MessageRepository(Global.db).syncOfflineMessages(messages);

  final curUserId = userId ?? await UserCache.getUserId();
  if (curUserId != null && info.nextCursor.isNotEmpty) {
    await MessageRepository(Global.db).setStoredSyncCursor(curUserId, info.nextCursor);
  }

  print("getOfflineMessageList");
  print(jsonEncode(response));
}

/// [userId] 若传入则全程用该用户取/写游标，与 switch_user 一致。
Future<void> syncAllOfflineMessages([int? userId]) async {
  final curUserId = userId ?? await UserCache.getUserId();
  if (curUserId == null) return;

  String cursor = (await getLastCursorId(curUserId)) ?? "0";
  bool hasMore = true;
  int round = 0;
  final repo = MessageRepository(Global.db);

  while (hasMore) {
    round++;
    print("🚀 开始拉取第 $round 批离线消息，cursor=$cursor");

    final response = await api.getOfflineMessageList({
      "cursor": cursor,
      "limit": limit,
      "include_read": includeRead,
    });

    final info = OfflineMessageResp.fromJson(response);

    print("📦 本批数量=${info.list.length}, hasMore=${info.hasMore}, nextCursor=${info.nextCursor}");

    if (info.list.isEmpty) {
      print("⚠️ 本批为空，提前终止同步");
      break;
    }

    final messages = info.list.map((m) => m.toPbEvent()).toList();
    await repo.syncOfflineMessages(messages);

    cursor = info.nextCursor;
    hasMore = info.hasMore;
    if (cursor.isNotEmpty) {
      await repo.setStoredSyncCursor(curUserId, cursor);
    }
  }

  print("✅ 离线消息同步完成");
}


