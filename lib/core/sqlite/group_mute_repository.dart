import 'package:sqflite/sqflite.dart';
import 'dart:async';

import '../notifications/notifications.dart';
import 'group_mute_table.dart'; // 假设你把表结构和 Model 放在这个文件
// import '../notifications/db_notifications.dart'; // 如果你有类似的通知机制

class GroupMuteRepository {
  final Database db;

  GroupMuteRepository(this.db);

  // ───────────────────────────────────────────────
  // 1. 全员禁言设置（group_mute_setting）
  // ───────────────────────────────────────────────

  /// 插入或更新 全员禁言设置（推荐使用 replace）
  Future<void> upsertMuteAllSetting(GroupMuteSetting setting) async {
    await db.insert(
      'group_mute_setting',
      setting.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    DbNotification().notifyGroupMuteChanged(setting.groupId);
  }

  /// 更新全员禁言状态（常用：开启/关闭/修改到期时间）
  Future<void> updateMuteAll(
      int groupId, {
        bool? isMuteAll,
        int? muteUntil, // seconds since epoch
        String? operatorId,
        String? reason,
      }) async {
    final fields = <String, Object?>{
      'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    if (isMuteAll != null) {
      fields['is_mute_all'] = isMuteAll ? 1 : 0;
    }
    if (muteUntil != null) {
      fields['mute_all_until'] = muteUntil;
    }
    if (operatorId != null) {
      fields['mute_all_operator_id'] = operatorId;
    }
    if (reason != null) {
      fields['mute_all_reason'] = reason;
    }

    if (fields.length <= 1) return; // 只有 updated_at 则无意义

    await db.update(
      'group_mute_setting',
      fields,
      where: 'group_id = ?',
      whereArgs: [groupId],
    );

    DbNotification().notifyGroupMuteChanged(groupId);
  }

  /// 获取某个群的全员禁言设置
  Future<GroupMuteSetting?> getMuteAllSetting(int groupId) async {
    final result = await db.query(
      'group_mute_setting',
      where: 'group_id = ?',
      whereArgs: [groupId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    final savedSetting = GroupMuteSetting.fromMap(result.first);
    return savedSetting;
  }

  /// 清除全员禁言（快捷方法）
  Future<void> clearMuteAll(int groupId) async {
    await db.update(
      'group_mute_setting',
      {
        'is_mute_all': 0,
        'mute_all_until': null,
        'mute_all_operator_id': null,
        'mute_all_reason': null,
        'updated_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      },
      where: 'group_id = ?',
      whereArgs: [groupId],
    );

    // 用不同名字接收查詢結果
    final savedSetting = await getMuteAllSetting(groupId);

    if (savedSetting == null) {
      print('群 ${groupId} 清除全员禁言禁言設定：不存在（已清除或從未設置）');
    } else {
      print('群 ${groupId} 清除全员禁言禁言設定：');
      print('  - is_mute_all     : ${savedSetting.isMuteAll}');
      print('  - mute_all_until  : ${savedSetting.muteAllUntil} '
          '(${savedSetting.muteAllUntil != null ? DateTime.fromMillisecondsSinceEpoch(savedSetting.muteAllUntil! * 1000) : "永久"})');
      print('  - operator_id     : ${savedSetting.operatorId ?? "無"}');
      print('  - reason          : ${savedSetting.reason ?? "無"}');
      print('  - updated_at      : ${savedSetting.updatedAt}');
    }

    DbNotification().notifyGroupMuteChanged(groupId);
  }

  // ───────────────────────────────────────────────
  // 2. 单个成员禁言（group_member_mute）
  // ───────────────────────────────────────────────

  /// 插入或更新 单个成员禁言记录
  Future<void> upsertMemberMute(GroupMemberMute mute) async {
    await db.insert(
      'group_member_mute',
      mute.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    // DbNotification().notifyMemberMuteChanged(mute.groupId, mute.userId);
  }

  /// 为某个成员设置禁言（常用方法）
  Future<void> muteMember(
      int groupId,
      String userId, {
        int? mutedUntil, // seconds since epoch, null=永久
        String? operatorId,
        String? reason,
      }) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final mute = GroupMemberMute(
      groupId: groupId,
      userId: userId,
      mutedUntil: mutedUntil,
      operatorId: operatorId,
      reason: reason,
      createdAt: now,
      updatedAt: now,
    );

    await upsertMemberMute(mute);
  }

  /// 解除某个成员的禁言
  Future<void> unmuteMember(int groupId, int userId) async {
    final rows = await db.delete(
      'group_member_mute',
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
    );

    if (rows > 0) {
      // DbNotification().notifyMemberMuteChanged(groupId, userId);
    }
  }

  /// 获取某个成员在某个群的禁言信息
  Future<GroupMemberMute?> getMemberMute(int groupId, int userId) async {
    final result = await db.query(
      'group_member_mute',
      where: 'group_id = ? AND user_id = ?',
      whereArgs: [groupId, userId],
      limit: 1,
    );

    if (result.isEmpty) return null;
    return GroupMemberMute.fromMap(result.first);
  }

  /// 获取某个群所有被禁言的成员（通常用于同步或初始化）
  Future<List<GroupMemberMute>> getMutedMembersInGroup(int groupId) async {
    final result = await db.query(
      'group_member_mute',
      where: 'group_id = ?',
      whereArgs: [groupId],
    );
    return result.map((e) => GroupMemberMute.fromMap(e)).toList();
  }

  // ───────────────────────────────────────────────
  // 3. 综合判断 - 当前用户是否被禁言（最常用）
  // ───────────────────────────────────────────────

  /// 判断当前用户在某个群是否被禁言（包含全员禁言和个人禁言）
  Future<bool> isUserMutedInGroup(int groupId, int userId) async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    // 1. 检查全员禁言
    final muteAll = await getMuteAllSetting(groupId);
    if (muteAll != null &&
        muteAll.isMuteAll &&
        (muteAll.muteAllUntil == null || muteAll.muteAllUntil! > now)) {
      return true;
    }

    // 2. 检查个人禁言
    final memberMute = await getMemberMute(groupId, userId);
    if (memberMute != null &&
        (memberMute.mutedUntil == null || memberMute.mutedUntil! > now)) {
      return true;
    }

    return false;
  }

  // ───────────────────────────────────────────────
  // 4. 定时清理过期禁言（建议在 app 启动或进入群聊时调用）
  // ───────────────────────────────────────────────

  /// 清理所有已过期的个人禁言记录（可定期调用）
  Future<int> cleanExpiredMemberMutes() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final count = await db.delete(
      'group_member_mute',
      where: 'muted_until IS NOT NULL AND muted_until < ?',
      whereArgs: [now],
    );

    if (count > 0) {
      // 可以选择广播通知，但通常不必要，因为客户端会懒加载判断
      // DbNotification().notifyMemberMuteCleaned();
    }

    return count;
  }

  /// 清理所有已过期的全员禁言（通常数量少，可一起清理）
  Future<int> cleanExpiredMuteAll() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;

    final count = await db.update(
      'group_mute_setting',
      {
        'is_mute_all': 0,
        'mute_all_until': null,
        'mute_all_operator_id': null,
        'mute_all_reason': null,
        'updated_at': now,
      },
      where: 'is_mute_all = 1 AND mute_all_until IS NOT NULL AND mute_all_until < ?',
      whereArgs: [now],
    );

    return count;
  }

  /// 推荐：应用启动或进入聊天列表时调用一次
  Future<void> cleanAllExpiredMutes() async {
    await cleanExpiredMemberMutes();
    await cleanExpiredMuteAll();
  }
}