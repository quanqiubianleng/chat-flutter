// ======================== 单个气泡 ========================
import 'dart:convert';

import 'package:education/core/websocket/ws_event.dart';
import 'package:education/providers/user_provider.dart';
import 'package:education/widgets/chat/avatar.dart';
import 'package:education/widgets/chat/image_bubble.dart';
import 'package:education/widgets/chat/invite_link_bubble.dart';
import 'package:education/widgets/chat/redpacket_bubble.dart';
import 'package:education/widgets/chat/text_bubble.dart';
import 'package:education/widgets/chat/video_bubble.dart';
import 'package:education/widgets/chat/voice_bubble.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:education/pb/protos/chat.pb.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart';

import '../../core/websocket/ws_extra.dart';

class MessageBubble extends ConsumerWidget {
  final Event message;

  const MessageBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 用 Riverpod 获取当前用户 UID
    final uidAsync = ref.watch(userProvider);

    return uidAsync.when(
      loading: () => const SizedBox.shrink(), // UID 加载中时不显示（极少发生）
      error: (_, __) => const SizedBox.shrink(),
      data: (currentUid) {
        if (currentUid == null) {
          return const Center(child: Text('用户未登录'));
        }

        final isMe = message.fromUser.toInt() == currentUid;
        final maxWidth = MediaQuery.of(context).size.width * 0.7;

        // 时间处理（更安全）
        final timestampMs = message.timestamp.toInt() *
            (message.timestamp.toInt() < 10000000000 ? 1000 : 1);
        final dt = DateTime.fromMillisecondsSinceEpoch(timestampMs);

        // 发送者昵称（优先用 senderNickname，有则显示，否则用默认）
        final senderName = message.hasSenderNickname() && message.senderNickname.isNotEmpty
            ? message.senderNickname
            : (isMe ? "我" : "对方");

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              // 左侧头像（非自己）
              if (!isMe) const Avatar(),
              if (!isMe) const SizedBox(width: 8),

              // 消息 + 昵称 + 时间
              Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // 昵称
                  Text(
                    senderName,
                    style: const TextStyle(color: Color(0xFF888888), fontSize: 12),
                  ),
                  const SizedBox(height: 4),

                  // 消息气泡
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: _buildBubble(message),
                  ),
                  const SizedBox(height: 4),

                  // 时间
                  Text(
                    "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}",
                    style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
                  ),
                ],
              ),

              if (isMe) const SizedBox(width: 8),
              if (isMe) const Avatar(),
            ],
          ),
        );
      },
    );
  }


  // 提取气泡构建逻辑，便于维护
  Widget _buildBubble(Event message) {
    switch (message.type) {
      case 'message':
      case WSEventType.message:  // 如果 WSEventType.message 是字符串 'message'
        return TextBubble(message: message);

      case 'red_packet':
      case WSEventType.redPacket:
        return RedPacketBubble(message: message);

      case 'invite':
      case WSEventType.invite:
        return InviteLinkBubble(message: message);

      case 'image':
      case WSEventType.image:
        return ImageBubble(url: message.mediaUrl.isNotEmpty ? message.mediaUrl : message.content);

      case 'voice':
      case WSEventType.voice:
        return VoiceBubble(message: message, isMe: true);

      case 'video':
      case WSEventType.video:
        return VideoBubble(thumbnail: message.mediaUrl);

      default:
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '[不支持的消息类型: ${message.type}]',
            style: const TextStyle(color: Colors.grey),
          ),
        );
    }
  }
}

