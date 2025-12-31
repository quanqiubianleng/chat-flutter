class User {
  final String username;
  final String walletAddress;
  final String avatarUrl;
  final String level;
  final int userId;
  final String did;
  final String deviceNo;

  User({
    required this.username,
    required this.walletAddress,
    required this.avatarUrl,
    required this.level,
    required this.userId,
    required this.did,
    required this.deviceNo,
  });

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      username: map['username']?.toString() ?? '',
      walletAddress: map['wallet_address']?.toString() ?? '',
      avatarUrl: map['avatar_url']?.toString() ?? '',
      level: map['level']?.toString() ?? 'Lv.1',
      userId: _parseInt(map['userId']),
      did: map['did']?.toString() ?? '',
      deviceNo: map['deviceNo']?.toString() ?? '',
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  Map<String, dynamic> toMap() {
    return {
      'username': username,
      'wallet_address': walletAddress,
      'avatar_url': avatarUrl,
      'level': level,
      'userId': userId,
      'did': did,
      'deviceNo': deviceNo,
    };
  }

  @override
  String toString() {
    return 'User(username: $username, walletAddress: $walletAddress, userId: $userId)';
  }
}