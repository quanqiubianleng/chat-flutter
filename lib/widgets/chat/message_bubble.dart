// ======================== 单个气泡 ========================
import 'dart:convert';

import 'package:education/core/websocket/ws_event.dart';
import 'package:education/providers/user_provider.dart';
import 'package:education/widgets/chat/avatar.dart';
import 'package:education/widgets/chat/image_bubble.dart';
import 'package:education/widgets/chat/invite_link_bubble.dart';
import 'package:education/widgets/chat/redpacket_bubble.dart';
import 'package:education/widgets/chat/text_bubble.dart';
import 'package:education/widgets/chat/transfer_bubble.dart';
import 'package:education/widgets/chat/video_bubble.dart';
import 'package:education/widgets/chat/voice_bubble.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter/material.dart';
import 'package:education/pb/protos/chat.pb.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/core/utils/timer.dart';

import '../../core/utils/date_utils.dart';
import '../../modules/chat/models/chat_display_item.dart';

class MessageBubble extends ConsumerWidget {
  final Event message;
  final bool showTime;
  const MessageBubble({Key? key, required this.message,this.showTime = true,}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 用 Riverpod 获取当前用户 UID
    final uidAsync = ref.watch(userProvider);
    final myAvatarAsync = ref.watch(myAvatarProvider);
    // 获取其他用户信息
    final senderId = message.fromUser.toInt();
    final senderAsync = ref.watch(userInfoProvider(senderId));

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
        final senderName = senderAsync.value?.username ?? "未知用户";

        // 新增：明确定义群组消息类型通知白名单
        const groupMessageTypes = {
          // 创建群组
          WSEventType.createGroup,
          WSEventType.addGroupMembers,
          // 禁言消息
          WSEventType.groupClearMute,
          WSEventType.groupMute,
        };

        // 消息信息
        debugPrint('msgId: ${message.msgId}');

        if(message.delivery == WSDelivery.group && groupMessageTypes.contains(message.type)){
          return _groupNoticeMessage(message, showTime: showTime);
        }else{
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
            child: Column(
              children: [
                // ⭐ 时间独立一行，居中显示
                if (showTime) ...[
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      ChatDateUtils.formatDateHeader(dt),
                      style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // ⭐ 原来的消息 Row 保持不动
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                  children: [
                    if (!isMe)
                      senderAsync.when(
                        data: (user) => Avatar(url: user.avatarUrl),
                        loading: () => const Avatar(url: null),
                        error: (_, __) => const Avatar(url: null),
                      ),
                    if (!isMe) const SizedBox(width: 8),

                    Column(
                      crossAxisAlignment:
                      isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                      children: [
                        if (!isMe && message.delivery == WSDelivery.group)
                          Text(
                            senderName,
                            style: const TextStyle(
                                color: Color(0xFF888888), fontSize: 12),
                          ),
                        if (!isMe && message.delivery == WSDelivery.group)
                          const SizedBox(height: 4),

                        ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: maxWidth),
                          child: _buildBubble(message, isMe),
                        ),
                      ],
                    ),

                    if (isMe) const SizedBox(width: 8),
                    if (isMe)
                      myAvatarAsync.when(
                        data: (url) => Avatar(url: url),
                        loading: () =>
                        const CircleAvatar(child: CircularProgressIndicator()),
                        error: (_, __) => const Avatar(url: null),
                      ),
                  ],
                ),
              ],
            ),
          );

        }

      },
    );
  }


  // 提取气泡构建逻辑，便于维护
  Widget _buildBubble(Event message, bool isMe) {
    switch (message.type) {
      case WSEventType.message:  // 如果 WSEventType.message 是字符串 'message'
        return TextBubble(message: message);
      case WSEventType.redPacket:
        return RedPacketBubble(message: message);
      case WSEventType.transfer:
        return TransferBubble(message: message, isMe: isMe,);
      case WSEventType.invite:
        return InviteLinkBubble(message: message);
      case WSEventType.image:
        return ImageBubble(url: message.mediaUrl.isNotEmpty ? message.mediaUrl : message.content);
      case WSEventType.voice:
        return VoiceBubble(message: message, isMe: true);
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

  // 群组通知消息
  Widget _groupNoticeMessage(Event message, {required bool showTime}){
    // 时间处理（更安全）
    final dt = parseTimestamp(message.timestamp);
    List<String> sender = message.senderNickname.split('、').map((e) => e.trim()).toList();
    return Center(
      child: Column(
        children: [
          // 时间
          if (showTime) ...[
            const SizedBox(height: 4),
            Text(
              ChatDateUtils.formatDateHeader(dt),
              style: const TextStyle(color: Color(0xFF666666), fontSize: 11),
            ),
            const SizedBox(height: 4),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                sender[0],
                style: const TextStyle(color: Colors.green, fontSize: 12),
              ),
              Text(
                " ${message.content}",
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              )
            ],
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

