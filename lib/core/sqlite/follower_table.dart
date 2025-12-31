import 'package:sqflite/sqflite.dart';

Future<void> createFollowerTable(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS follower (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      from_user_id INTEGER NOT NULL,
      to_user_id INTEGER NOT NULL,
      remark TEXT,
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
  final String? remark;

  Follower({
    required this.fromUserId,
    required this.toUserId,
    this.remark,
  });

  Map<String, dynamic> toMap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    return {
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'remark': remark,
      'created_at': now,
      'updated_at': now,
    };
  }
}

