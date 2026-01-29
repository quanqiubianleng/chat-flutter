// lib/providers/user_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/core/cache/user_cache.dart';

import '../core/global.dart';
import '../core/sqlite/user_repository.dart';
import '../core/sqlite/user_table.dart';
import '../services/user_service.dart';
import '../widgets/user/user.dart';

final userProvider = FutureProvider<int?>((ref) async {
  // 自动加载 UID
  final uid = await UserCache.getUserId();

  if (uid == null || uid <= 0) {
    throw Exception("User not logged in");
  }

  return uid;
});

final myAvatarProvider = FutureProvider<String?>((ref) async {
  return await UserCache.getAvatar();
});

final myNicknameProvider = FutureProvider<String?>((ref) async {
  return await UserCache.getNickname();
});

// 可选：如果需要一个简单的 StateProvider 来控制登录状态
final loginStateProvider = StateProvider<bool>((ref) => false);

// 获取其他用户信息
final userInfoProvider = FutureProvider.family<UserProfile, int>((ref, userId) async {
  final repo = UserRepository(Global.db);

  // 1. 本地缓存
  final local = await repo.getUser(userId);
  if (local != null) return local;

  // 2. 网络拉取
  final api = UserApi();
  final map = await api.getUserOtherInfo({"userId": userId});
  final user = UserProfile.fromMap(map);

  // 3. 回写缓存
  await repo.upsertUser(user);
  return user;
});

