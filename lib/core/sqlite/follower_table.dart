import 'package:sqflite/sqflite.dart';

Future<void> createFollowerTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS follower (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      from_user_id INTEGER NOT NULL,
      to_user_id INTEGER NOT NULL,
      name TEXT,
      avatar_url TEXT,
      remark TEXT,
      address TEXT,
      is_read INTEGER NOT NULL,
      created_at INTEGER,
      updated_at INTEGER
    );
  ''');

  await db.execute('''
    CREATE UNIQUE INDEX IF NOT EXISTS idx_follower_pair
    ON follower (from_user_id, to_user_id);
  ''');
}

class Follower {
  final int fromUserId;
  final int toUserId;
  final String? name;
  final String? avatarUrl;
  final String? remark;
  final String? address;
  final int isRead;
  final int createdAt;

  Follower({
    required this.fromUserId,
    required this.toUserId,
    this.name,
    this.avatarUrl,
    this.remark,
    this.address,
    this.isRead = 0,
    required this.createdAt,
  });

  factory Follower.fromMap(Map<String, dynamic> map) {
    return Follower(
      fromUserId: map['from_user_id'] as int,
      toUserId: map['to_user_id'] as int,
      name: map['name'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      remark: map['remark'] as String?,
      address: map['address'] as String?,
      isRead: map['is_read'] as int,
      createdAt: map['created_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'name': name,
      'avatar_url': avatarUrl,
      'remark': remark,
      'address': address,
      'is_read': isRead,
      'created_at': createdAt,
    };
  }
}

