import 'package:flutter/foundation.dart';
import '../core/proto/proto_registry.dart';

// 导入你的 proto 编译生成的 Dart 文件
import '../pb/protos/chat.pb.dart';
// 以后其他 proto 也可以 import 进来

/// 初始化 ProtoBuf 注册中心
void initProtoRegistry() {
  debugPrint("Initializing ProtoBuf Registry...");

  // 注册 ChatProto
  protoRegistry.register(
    Event().info_.messageName, // 这里对应你的 chat.proto 的 Event 消息
    (bytes) => Event.fromBuffer(bytes),
  );

  // 如果有教育模块 Proto，可以在这里注册
  // protoRegistry.register(
  //   CourseProto().info_.messageName,
  //   (bytes) => CourseProto.fromBuffer(bytes),
  // );

  // 未来增加更多 proto，只需继续注册
}
