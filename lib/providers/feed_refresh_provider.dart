import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 动态列表刷新触发：发布/编辑完成后调用触发刷新
final feedRefreshTriggerProvider = StateProvider<int>((ref) => 0);
