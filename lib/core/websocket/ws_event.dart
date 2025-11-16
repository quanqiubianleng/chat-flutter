typedef EventCallback = void Function(dynamic message);

class WSEventBus {
  final Map<String, List<EventCallback>> _listeners = {};

  /// 监听事件
  void on(String eventType, EventCallback callback) {
    _listeners.putIfAbsent(eventType, () => []).add(callback);
  }

  /// 移除事件监听
  void off(String eventType, [EventCallback? callback]) {
    if (callback == null) {
      _listeners.remove(eventType);
    } else {
      _listeners[eventType]?.remove(callback);
    }
  }

  /// 派发事件
  void emit(String eventType, dynamic message) {
    final callbacks = _listeners[eventType];
    if (callbacks != null) {
      for (var cb in callbacks) {
        cb(message);
      }
    }
  }

  /// 清空所有事件
  void clear() => _listeners.clear();
}

/// 内置事件类型
class WSEventType {
  static const String chat = 'chat';
  static const String userOnline = 'user_online';
  static const String userOffline = 'user_offline';
  static const String systemNotice = 'system_notice';
  static const String groupMessage = 'group_message';
  static const String ping = 'ping';
  static const String pong = 'pong';  // 如果后端会发
}
