

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixnum/fixnum.dart';
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'package:education/core/sqlite/message_repository.dart';
import 'package:education/core/global.dart';
import 'package:education/core/notifications/notifications.dart';
import 'package:intl/intl.dart';
import 'package:rxdart/rxdart.dart';
import '../core/sqlite/database_helper.dart';
import '../core/utils/date_utils.dart';           // ChatDateUtils
import '../modules/chat/models/chat_display_item.dart';
import 'package:intl/date_symbol_data_local.dart';

// ────────────────────────────────────────────────
// 基础 Repository Provider
// ────────────────────────────────────────────────
final messageRepositoryProvider = Provider<MessageRepository>((ref) {
  final db = Global.db;
  if (db == null) throw Exception('Database not initialized');
  return MessageRepository(db);
});

// ────────────────────────────────────────────────
// 会话列表（多会话页面用）
// ────────────────────────────────────────────────
final conversationListProvider = StreamProvider.family<List<Conversation>, int>(
      (ref, userId) {
    final repo = ref.watch(messageRepositoryProvider);
    return DbNotification()
        .conversationStream
        .startWith(null)
        .switchMap((_) => Stream.fromFuture(repo.getConversations(userId)));
  },
);

// ────────────────────────────────────────────────
// 单个会话的消息列表（AsyncValue 版）
// ────────────────────────────────────────────────
final messagesProvider = StreamProvider.family<List<pb.Event>, String>(
      (ref, conversationId) {
    final repo = ref.watch(messageRepositoryProvider);
    return DbNotification()
        .messageStream
        .where((id) => id == conversationId)
        .startWith(conversationId)
        .switchMap((_) => Stream.fromFuture(
      repo.getMessagesForConversation(conversationId, limit: 500),
    ));
  },
);

// ────────────────────────────────────────────────
// 分组后的显示项（最重要的 provider）
// ────────────────────────────────────────────────
final displayItemsProvider = Provider.family<List<ChatDisplayItem>, String>(
      (ref, conversationId) {
    // 1. 拿到 AsyncValue
    final messagesAsync = ref.watch(messagesProvider(conversationId));

    // 2. 处理 loading / error / data 三种状态
    return messagesAsync.when(
      data: (messages) => buildDisplayItems(messages),
      loading: () => const <ChatDisplayItem>[], // 或返回一个 loading item
      error: (_, __) => const <ChatDisplayItem>[], // 或返回错误提示 item
    );
  },
);

// ────────────────────────────────────────────────
// 分组逻辑（纯函数，可测试）
// 重要：确保 messages 是按时间升序（旧 → 新）
// 如果你的数据库返回的是倒序（新 → 旧），需要在这一步 reversed
// ────────────────────────────────────────────────
List<ChatDisplayItem> buildDisplayItems(List<pb.Event> messages) {
  if (messages.isEmpty) return [];

  // 如果数据库返回的是【最新 → 旧】（DESC），在这里反转成【旧 → 新】
  // final sortedMessages = messages.reversed.toList();
  // 下面用 sortedMessages 替换 messages
  // 这里假设你已经改成 ASC 升序（旧 → 新），所以直接用 messages

  final List<ChatDisplayItem> items = [];

  // 使用韩语 locale 的日期格式（yyyy-MM-dd）
  final dateFormat = DateFormat('yyyy-MM-dd', 'zh_CN');

  // 用于比较是否同一天的“规范化”日期（只保留年月日）
  DateTime? lastNormalizedDate;

  DateTime? lastTime;

  for (final msg in messages) {
    final msgTime = _parseTimestamp(msg.timestamp).toLocal(); // 强制转本地时区（韩国时间）
    final msgDateKey = dateFormat.format(msgTime);            // '2026-01-22'

    // 日期分隔条（只在日期变化时添加）
    if (lastNormalizedDate == null ||
        dateFormat.format(lastNormalizedDate) != msgDateKey) {

      // 使用你已有的 ChatDateUtils 来生成显示文本（今天、昨天、星期几等）
      final header = ChatDateUtils.formatDateHeader(msgTime);
      items.add(DateSeparator(header));

      lastNormalizedDate = msgTime;
      lastTime = null;
    }

    // 是否显示具体时间（5分钟规则）
    final showTime = ChatDateUtils.shouldShowTime(msgTime, lastTime);

    items.add(MessageBubbleItem(
      msg,
      showTime: showTime,
    ));

    lastTime = msgTime;
  }

  return items;
}

DateTime _parseTimestamp(Int64 ts) {
  final value = ts.toInt();
  final ms = value * (value < 10000000000 ? 1000 : 1);
  return DateTime.fromMillisecondsSinceEpoch(ms);
}