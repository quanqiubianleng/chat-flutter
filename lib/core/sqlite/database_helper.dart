import 'dart:convert';
import 'dart:typed_data';
import 'package:education/core/sqlite/user_table.dart';
import 'package:fixnum/fixnum.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'follower_table.dart';
import 'group_mute_table.dart'; // 导入 follower 表创建函数

// ==================== Event 扩展：保持不变，很好 ====================
extension EventSqlite on pb.Event {
  pb.Event fillFromMap(Map<String, dynamic> map) {
    delivery = map['delivery'] as String? ?? '';
    type = map['type'] as String? ?? '';

    fromUser = map['from_user'] is Int64
        ? map['from_user'] as Int64
        : Int64((map['from_user'] as num?)?.toInt() ?? 0);

    toUser = map['to_user'] is Int64
        ? map['to_user'] as Int64
        : Int64((map['to_user'] as num?)?.toInt() ?? 0);

    groupId = map['group_id'] is Int64
        ? map['group_id'] as Int64
        : Int64((map['group_id'] as num?)?.toInt() ?? 0);

    msgId = map['msg_id'] as String? ?? '';
    clientMsgId = map['client_msg_id'] as String? ?? '';
    mediaUrl = map['media_url'] as String? ?? '';
    content = map['content'] as String? ?? '';

    // 新增：读取 conversation_id
    if (map['conversation_id'] != null) {
      conversationId = map['conversation_id'];
    }

    // extra: TEXT(JSON) → Uint8List
    if (map['extra'] != null &&
        map['extra'] is String &&
        (map['extra'] as String).isNotEmpty) {
      extra = Uint8List.fromList(
          (jsonDecode(map['extra'] as String) as List).cast<int>());
    }

    timestamp = Int64((map['timestamp'] as num?)?.toInt() ?? 0);
    serverTs = Int64((map['server_ts'] as num?)?.toInt() ?? 0);
    nodeId = map['node_id'] as String? ?? '';
    seq = Int64((map['seq'] as num?)?.toInt() ?? 0);
    status = map['status'] as String? ?? '';
    replyTo = map['reply_to'] as String? ?? '';

    // mention: TEXT(JSON) → List<Int64>
    if (map['mention'] != null &&
        map['mention'] is String &&
        (map['mention'] as String).isNotEmpty) {
      final list = jsonDecode(map['mention'] as String) as List;
      mention.addAll(list.map((e) => Int64(e as int)));
    }

    threadId = map['thread_id'] as String? ?? '';
    senderNickname = map['sender_nickname'] as String? ?? '';
    senderAvatar = map['sender_avatar'] as String? ?? '';

    return this;
  }

  Map<String, dynamic> toMapForDb() {
    return {
      'delivery': delivery,
      'type': type,
      'from_user': fromUser.toInt(),
      'to_user': toUser.toInt(),
      'group_id': groupId.toInt(),
      'conversation_id': conversationId.toString(), // 新增：保存服务端ID
      'msg_id': msgId.isEmpty || msgId.startsWith('temp_') ? null : msgId,
      'client_msg_id': clientMsgId,
      'media_url': mediaUrl,
      'content': content,
      'extra': extra.isNotEmpty ? jsonEncode(extra) : null,
      'timestamp': timestamp.toInt(),
      'server_ts': serverTs.toInt(),
      'node_id': nodeId,
      'seq': seq.toInt(),
      'status': status,
      'reply_to': replyTo,
      'mention':
      mention.isNotEmpty ? jsonEncode(mention.map((e) => e.toInt())) : null,
      'thread_id': threadId,
      'sender_nickname': senderNickname,
      'sender_avatar': senderAvatar,
    };
  }
}

// ==================== Conversation 类：全面升级 ====================
class Conversation {
  final int? localId;                          // 本地自增ID
  final String serverConversationId;              // 服务端真实ID（核心！）
  final int userId;
  final String type;                           // single / group
  final String title;
  final String avatar;
  final String? lastMsgId;
  final String? lastContent;                   // 新增：最后一条消息内容
  final int lastTimestamp;
  int unreadCount;
  bool pinned;
  bool muted;
  String draftText;
  int lastReadSeq;
  bool isDeleted;
  final int createdAt;
  int updatedAt;

  Conversation({
    this.localId,
    required this.serverConversationId,
    required this.userId,
    required this.type,
    required this.title,
    required this.avatar,
    this.lastMsgId,
    this.lastContent,
    required this.lastTimestamp,
    this.unreadCount = 0,
    this.pinned = false,
    this.muted = false,
    this.draftText = '',
    this.lastReadSeq = 0,
    this.isDeleted = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Conversation.fromMap(Map<String, dynamic> map) {
    return Conversation(
      localId: map['id'] as int?,
      serverConversationId: map['server_conversation_id'] as String? ?? "",
      userId: map['user_id'] as int? ?? 0,
      type: map['type'] as String,
      title: map['title'] as String? ?? '',
      avatar: map['avatar'] as String? ?? '',
      lastMsgId: map['last_msg_id'] as String?,
      lastContent: map['last_content'] as String?,
      lastTimestamp: map['last_timestamp'] as int? ?? 0,
      unreadCount: map['unread_count'] as int? ?? 0,
      pinned: (map['pinned'] as int? ?? 0) == 1,
      muted: (map['muted'] as int? ?? 0) == 1,
      draftText: map['draft_text'] as String? ?? '',
      lastReadSeq: map['last_read_seq'] as int? ?? 0,
      isDeleted: (map['is_deleted'] as int? ?? 0) == 1,
      createdAt: map['created_at'] as int? ?? 0,
      updatedAt: map['updated_at'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': localId,
      'server_conversation_id': serverConversationId,
      'user_id': userId,
      'type': type,
      'title': title,
      'avatar': avatar,
      'last_msg_id': lastMsgId,
      'last_content': lastContent,
      'last_timestamp': lastTimestamp,
      'unread_count': unreadCount,
      'pinned': pinned ? 1 : 0,
      'muted': muted ? 1 : 0,
      'draft_text': draftText,
      'last_read_seq': lastReadSeq,
      'is_deleted': isDeleted ? 1 : 0,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

// ==================== DatabaseHelper：核心升级 ====================
class DatabaseHelper {
  static DatabaseHelper? _instance;
  static Database? _database;

  DatabaseHelper._privateConstructor();
  static DatabaseHelper get instance => _instance ??= DatabaseHelper._privateConstructor();

  Future<Database> get database async => _database ??= await _initDatabase();

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final path = join(dir.path, 'app.db');
    return await openDatabase(
      path,
      version: 3, // 版本升级！
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,  // 新增：实现升级逻辑
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await _createTables(db);
  }

  Future<void> _createTables(Database db) async {
    // messages 表：新增 conversation_id
    await db.execute('''
      CREATE TABLE messages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,     -- 本地自增 ID（可选，用于 Riverpod key）
        msg_id TEXT,
        client_msg_id TEXT,
        delivery TEXT,
        type TEXT,
        from_user INTEGER,
        to_user INTEGER,
        group_id INTEGER,
        conversation_id TEXT,  -- 新增：服务端会话ID
        media_url TEXT,
        content TEXT,
        extra TEXT,
        timestamp INTEGER,
        server_ts INTEGER,
        node_id TEXT,
        seq INTEGER,
        status TEXT,
        reply_to TEXT,
        mention TEXT,
        thread_id TEXT,
        sender_nickname TEXT,
        sender_avatar TEXT
      )
    ''');

    // conversations 表：全面升级
    await db.execute('''
      CREATE TABLE conversations (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        server_conversation_id TEXT NOT NULL,  -- 服务端真实ID
        user_id INTEGER NOT NULL DEFAULT 0,
        type TEXT NOT NULL,
        title TEXT,
        avatar TEXT,
        last_msg_id TEXT,
        last_content TEXT,
        last_timestamp INTEGER,
        unread_count INTEGER DEFAULT 0,
        pinned INTEGER DEFAULT 0,
        muted INTEGER DEFAULT 0,
        draft_text TEXT DEFAULT '',
        last_read_seq INTEGER DEFAULT 0,
        is_deleted INTEGER DEFAULT 0,
        created_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
        updated_at INTEGER NOT NULL DEFAULT (strftime('%s','now') * 1000),
        UNIQUE(server_conversation_id, user_id)
      )
    ''');

    // FTS5 全文搜索（保持不变）
    await db.execute('''
      CREATE VIRTUAL TABLE messages_fts USING fts5(
        msg_id,
        content,
        sender_nickname,
        tokenize = 'unicode61'
      );
    ''');


    await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp DESC)');

    // 创建 follower 表
    await createFollowerTable(db);
    // 创建user表
    await createUserTable(db);
    // 创建群组禁言表
    await createGroupMuteTables(db);
  }

  // 数据表升级
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 安全添加列：先查是否已存在
      await _addColumnIfNotExists(db, 'messages', 'status', 'TEXT');
      await _addColumnIfNotExists(db, 'messages', 'conversation_id', 'TEXT');
      await _addColumnIfNotExists(db, 'messages', 'client_msg_id', 'TEXT');

      // 添加索引（这些支持 IF NOT EXISTS，安全）
      await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_messages_conversation_user_id ON messages(user_id)');
      await db.execute('CREATE UNIQUE INDEX IF NOT EXISTS idx_messages_client_msg_id ON messages(client_msg_id)');
    }

    // 未来版本可以继续加
    // if (oldVersion < 3) { ... }
  }

  // 工具函数：安全添加列
  Future<void> _addColumnIfNotExists(Database db, String table, String column, String type) async {
    final tableInfo = await db.rawQuery('PRAGMA table_info($table);');
    final hasColumn = tableInfo.any((row) => row['name'] == column);

    if (!hasColumn) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $type;');
      print('添加列成功: $table.$column $type');
    } else {
      print('列已存在，无需添加: $table.$column');
    }
  }
}