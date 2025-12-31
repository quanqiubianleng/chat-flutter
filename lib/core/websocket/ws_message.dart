// lib/core/websocket/ws_message.dart
// 该文件在新协议下已不再需要（全部直接使用 chat.pb.dart 中的 Event）
// 保留仅为兼容旧代码，可直接删除

import 'package:education/pb/protos/chat.pb.dart';

/// 旧的抽象消息类，已废弃
@Deprecated("直接使用 chat.pb.dart 中的 Event")
abstract class WSMessage {
  List<int> toProtoBuf() => [];
}