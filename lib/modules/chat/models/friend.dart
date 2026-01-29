// models/friend.dart
class Friend {
  final int userId;              // 好友用户ID
  final String username;     // 用户名
  final String avatarUrl;     // 头像URL（如果有）
  final String walletAddress;       // 地址
  // 根据你的实际接口返回字段继续添加...

  Friend({
    required this.userId,
    required this.username,
    this.avatarUrl = '',
    this.walletAddress = '',
  });

  // 从后端返回的 Map 转为 Friend 对象
  factory Friend.fromJson(Map<String, dynamic> json) {
    return Friend(
      userId: json['userId'] as int,
      username: json['username'] as String,
      avatarUrl: (json['avatar_url'] ?? '') as String,
      walletAddress: (json['wallet_address'] ?? '') as String,
    );
  }
}