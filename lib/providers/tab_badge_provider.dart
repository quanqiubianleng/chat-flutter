// lib/providers/tab_badge_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/core/sqlite/message_repository.dart';
import 'package:education/core/notifications/notifications.dart';
import 'package:education/providers/user_provider.dart';
import 'package:rxdart/rxdart.dart';

import 'chat_providers.dart';
import 'follower_provider.dart'; // 你的 userProvider，返回 AsyncValue<int?> 或 int?

/// 实时计算聊天 Tab 的总未读消息数
/// 自动响应：用户登录/登出、收到新消息、阅读消息、清零未读 等所有场景
final chatTabUnreadStreamProvider = StreamProvider<int>((ref) {
  // 监听当前用户 ID 的变化（登录、登出、切换账号都会触发）
  final userAsync = ref.watch(userProvider);

  return userAsync.when(
    // 加载中或出错 → 显示 0
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),

    // 已登录用户
    data: (userId) {
      if (userId == null) {
        return Stream.value(0); // 未登录
      }

      final repo = ref.read(messageRepositoryProvider);

      // 创建一个合并流：初始值 + 数据库变化通知
      return DbNotification()
          .conversationStream
          .startWith(null) // 立即触发一次初始加载
          .asyncMap<int>((_) async {
        final conversations = await repo.getConversations(userId);
        return conversations.fold<int>(
          0,
              (sum, conv) => sum + (conv.unreadCount ?? 0),
        );
      });
    },
  );
});

// 好友、关注、取消关注监听
final friendTabUnreadProvider = StreamProvider<int>((ref) {
  // 持续监听 userProvider 的完整 AsyncValue
  final userAsync = ref.watch(userProvider);

  return userAsync.when(
    loading: () => Stream.value(0),
    error: (_, __) => Stream.value(0),
    data: (userId) {
      if (userId == null) {
        return Stream.value(0); // 未登录
      }

      final repo = ref.read(followerRepositoryProvider);

      return DbNotification()
          .followerStream
          .startWith(null) // 触发初始加载
          .asyncMap((_) => repo.getUnreadFollowCount(userId)); // 避免相同值重复触发
    },
  );
});

/// 最终暴露给 UI 使用的角标 Map
final tabBadgeProvider = Provider<Map<String, int>>((ref) {
  final chatUnread = ref.watch(chatTabUnreadStreamProvider);
  final friendUnread = ref.watch(friendTabUnreadProvider); // 加回来！

  final chatCount = chatUnread.asData?.value ??
      chatUnread.valueOrNull ??
      0;

  final friendCount = friendUnread.asData?.value ??
      friendUnread.valueOrNull ??
      0;

  return {
    'chat': chatCount,
    'friend': friendCount,
    'discover': 0,
    'mine': 0,
  };
});