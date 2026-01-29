import 'package:sqflite/sqflite.dart';

Future<void> createGroupMuteTables(Database db) async {
  // 1. 群组禁言设置表（全员禁言 + 群级配置）
  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_mute_setting (
      group_id INTEGER PRIMARY KEY,              -- 群ID（建议用 TEXT，支持各种格式的ID）
      is_mute_all INTEGER NOT NULL DEFAULT 0, -- 是否全员禁言 1=是 0=否
      mute_all_until INTEGER,                 -- 全员禁言结束时间（Unix timestamp 秒），null=永久
      mute_all_operator_id TEXT,              -- 操作者ID（谁设置的全员禁言）
      mute_all_reason TEXT,                   -- 禁言原因（可选）
      version INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER NOT NULL DEFAULT 0,
      extra TEXT                              -- 扩展字段（JSON字符串）
    );
  ''');

  // 2. 单个成员禁言记录表
  await db.execute('''
    CREATE TABLE IF NOT EXISTS group_member_mute (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      group_id INTEGER NOT NULL,
      user_id TEXT NOT NULL,
      muted_until INTEGER,                    -- 禁言结束时间（秒），null=永久
      operator_id TEXT,                       -- 操作者ID
      reason TEXT,                            -- 禁言原因（可选）
      created_at INTEGER NOT NULL DEFAULT (CAST(strftime('%s', 'now') AS INTEGER)),
      updated_at INTEGER NOT NULL DEFAULT 0,
      version INTEGER NOT NULL DEFAULT 1,
      UNIQUE(group_id, user_id)               -- 同一个群+用户只有一条记录
    );
  ''');

  // 索引（加速查询）
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_member_mute_group_user 
    ON group_member_mute (group_id, user_id);
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_member_mute_until 
    ON group_member_mute (muted_until);
  ''');
}

class GroupMuteSetting {
  final int groupId;
  final bool isMuteAll;
  final int? muteAllUntil;       // Unix timestamp seconds
  final String? operatorId;
  final String? reason;
  final int version;
  final int updatedAt;
  final String? extra;

  GroupMuteSetting({
    required this.groupId,
    this.isMuteAll = false,
    this.muteAllUntil,
    this.operatorId,
    this.reason,
    this.version = 1,
    required this.updatedAt,
    this.extra,
  });

  factory GroupMuteSetting.fromMap(Map<String, dynamic> map) {
    return GroupMuteSetting(
      groupId: map['group_id'] as int,
      isMuteAll: (map['is_mute_all'] as int?) == 1,
      muteAllUntil: map['mute_all_until'] as int?,
      operatorId: map['mute_all_operator_id'] as String?,
      reason: map['mute_all_reason'] as String?,
      version: map['version'] as int? ?? 1,
      updatedAt: map['updated_at'] as int? ?? 0,
      extra: map['extra'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'group_id': groupId,
      'is_mute_all': isMuteAll ? 1 : 0,
      'mute_all_until': muteAllUntil,
      'mute_all_operator_id': operatorId,
      'mute_all_reason': reason,
      'version': version,
      'updated_at': updatedAt,
      'extra': extra,
    };
  }

  bool get isMuteAllActive =>
      isMuteAll && (muteAllUntil == null || muteAllUntil! > DateTime.now().millisecondsSinceEpoch ~/ 1000);
}

class GroupMemberMute {
  final int? id;
  final int groupId;
  final String userId;
  final int? mutedUntil;     // Unix timestamp seconds
  final String? operatorId;
  final String? reason;
  final int createdAt;
  final int updatedAt;
  final int version;

  GroupMemberMute({
    this.id,
    required this.groupId,
    required this.userId,
    this.mutedUntil,
    this.operatorId,
    this.reason,
    required this.createdAt,
    required this.updatedAt,
    this.version = 1,
  });

  factory GroupMemberMute.fromMap(Map<String, dynamic> map) {
    return GroupMemberMute(
      id: map['id'] as int?,
      groupId: map['group_id'] as int,
      userId: map['user_id'] as String,
      mutedUntil: map['muted_until'] as int?,
      operatorId: map['operator_id'] as String?,
      reason: map['reason'] as String?,
      createdAt: map['created_at'] as int,
      updatedAt: map['updated_at'] as int,
      version: map['version'] as int? ?? 1,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'group_id': groupId,
      'user_id': userId,
      'muted_until': mutedUntil,
      'operator_id': operatorId,
      'reason': reason,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'version': version,
    };
  }

  bool get isMutedActive =>
      mutedUntil == null || mutedUntil! > DateTime.now().millisecondsSinceEpoch ~/ 1000;
}