// lib/models/conversation_info.dart
import 'package:education/pb/protos/chat.pb.dart' as pb;

class ConversationInfo {
  final int conversationId;      // 服务端 convID
  final String type;             // "private" 或 "group"
  final String title;
  final String avatar;
  final int peerUserId;            // 新增：单聊时对方用户ID；群聊时 0（关键！）
  final int? creatorId;
  final int createdAt;
  final int updatedAt;
  final String? lastMsgId;
  final String? lastMsgContent;
  final int? lastMsgTimestamp;

  ConversationInfo({
    required this.conversationId,
    required this.type,
    required this.title,
    required this.avatar,
    this.peerUserId = 0,           // 默认 0（群聊或未知）
    this.creatorId,
    required this.createdAt,
    required this.updatedAt,
    this.lastMsgId,
    this.lastMsgContent,
    this.lastMsgTimestamp,
  });

  factory ConversationInfo.fromJson(Map<String, dynamic> json) {
    return ConversationInfo(
      conversationId: json['conversation_id'] as int,
      type: json['type'] as String,
      title: json['title'] as String? ?? '',
      avatar: json['avatar'] as String? ?? '',
      peerUserId: json['peer_user_id'] as int? ?? 0,  // 单聊：对方UID；群聊：0
      createdAt: json['created_at'] as int,
      updatedAt: json['updated_at'] as int,
      lastMsgId: json['last_msg_id'] as String?,
      lastMsgContent: json['last_msg_content'] as String?,
      lastMsgTimestamp: json['last_msg_timestamp'] as int?,
    );
  }

  // 可选：转 Map 用于数据库操作
  Map<String, dynamic> toMap() {
    return {
      'server_conversation_id': conversationId,
      'type': type,
      'title': title,
      'avatar': avatar,
      'created_at': createdAt * 1000, // 服务端是秒，转毫秒
      'updated_at': updatedAt * 1000,
      'last_msg_id': lastMsgId,
      // last_msg_content 和 last_msg_timestamp 可以不存本地，靠消息表
    };
  }

  // 新增便利属性
  bool get isGroup => type == 'group';
  bool get isSingle => type == 'single' || type == 'private';
}