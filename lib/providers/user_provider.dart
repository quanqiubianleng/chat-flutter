// lib/providers/user_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/core/cache/user_cache.dart';

final userProvider = FutureProvider<int?>((ref) async {
  // 自动加载 UID
  final uid = await UserCache.getUserId();
  return uid;
});

// 可选：如果需要一个简单的 StateProvider 来控制登录状态
final loginStateProvider = StateProvider<bool>((ref) => false);