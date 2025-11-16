import 'package:protobuf/protobuf.dart';

/// ProtoBuf 消息构造器类型
typedef ProtoCreator = GeneratedMessage Function(List<int> buffer);

/// ProtoBuf 注册中心
class ProtoRegistry {
  static final ProtoRegistry _instance = ProtoRegistry._internal();

  factory ProtoRegistry() => _instance;

  ProtoRegistry._internal();

  /// messageType → 构造器
  final Map<String, ProtoCreator> _creators = {};

  /// 注册 ProtoBuf 消息
  void register<T extends GeneratedMessage>(
      String messageType,
      T Function(List<int>) fromBuffer,
      ) {
    _creators[messageType] = (buffer) => fromBuffer(buffer);
  }

  /// 根据 messageName 自动反序列化
  GeneratedMessage? decode(String messageType, List<int> buffer) {
    final creator = _creators[messageType];
    if (creator == null) return null;
    return creator(buffer);
  }
}

/// 全局注册中心实例
final protoRegistry = ProtoRegistry();
