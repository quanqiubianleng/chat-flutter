// lib/message_handler/base_message_handler.dart
import 'package:education/pb/protos/chat.pb.dart' as pb;

abstract class BaseMessageHandler {
  /// 是否能处理该消息
  bool canHandle(pb.Event event);

  /// 处理消息（子类实现）
  Future<void> handle(pb.Event event);
}