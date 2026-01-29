
import 'dart:convert';

import '../../../core/cache/user_cache.dart';
import '../../../core/global.dart';
import '../../../core/sqlite/message_repository.dart';
import '../../../services/group_service.dart';
import 'message.dart';

final GroupApi api = GroupApi();
final int limit = 200;
final bool includeRead = true;

/// 获取最新消息游标
Future<String?> getLastCursorId() async {
  final curUserId = await UserCache.getUserId();
  String? cursor =  await MessageRepository(Global.db).getSyncCursor(curUserId!);
  cursor ??= "0";
  return cursor;
}


/// 获取离线、同步消息
Future<void> getOfflineMessageList() async {
  final cursor = await getLastCursorId();

  final response = await api.getOfflineMessageList({"cursor": cursor, "limit": limit, "include_read": includeRead});
  final info = OfflineMessageResp.fromJson(response);

  // 将消息转换成 pb.Event
  final messages = info.list.map((m) => m.toPbEvent()).toList();

  // 批量同步到 SQLite
  await MessageRepository(Global.db).syncOfflineMessages(messages);

  print("getOfflineMessageList");
  print(jsonEncode(response));

}

Future<void> syncAllOfflineMessages() async {
  String cursor = (await getLastCursorId()) ?? "0";

  bool hasMore = true;
  int round = 0;

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
      // 防御：避免死循环
      print("⚠️ 本批为空，提前终止同步");
      break;
    }

    // ✅ 批量落库 + 更新会话
    // 将消息转换成 pb.Event
    final messages = info.list.map((m) => m.toPbEvent()).toList();
    await MessageRepository(Global.db).syncOfflineMessages(messages);

    // ✅ 更新 cursor
    cursor = info.nextCursor;
    hasMore = info.hasMore;
  }

  print("✅ 离线消息同步完成");
}


