import 'dart:convert';

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:education/pb/protos/chat.pb.dart' as pb;

class Message {
  final String delivery;
  final String type;
  final int fromUser;
  final int toUser;
  final int groupId;

  final String msgId;
  final String clientMsgId;

  final String mediaUrl;
  final String content;
  final String extra;

  final int timestamp;
  final int serverTs;
  final int clientTs;
  final String nodeId;

  final int seq;
  final String status;

  final String replyTo;
  final List<int> mention;
  final String threadId;

  final String senderNickname;
  final String senderAvatar;

  final String conversationId;

  const Message({
    this.delivery = '',
    this.type = '',
    this.fromUser = 0,
    this.toUser = 0,
    this.groupId = 0,
    this.msgId = '',
    this.clientMsgId = '',
    this.mediaUrl = '',
    this.content = '',
    this.extra = '',
    this.timestamp = 0,
    this.serverTs = 0,
    this.clientTs = 0,
    this.nodeId = '',
    this.seq = 0,
    this.status = '',
    this.replyTo = '',
    this.mention = const [],
    this.threadId = '',
    this.senderNickname = '',
    this.senderAvatar = '',
    this.conversationId = '',
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      delivery: json['delivery'] ?? '',
      type: json['type'] ?? '',
      fromUser: json['from_user'] ?? 0,
      toUser: json['to_user'] ?? 0,
      groupId: json['group_id'] ?? 0,
      msgId: json['msg_id'] ?? '',
      clientMsgId: json['client_msg_id'] ?? '',
      mediaUrl: json['media_url'] ?? '',
      content: json['content'] ?? '',
      extra: json['extra'] ?? '',
      timestamp: json['timestamp'] ?? 0,
      serverTs: json['server_ts'] ?? 0,
      clientTs: json['client_ts'] ?? 0,
      nodeId: json['node_id'] ?? '',
      seq: json['seq'] ?? 0,
      status: json['status'] ?? '',
      replyTo: json['reply_to'] ?? '',
      mention: (json['mention'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList() ??
          [],
      threadId: json['thread_id'] ?? '',
      senderNickname: json['sender_nickname'] ?? '',
      senderAvatar: json['sender_avatar'] ?? '',
      conversationId: json['conversation_id'] ?? '',
    );
  }
}

class OfflineMessageResp {
  final List<Message> list;
  final String nextCursor;
  final bool hasMore;
  final int serverTime;

  const OfflineMessageResp({
    this.list = const [],
    this.nextCursor = '',
    this.hasMore = false,
    this.serverTime = 0,
  });

  factory OfflineMessageResp.fromJson(Map<String, dynamic> json) {
    return OfflineMessageResp(
      list: (json['list'] as List<dynamic>?)
          ?.map((e) => Message.fromJson(e))
          .toList() ??
          [],
      nextCursor: json['next_cursor'] ?? '',
      hasMore: json['has_more'] ?? false,
      serverTime: json['server_time'] ?? 0,
    );
  }
}



extension OfflineMessageToPb on Message {
  /// 将本地 Message 转为 pb.Event
  pb.Event toPbEvent() {
    return pb.Event(
      delivery: delivery,
      type: type,
      fromUser: $fixnum.Int64(fromUser),
      toUser: $fixnum.Int64(toUser),
      groupId: $fixnum.Int64(groupId),
      msgId: msgId,
      clientMsgId: clientMsgId,
      mediaUrl: mediaUrl,
      content: content,
      extra: extra.isNotEmpty ? utf8.encode(extra) : null,
      timestamp: $fixnum.Int64(timestamp),
      serverTs: $fixnum.Int64(serverTs),
      nodeId: nodeId,
      seq: $fixnum.Int64(seq),
      status: status,
      replyTo: replyTo,
      mention: mention.map((e) => $fixnum.Int64(e)),
      threadId: threadId,
      senderNickname: senderNickname,
      senderAvatar: senderAvatar,
      conversationId: conversationId,
    );
  }
}


