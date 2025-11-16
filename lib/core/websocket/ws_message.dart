import 'dart:convert';
import 'package:protobuf/protobuf.dart';
import '../../pb/protos/chat.pb.dart';

/// WebSocket 消息基类
abstract class WSMessage {
  Map<String, dynamic> toJson() => {};
  List<int> toProtoBuf() => [];
}


/// ProtoBuf 消息示例
class WSProtoMessage<T extends GeneratedMessage> extends WSMessage {
  final T message;

  WSProtoMessage(this.message);

  @override
  List<int> toProtoBuf() => message.writeToBuffer();
}

