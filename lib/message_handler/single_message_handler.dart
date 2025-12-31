// lib/message_handler/single_message_handler.dart
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/message_repository.dart'; // 假设你的 repo
import '../core/websocket/ws_event.dart';
import 'base_message_handler.dart';

class SingleMessageHandler implements BaseMessageHandler {
  @override
  bool canHandle(pb.Event event) {
    return event.delivery == 'single';
  }

  @override
  Future<void> handle(pb.Event event) async {
    print('【单聊】收到消息 from=${event.fromUser} content=${event.content} status=${event.status} conversationId=${event.conversationId}');

    if(event.status == WSMessageStatus.sending){
      // 1. 保存消息
      await MessageRepository(Global.db).saveMessage(event);
    }else{
      await MessageRepository(Global.db).updateMessageByClientMsgId(event);
    }


    // 2. 单聊特有逻辑（可选）
    // - 触发对方用户信息更新
    // - 播放专属提示音
    // - 统计单聊未读
    // - 推送本地通知（带对方昵称）
  }
}