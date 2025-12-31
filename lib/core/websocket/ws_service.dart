// lib/core/websocket/ws_service.dart

import 'dart:async';
import 'dart:io';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/websocket/ws_event.dart';
import 'package:education/pb/protos/chat.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

enum WSStatus { disconnected, connecting, connected }

class WSService {
  // 单例
  static final WSService instance = WSService._internal();
  factory WSService() => instance;
  WSService._internal();

  String? _baseUrl;
  Duration _heartbeatInterval = const Duration(seconds: 15);
  Duration _reconnectDelay = const Duration(seconds: 5);

  String get baseUrl {
    if (_baseUrl == null) {
      throw StateError("WSService 未配置 baseUrl，请先调用 configure()");
    }
    return _baseUrl!;
  }

  Duration get heartbeatInterval => _heartbeatInterval;
  Duration get reconnectDelay => _reconnectDelay;

  WebSocketChannel? _channel;
  WSStatus _status = WSStatus.disconnected;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final List<Event> _sendQueue = [];
  final Map<String, List<void Function(Event)>> _listeners = {};
  /// 新增：全局监听（所有消息都会走到）
final List<void Function(Event)> _allListeners = [];

  WSStatus get status => _status;

  void configure({
    required String baseUrl,
    Duration? heartbeatInterval,
    Duration? reconnectDelay,
  }) {
    _baseUrl = baseUrl;
    if (heartbeatInterval != null) _heartbeatInterval = heartbeatInterval;
    if (reconnectDelay != null) _reconnectDelay = reconnectDelay;
  }

  Future<void> initAndConnect() async {
    if (_status == WSStatus.connecting || _status == WSStatus.connected) {
      return;
    }
    await _connect();
  }

  Future<void> _connect() async {
    if (_status == WSStatus.connecting) return;

    _status = WSStatus.connecting;
    _cancelReconnect();

    try {
      final token = await UserCache.getToken();
      if (token == null || token.isEmpty) {
        print("WS 连接失败：token 为空");
        _status = WSStatus.disconnected;
        return;
      }

      final userId = await UserCache.getUserId() ?? 0;
      final url = '$baseUrl?token=$token&user_id=$userId';

      _channel = WebSocketChannel.connect(Uri.parse(url));
      await _channel!.ready;

      _status = WSStatus.connected;
      print("WebSocket 已连接 (userId: $userId)");

      _startHeartbeat();
      _listenStream();
      _flushQueue();

      if (userId > 0) {
        // 连接成功后主动发送 switch_user
        _sendSwitchUser();
      }

    } catch (e) {
      print("WS 连接异常: $e");
      _status = WSStatus.disconnected;
      _scheduleReconnect();
    }
  }

  void _listenStream() {
    _channel?.stream.listen(
      (data) {
        try {
          // data 是 List<int>（二进制）
          final event = Event.fromBuffer(data as List<int>);
          _emit(event.type, event);

          if (event.type == 'pong') {
            print("收到 pong");
          }
        } catch (e) {
          print("ProtoBuf 解析失败: $e");
        }
      },
      onDone: () {
        print("WS 连接断开");
        _status = WSStatus.disconnected;
        _scheduleReconnect();
      },
      onError: (err) {
        print("WS 错误: $err");
        _status = WSStatus.disconnected;
        _scheduleReconnect();
      },
    );
  }

  // 主动发送 switch_user（登录/切换账号时必须）
  Future<void> _sendSwitchUser() async {
    final userId = await UserCache.getUserId() ?? 0;
    final did = await UserCache.getDid() ?? '';

    final event = Event()
    ..delivery = WSDelivery.single                               // 关键！必须填 delivery
    ..type = WSEventType.switchUser                            // 保持
    ..fromUser = Int64(userId)
    ..toUser = Int64(userId)                             // 强烈建议：to_user 也填自己，方便后端路由
    ..content = did                                      // did 放 content 也可以（后端很多项目都这么干）
    ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch)
    ..clientMsgId = 'switch_user_${DateTime.now().millisecondsSinceEpoch}'; // 可选，方便排查

    send(event);
    print("已发送 switch_user (userId=$userId, did=$did)");
  }

  // 公开的切换账号方法（不重连，直接发 switch_user）
  Future<void> switchAccount() async {
    if (_status != WSStatus.connected) {
      await initAndConnect();
      return;
    }
    await _sendSwitchUser();
  }

  // 发送任意 Event（全部走 ProtoBuf）
  void send(Event event) {
    if (_status != WSStatus.connected || _channel == null) {
      _sendQueue.add(event);
      print("WS 未连接，加入队列（${_sendQueue.length} 条）");
      return;
    }

    try {
      _channel!.sink.add(event.writeToBuffer());
    } catch (e) {
      print("发送失败，加入队列: $e");
      _sendQueue.add(event);
    }
  }

  // 事件监听
  void on(String type, void Function(Event) callback) {
    _listeners.putIfAbsent(type, () => []).add(callback);
  }

  void off(String type, [void Function(Event)? callback]) {
    if (callback == null) {
      _listeners.remove(type);
    } else {
      _listeners[type]?.remove(callback);
    }
  }

  void onAll(void Function(Event) callback) {
    _allListeners.add(callback);
  }

  void offAll([void Function(Event)? callback]) {
    if (callback == null) {
      _allListeners.clear();
    } else {
      _allListeners.remove(callback);
    }
  }

  void _emit(String type, Event event) {
    // 1. 具体 type 的监听
    final callbacks = _listeners[type];
    if (callbacks != null) {
      for (var cb in callbacks) cb(event);
    }

    // 2. 全局监听（所有消息都触发）
    for (var cb in List.from(_allListeners)) {
      try {
        cb(event);
      } catch (e) {
        print('全局监听回调异常: $e');
      }
    }
  }

  // 心跳
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_status == WSStatus.connected) {
        final ping = Event()
          ..type = 'ping'
          ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch);
        send(ping);
      }
    });
  }

  // 重连
  void _scheduleReconnect() {
    _cancelReconnect();
    _reconnectTimer = Timer(reconnectDelay, () {
      print("尝试重连 WebSocket...");
      _connect();
    });
  }

  void _cancelReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  void _flushQueue() {
    if (_sendQueue.isEmpty) return;
    print("刷新队列：${_sendQueue.length} 条");
    final copy = List<Event>.from(_sendQueue);
    _sendQueue.clear();
    for (final msg in copy) {
      send(msg);
    }
  }

  // 手动断开（退出登录）
  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _status = WSStatus.disconnected;
    _sendQueue.clear();
    print("WebSocket 已手动断开");
  }
}

// 全局快捷实例
final ws = WSService.instance;