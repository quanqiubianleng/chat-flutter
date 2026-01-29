// lib/providers/follower_provider.dart

import 'package:education/providers/user_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/core/sqlite/follower_repository.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/follower_table.dart';
import 'package:rxdart/rxdart.dart';

import 'package:education/core/notifications/notifications.dart'; // 你的 Follower 模型

/// 提供 FollowerRepository 实例（单例）
final followerRepositoryProvider = Provider<FollowerRepository>((ref) {
  final db = Global.db;
  if (db == null) {
    throw Exception('Database not initialized. Call Global.initDb() first.');
  }
  return FollowerRepository(db);
});

/// 实时监听当前用户的“我的朋友”列表（互关或单向关注，根据你的业务定义）
final followerListProvider = StreamProvider<List<Follower>>((ref) {
  final userIdAsync = ref.watch(userProvider); // 你的当前用户 ID provider
  return userIdAsync.when(
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
    data: (userId) {
      if (userId == null) return Stream.value([]);

      final repo = ref.read(followerRepositoryProvider);

      // 监听 follower 表变化 + 初始加载
      return DbNotification()
          .followerStream
          .startWith(null) // 立即加载一次
          .asyncMap<List<Follower>>( (_) async {  // ← 关键：加泛型 + async
            return await repo.getMyFriends(userId);
          });
    },
  );
});


/// 实时监听当前用户的“我关注”（互关或单向关注，根据你的业务定义）
final followerMyProvider = StreamProvider<List<Follower>>((ref) {
  final userIdAsync = ref.watch(userProvider); // 你的当前用户 ID provider
  return userIdAsync.when(
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
    data: (userId) {
      if (userId == null) return Stream.value([]);

      final repo = ref.read(followerRepositoryProvider);

      // 监听 follower 表变化 + 初始加载
      return DbNotification()
          .followerStream
          .startWith(null) // 立即加载一次
          .asyncMap( (_) async {  // ← 关键：加泛型 + async
        return await repo.getMyFollowing(userId);
      });
    },
  );
});

/// 实时监听当前用户的“关注我”（互关或单向关注，根据你的业务定义）
final followerMeProvider = StreamProvider<List<Follower>>((ref) {
  final userIdAsync = ref.watch(userProvider); // 你的当前用户 ID provider
  return userIdAsync.when(
    loading: () => Stream.value([]),
    error: (_, __) => Stream.value([]),
    data: (userId) {
      if (userId == null) return Stream.value([]);

      final repo = ref.read(followerRepositoryProvider);

      // 监听 follower 表变化 + 初始加载
      return DbNotification()
          .followerStream
          .startWith(null) // 立即加载一次
          .asyncMap( (_) async {  // ← 关键：加泛型 + async
        return await repo.getMyFollowers(userId);
      });
    },
  );
});


// 我关注
final iFollowCountsProvider = Provider<int>((ref) {
  final asyncList = ref.watch(followerMyProvider);
  return asyncList.maybeWhen(
    data: (list) => list.length,
    orElse: () => 0,
  );
});
// 关注我
final followMeCountsProvider = Provider<int>((ref) {
  final asyncList = ref.watch(followerMeProvider);
  return asyncList.maybeWhen(
    data: (list) => list.length,
    orElse: () => 0,
  );
});