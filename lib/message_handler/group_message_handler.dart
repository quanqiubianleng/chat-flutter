// lib/message_handler/group_message_handler.dart
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/message_repository.dart';
import 'base_message_handler.dart';

class GroupMessageHandler implements BaseMessageHandler {
  @override
  bool canHandle(pb.Event event) {
    return event.delivery == 'group';
  }

  @override
  Future<void> handle(pb.Event event) async {
    print('【群聊】群 ${event.groupId} 收到消息 from=${event.fromUser}');

    await MessageRepository(Global.db).saveMessage(event);

    // 群聊特有逻辑
    // - @人高亮处理
    // - 群公告检测
    // - 撤回消息处理
    // - 播放群消息提示音（可根据设置静音）
  }
}