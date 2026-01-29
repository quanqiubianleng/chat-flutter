// lib/message_handler/group_message_handler.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/message_repository.dart';
import '../core/sqlite/group_mute_repository.dart';
import '../core/sqlite/group_mute_table.dart';
import '../core/websocket/ws_event.dart';
import 'base_message_handler.dart';

class GroupMessageHandler implements BaseMessageHandler {
  @override
  bool canHandle(pb.Event event) {
    return event.delivery == WSDelivery.group;
  }

  final addGroupTypes = {
    // 创建群组
    WSEventType.createGroup,
    WSEventType.addGroupMembers,
  };

  // 群组禁言
  final groupMuteTypes = {
    WSEventType.groupMute,
    WSEventType.groupClearMute,
  };

  @override
  Future<void> handle(pb.Event event) async {
    print('【群聊】群 ${event.groupId} 收到消息 status=${event.status} msg=${event.msgId} conversationId=${event.conversationId}');

    if(event.status == WSMessageStatus.sending){
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/notice.mp3'));
      // 1. 保存消息
      await MessageRepository(Global.db).saveMessage(event);
    }else{
      if (!addGroupTypes.contains(event.type)) {
        await MessageRepository(Global.db).updateMessageByClientMsgId(event);
      }else{
        // 1. 保存消息
        await MessageRepository(Global.db).saveMessage(event);
      }
    }

    // 禁言
    if (groupMuteTypes.contains(event.type)) {
      print("取消、禁言操作");
      print(event.type == WSEventType.groupClearMute);
      if(event.type == WSEventType.groupClearMute){
        await GroupMuteRepository(Global.db).clearMuteAll(event.groupId.toInt());
      }else{
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final setting = GroupMuteSetting(
          groupId: event.groupId.toInt(),
          isMuteAll: true,
          muteAllUntil: null,
          operatorId: event.fromUser.toString(),
          reason: null,
          updatedAt: now,
          // version 預設 1，可自行遞增邏輯
        );
        await GroupMuteRepository(Global.db).upsertMuteAllSetting(setting);
      }
    }

    // 群聊特有逻辑
    // - @人高亮处理
    // - 群公告检测
    // - 撤回消息处理
    // - 播放群消息提示音（可根据设置静音）
  }
}