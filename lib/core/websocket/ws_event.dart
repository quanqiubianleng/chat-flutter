// lib/core/websocket/ws_event.dart

import 'package:education/pb/protos/chat.pb.dart';

/// 事件回调
typedef EventCallback = void Function(Event event);

/// 全局事件总线（可选，如果你页面里需要跨组件监听）
class WSEventBus {
  final Map<String, List<EventCallback>> _listeners = {};

  void on(String eventType, EventCallback callback) {
    _listeners.putIfAbsent(eventType, () => []).add(callback);
  }

  void off(String eventType, [EventCallback? callback]) {
    if (callback == null) {
      _listeners.remove(eventType);
    } else {
      _listeners[eventType]?.remove(callback);
    }
  }

  void emit(String eventType, Event event) {
    final callbacks = _listeners[eventType] ?? [];
    for (final cb in callbacks) {
      cb(event);
    }
  }

  void clear() => _listeners.clear();
}

/// ==================== 所有常量 100% 对齐后端 Go ====================

/// Delivery 类型（路由类型） - 完全对齐后端 const DeliveryXXX
class WSDelivery {
  static const String single    = 'single';    // 单聊
  static const String group     = 'group';     // 群聊
  static const String broadcast = 'broadcast'; // 广播
}

/// 消息类型 - 完全对齐后端 TypeXXX 常量
class WSEventType {
  // 基础消息
  static const String message       = 'message';       // 普通文本消息
  static const String systemNotice  = 'system_notice'; // 系统通知

  // 用户状态
  static const String userOnline    = 'user_online';
  static const String userOffline   = 'user_offline';

  // 多媒体
  static const String voice         = 'voice';         // 语音
  static const String video         = 'video';         // 视频
  static const String file          = 'file';          // 文件
  static const String emoji         = 'emoji';         // 表情包
  static const String invite         = 'invite';         // 链接
  static const String image         = 'image';         // 链接

  // 业务消息
  static const String redPacket     = 'red_packet';     // 红包
  static const String transfer     = 'transfer';     // 转账
  static const String businessCard     = 'business_card';     // 名片
  static const String withdraw     = 'withdraw';     // 撤回
  static const String typing        = 'typing';         // 正在输入

  // 控制消息（客户端 → 服务端）
  static const String ping          = 'ping';
  static const String pong          = 'pong';
  static const String switchUser    = 'switch_user';    // 切换用户（最重要！）

  // 服务端 → 客户端的回执
  static const String authSuccess   = 'auth_success';   // 登录成功（后端会发）
  static const String authFailed    = 'auth_failed';    // 登录失败
  static const String conversationListSync    = 'conversation_list_sync';    // 会话列表

  // 事件消息
  static const String follow    = 'follow';    // 关注
  static const String unFollow    = 'unfollow';    // 取消关注
}

/// 消息状态（可选，用于 UI 显示）
class WSMessageStatus {
  static const String sending = 'sending';
  static const String sent    = 'sent';
  static const String read    = 'read';
  static const String failed  = 'failed';
}