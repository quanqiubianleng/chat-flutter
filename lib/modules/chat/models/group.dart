// models/group.dart
class GroupInfo {
  final int groupId;              // 群组ID
  final int ownerUserId;     // 群主用户ID（创建者）
  final String Name;     // 群名称
  final String Avatar;       // 群头像URL
  final String description;       // 群简介
  final String notice;       // 公告
  final int type;       // 群类型：0=普通小群(≤3000人), 1=Club大群(无限制)
  final int joinMode;       // 入群方式：0=公开(任何人可加), 1=需审核, 2=持仓门控(Token/NFT), 3=邀请制
  final int maxMembers;       // 最大成员数（小群默认3000，Club可设更大或NULL表示无限制）
  final int speakFrequencyLimit;       // 发言频率限制（秒内最多发言次数，0=无限制）
  final int restrictAddFriend;       // 是否禁止群成员互加好友：0=允许, 1=禁止
  final int status;       // 群状态：0=正常, 1=已解散, 2=已冻结
  final int isMute;       // 是否禁言：0=允许, 1=禁止
  final int showNewMemberTip;       // 新成员加入提示：0=允许, 1=关闭
  final String createdAt;       // 创建时间
  final String updatedAt;       // 更新时间
  final int mutedUntil;       // 禁言截止时间
  final int role;       // 角色：0=普通成员, 1=管理员(MOD), 2=群主(冗余，便于查询)
  /// 当前成员数（资料页）
  final int memberCount;
  /// 持仓门控规则（与网关 gate_rules 一致）
  final List<Map<String, dynamic>> gateRules;

  GroupInfo({
    required this.groupId,
    required this.ownerUserId,
    this.Name = '',
    this.Avatar = '',
    this.description = '',
    this.notice = '',
    this.type = 0,
    this.joinMode = 0,
    this.maxMembers = 0,
    this.speakFrequencyLimit = 0,
    this.restrictAddFriend = 0,
    this.status = 0,
    this.isMute = 0,
    this.showNewMemberTip = 0,
    this.createdAt = '',
    this.updatedAt = '',
    this.mutedUntil = 0,
    this.role = 0,
    this.memberCount = 0,
    this.gateRules = const [],
  });

  static int _i(dynamic v, [int d = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? d;
  }

  // 从后端返回的 Map 转为 Group 对象
  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    final rulesRaw = json['gate_rules'] as List<dynamic>? ?? [];
    final rules = rulesRaw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    return GroupInfo(
      groupId: _i(json['group_id']),
      ownerUserId: _i(json['owner_user_id']),
      Name: (json['name'] ?? '') as String,
      Avatar: (json['avatar'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      notice: (json['notice'] ?? '') as String,
      type: _i(json['type']),
      joinMode: _i(json['join_mode']),
      maxMembers: _i(json['max_members']),
      speakFrequencyLimit: _i(json['speak_frequency_limit']),
      restrictAddFriend: _i(json['restrict_add_friend']),
      status: _i(json['status']),
      isMute: _i(json['is_mute']),
      showNewMemberTip: _i(json['show_new_member_tip']),
      createdAt: (json['created_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
      mutedUntil: _i(json['muted_until']),
      role: _i(json['role']),
      memberCount: _i(json['member_count']),
      gateRules: rules,
    );
  }
}