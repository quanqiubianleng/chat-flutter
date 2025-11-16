import 'dart:async';
import 'package:education/core/websocket/ws_event.dart';
import 'package:education/pb/protos/chat.pb.dart';
import 'package:fixnum/fixnum.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../cache/user_cache.dart';
import 'package:education/pb/protos/chat.pb.dart';

enum WSStatus { disconnected, connecting, connected }

class WSService {
  final String url;
  final Duration heartbeatInterval;
  final Duration reconnectInterval;

  WebSocketChannel? _channel;
  WSStatus _status = WSStatus.disconnected;

  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;

  final List<Event> _queue = [];
  final Map<String, List<void Function(Event)>> _listeners = {};

  WSStatus get status => _status;

  WSService({
    required this.url,
    this.heartbeatInterval = const Duration(seconds: 10),
    this.reconnectInterval = const Duration(seconds: 5), required WSEventBus eventBus,
  });

  // -------------------------- Connect --------------------------
  void connect() async {
    if (_status != WSStatus.disconnected) return;

    _status = WSStatus.connecting;

    try {
      final token = await UserCache.getToken();
      if (token == null) throw Exception('Token missing');

      final connectUrl = '$url?token=$token';
      _channel = WebSocketChannel.connect(Uri.parse(connectUrl));

      _status = WSStatus.connected;
      print("WS connected");

      _startHeartbeat();
      _listen();
      _flushQueue();

    } catch (e) {
      print("WS connect error: $e");
      _status = WSStatus.disconnected;
      _scheduleReconnect();
    }
  }

  // -------------------------- Listen --------------------------
  void _listen() {
    _channel?.stream.listen(
      (data) {
        try {
          // 后端发送的是纯 protobuf
          final event = Event.fromBuffer(data);
          _emit(event);
        } catch (e) {
          print("WS decode error: $e");
        }
      },
      onDone: () {
        print("WS closed");
        _status = WSStatus.disconnected;
        _scheduleReconnect();
      },
      onError: (err) {
        print("WS error: $err");
        _status = WSStatus.disconnected;
        _scheduleReconnect();
      },
    );
  }

  // -------------------------- Send Proto --------------------------
  void send(Event event) {
    if (_status != WSStatus.connected) {
      _queue.add(event);
      return;
    }

    _channel?.sink.add(event.writeToBuffer());
  }

  // -------------------------- EventBus --------------------------
  void on(String type, void Function(Event) cb) {
    _listeners.putIfAbsent(type, () => []).add(cb);
  }

  void _emit(Event event) {
    final list = _listeners[event.type];
    if (list != null) {
      for (var cb in list) {
        cb(event);
      }
    }
  }

  // -------------------------- Heartbeat --------------------------
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(heartbeatInterval, (_) {
      if (_status == WSStatus.connected) {
        final hb = Event()
          ..type = "ping"
          ..timestamp = Int64(DateTime.now().millisecondsSinceEpoch);

        send(hb);
      }
    });
  }

  // -------------------------- Reconnect --------------------------
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive ?? false) return;

    _reconnectTimer = Timer(reconnectInterval, () {
      print("WS reconnecting...");
      connect();
    });
  }

  // -------------------------- Queue --------------------------
  void _flushQueue() {
    for (var msg in _queue) {
      send(msg);
    }
    _queue.clear();
  }

  // -------------------------- Dispose --------------------------
  void disconnect() {
    _heartbeatTimer?.cancel();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _status = WSStatus.disconnected;
  }

  void dispose() {
    disconnect();
    _listeners.clear();
    _queue.clear();
  }
}
