import 'package:sqflite/sqflite.dart';

Future<void> createUserTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS user (
      userId INTEGER PRIMARY KEY,
      username TEXT,
      avatar_url TEXT,
      remark TEXT,

      version INTEGER NOT NULL DEFAULT 1,
      updated_at INTEGER,
      deleted INTEGER DEFAULT 0,
      extra TEXT
    );
  ''');

  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_user_username
    ON user (username);
  ''');
}

class UserProfile {
  final int userId;
  final String? username;
  final String? avatarUrl;
  final String? remark;

  final int version;
  final int? updatedAt;
  final int deleted;
  final String? extra;

  UserProfile({
    required this.userId,
    this.username,
    this.avatarUrl,
    this.remark,
    this.version = 1,
    this.updatedAt,
    this.deleted = 0,
    this.extra,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      userId: map['userId'] as int,
      username: map['username'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      remark: map['remark'] as String?,
      version: map['version'] as int? ?? 1,
      updatedAt: map['updated_at'] as int?,
      deleted: map['deleted'] as int? ?? 0,
      extra: map['extra'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'username': username,
      'avatar_url': avatarUrl,
      'remark': remark,
      'version': version,
      'updated_at': updatedAt,
      'deleted': deleted,
      'extra': extra,
    };
  }
}
