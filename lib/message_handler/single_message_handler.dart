// lib/message_handler/single_message_handler.dart
import 'package:audioplayers/audioplayers.dart';
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/message_repository.dart'; // 假设你的 repo
import 'package:education/core/websocket/ws_event.dart';
import 'package:education/core/notifications/notifications.dart';
import 'base_message_handler.dart';
import 'package:education/core/sqlite/follower_repository.dart';

class SingleMessageHandler implements BaseMessageHandler {
  @override
  bool canHandle(pb.Event event) {
    return event.delivery == WSDelivery.single;
  }

  // 新增：明确定义好友相关消息类型白名单
  final friendMessageTypes = {
    WSEventType.follow,
    WSEventType.unFollow,
  };

  @override
  Future<void> handle(pb.Event event) async {
    print('【单聊】收到消息 from=${event.fromUser} content=${event.content} status=${event.status} conversationId=${event.conversationId}');

    // 如果是好友相关消息类型
    if (friendMessageTypes.contains(event.type)) {
      friendHandle(event);
      return;
    }


    if(event.status == WSMessageStatus.sending){
      final player = AudioPlayer();
      await player.play(AssetSource('sounds/notice.mp3'));
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

  // 关注、取消关注
  void friendHandle(pb.Event event) async {
    print('好友相关消息类型: type=${event.type}');
    if(event.type == WSEventType.follow){
      await FollowerRepository(Global.db).follow(event.fromUser.toInt(), event.toUser.toInt());
    }else{
      await FollowerRepository(Global.db).unfollow(event.fromUser.toInt(), event.toUser.toInt());
    }
  }
}