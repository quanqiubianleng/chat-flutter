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
  // 根据你的实际接口返回字段继续添加...

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
  });

  // 从后端返回的 Map 转为 Group 对象
  factory GroupInfo.fromJson(Map<String, dynamic> json) {
    return GroupInfo(
      groupId: json['group_id'] as int,
      ownerUserId: json['owner_user_id'] as int,
      Name: (json['name'] ?? '') as String,
      Avatar: (json['avatar'] ?? '') as String,
      description: (json['description'] ?? '') as String,
      notice: (json['notice'] ?? '') as String,
      type: (json['type'] ?? '') as int,
      joinMode: (json['join_mode'] ?? '') as int,
      maxMembers: (json['max_members'] ?? '') as int,
      speakFrequencyLimit: (json['speak_frequency_limit'] ?? '') as int,
      restrictAddFriend: (json['restrict_add_friend'] ?? '') as int,
      status: (json['status'] ?? '') as int,
      isMute: (json['is_mute'] ?? '') as int,
      showNewMemberTip: (json['show_new_member_tip'] ?? '') as int,
      createdAt: (json['created_at'] ?? '') as String,
      updatedAt: (json['updated_at'] ?? '') as String,
      mutedUntil: (json['muted_until'] ?? '') as int,
      role: (json['role'] ?? '') as int,
    );
  }
}