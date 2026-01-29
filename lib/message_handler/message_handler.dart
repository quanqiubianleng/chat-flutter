// lib/message_handler/message_handler.dart
import 'dart:convert';
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/message_repository.dart';
import 'package:education/modules/chat/models/conversation_info.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tab_badge_provider.dart';
import 'base_message_handler.dart';
import 'single_message_handler.dart';
import 'group_message_handler.dart';
import 'broadcast_message_handler.dart';
import 'package:education/core/websocket/ws_event.dart';

// 改为使用回调函数来通知角标更新
class MessageHandler {
  final List<BaseMessageHandler> _handlers = [];
  final WidgetRef? ref;

  MessageHandler(this.ref) {  // 修改构造函数
    _handlers.add(SingleMessageHandler());
    _handlers.add(GroupMessageHandler());
    _handlers.add(BroadcastMessageHandler());
  }


  /// 全局处理入口（在 WebSocket onMessage 中调用）
  Future<void> process(pb.Event event) async {
    print('获取消息process delivery=${event.delivery} seq=${event.seq}');

    // 1. 处理会话列表同步（优先处理！）
    if (event.type == WSEventType.conversationListSync) {
      print('处理会话列表同步');
      await _handleConversationListSync(event);
      return;
    }

    // 2. 离线消息同步完成（可选刷新 UI）
    if (event.type == 'offline_sync_complete') {
      print('所有离线消息和会话列表同步完成');
      return;
    }


    // 新增：明确定义聊天消息类型白名单
    const chatMessageTypes = {
      WSEventType.message,
      WSEventType.image,
      WSEventType.video,
      WSEventType.file,
      WSEventType.voice,
      'location',
      WSEventType.businessCard,
      WSEventType.redPacket,
      WSEventType.withdraw,
      WSEventType.transfer,

      // 系统消息
      WSEventType.follow,
      WSEventType.unFollow,

      // 创建群组
      WSEventType.createGroup,
      WSEventType.addGroupMembers,
      WSEventType.groupMute,
      WSEventType.groupClearMute,
    };

    // 如果不是聊天消息类型，直接返回（不保存、不处理）
    if (!chatMessageTypes.contains(event.type)) {
      print('非聊天消息，忽略处理: type=${event.type}');

      return;
    }

    // 3. 正常消息处理
    for (final handler in _handlers) {
      if (handler.canHandle(event)) {
        await handler.handle(event);
        return;
      }
    }

    print('未匹配到专用 handler，使用默认处理: ${event.type}');
  }

  Future<void> _handleConversationListSync(pb.Event event) async {
    if (event.extra.isEmpty) {
      print('会话列表同步数据为空');
      return;
    }

    try {
      final jsonStr = utf8.decode(event.extra);
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      print("会话列表extra.data");
      print(data);

      final rawList = data['conversations'];
      if (rawList == null || rawList is! List) {
        print('会话列表同步格式错误：缺少 conversations 字段或不是 List');
        return;
      }

      final convList = rawList
          .map((e) => ConversationInfo.fromJson(e as Map<String, dynamic>))
          .toList();

      print('收到会话列表同步，共 ${convList.length} 个会话');

      if (convList.isNotEmpty) {
        final repo = MessageRepository(Global.db!);
        await repo.syncConversationList(convList);
      } else {
        print('会话列表为空，无需同步到本地数据库');
      }
    } catch (e) {
      print('解析 conversation_list_sync 失败: $e');
    }
  }
}