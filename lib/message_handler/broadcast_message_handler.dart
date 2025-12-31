// lib/message_handler/broadcast_message_handler.dart
import 'package:education/pb/protos/chat.pb.dart' as pb;
import 'base_message_handler.dart';

class BroadcastMessageHandler implements BaseMessageHandler {
  @override
  bool canHandle(pb.Event event) {
    return event.delivery == 'broadcast';
  }

  @override
  Future<void> handle(pb.Event event) async {
    print('【广播】系统消息: ${event.content}');


    // 广播通常不存本地消息表，或存到单独的系统消息表
    // - 显示全局 Toast / Banner
    // - 跳转到公告页
    // - 更新全局状态（如版本更新、活动通知）

    // 示例：显示一个全局提示
    // Global.showToast(event.content);
  }
}