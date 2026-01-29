class GroupMember {
  final int userId;              // 好友用户ID
  final String username;     // 用户名
  final String avatarUrl;     // 头像URL（如果有）
  final String walletAddress;       // 地址
  final int role;
  // 根据你的实际接口返回字段继续添加...

  GroupMember({
    required this.userId,
    required this.username,
    this.avatarUrl = '',
    this.walletAddress = '',
    this.role = 0,
  });

  // 从后端返回的 Map 转为 Friend 对象
  factory GroupMember.fromJson(Map<String, dynamic> json) {
    return GroupMember(
      userId: json['userId'] as int,
      username: json['username'] as String,
      avatarUrl: (json['avatar_url'] ?? '') as String,
      walletAddress: (json['wallet_address'] ?? '') as String,
      role: json['role'] as int,
    );
  }

  /// ⭐ 新增：不可变拷贝方法
  GroupMember copyWith({
    int? userId,
    String? username,
    String? avatarUrl,
    String? walletAddress,
    int? role,
  }) {
    return GroupMember(
      userId: userId ?? this.userId,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      walletAddress: walletAddress ?? this.walletAddress,
      role: role ?? this.role,
    );
  }
}