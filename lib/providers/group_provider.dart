import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/cache/user_cache.dart';
import '../core/global.dart';
import '../core/notifications/notifications.dart'; // 注意路径是否正确
import '../core/sqlite/group_mute_repository.dart';
import '../core/sqlite/group_mute_table.dart';

typedef GroupMuteResult = ({bool isMuted, int? muteUntil, bool isAllMute});

// 当前用户 ID（建议改名，避免和别的 userProvider 冲突）
final currentUserIdProvider = FutureProvider<int?>((ref) async {
  return await UserCache.getUserId();
});

// 全员禁言设置（保持 FutureProvider，因为变化频率低，且已有通知机制间接触发刷新）
final groupMuteAllStreamProvider = StreamProvider.family<GroupMuteSetting?, int>(
      (ref, groupId) async* {
    final repo = ref.watch(groupMuteRepoProvider);

    // 初始值
    yield await repo.getMuteAllSetting(groupId);

    // 每次收到这个群的通知，就重新查一次
    await for (final changedId in DbNotification().groupMuteStream) {
      if (changedId == groupId) {
        yield await repo.getMuteAllSetting(groupId);
      }
    }
  },
  // autoDispose: true,  // 可选：长时间不看这个群就自动释放
);

// 个人禁言（同上）
final myGroupMemberMuteProvider = FutureProvider.family<GroupMemberMute?, int>(
      (ref, groupId) async {
    final userId = await ref.watch(currentUserIdProvider.future);
    if (userId == null || userId <= 0) return null;

    final repo = GroupMuteRepository(Global.db);
    return await repo.getMemberMute(groupId, userId);
  },
);

// 推荐：把 repo 也做成 provider，减少重复实例
final groupMuteRepoProvider = Provider<GroupMuteRepository>(
      (ref) => GroupMuteRepository(Global.db),
);

// ─── 核心：实时禁言状态 StreamProvider ───
final groupMuteResultStreamProvider = StreamProvider.family<GroupMuteResult, int>(
      (ref, groupId) async* {
    final repo = ref.watch(groupMuteRepoProvider);

    // 初始值
    yield await _computeCurrentMuteResult(ref, groupId, repo);

    // 监听变化通知（注意类型修正）
    await for (final groupIdFromNotification in DbNotification().groupMuteStream) {
      // 因为你 notifyGroupMuteChanged(int groupID)，所以这里应该是 int
      // 但你的 Stream<void>，所以需要修正 DbNotification（见下方）
      if (groupIdFromNotification == groupId) {
        yield await _computeCurrentMuteResult(ref, groupId, repo);
      }
    }
  },
  // 可选：设置 autoDispose，避免长时间不用的群一直持有 stream
  // 但如果你希望全局缓存禁言状态，也可以去掉
  // autoDispose: true,
);

Future<GroupMuteResult> _computeCurrentMuteResult(
    Ref ref,
    int groupId,
    GroupMuteRepository repo,
    ) async {
  final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

  final muteAll = await ref.watch(groupMuteAllStreamProvider(groupId).future);
  if (muteAll != null && muteAll.isMuteAll && (muteAll.muteAllUntil == null || muteAll.muteAllUntil! > now)) {
    return (isMuted: true, muteUntil: muteAll.muteAllUntil, isAllMute: true);
  }

  final myMute = await ref.watch(myGroupMemberMuteProvider(groupId).future);
  if (myMute != null && (myMute.mutedUntil == null || myMute.mutedUntil! > now)) {
    return (isMuted: true, muteUntil: myMute.mutedUntil, isAllMute: false);
  }

  return (isMuted: false, muteUntil: null, isAllMute: false);
}