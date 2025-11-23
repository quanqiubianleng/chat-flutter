import 'package:education/config/app_config.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/global.dart';
import 'package:education/core/websocket/ws_event.dart';
import 'package:education/core/websocket/ws_service.dart';
import 'package:education/core/websocket/ws_message.dart';
import 'package:fixnum/src/int64.dart';
import 'package:flutter/material.dart';
import 'config/proto_registry.dart';
import './pb/protos/chat.pb.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized(); // ✅ 必须先调用

  initProtoRegistry();   // 注册所有 ProtoBuf 消息

  runApp(const MyApp());

  await UserCache.saveToken('ddddddddddd');
  await UserCache.saveUserId(1);

  
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();

    // 启动 WebSocket
    ws.connect();

    // 注册事件
    eventBus.on(WSEventType.chat, (msg) {
      if (msg is Event) {
        print("收到聊天: ${msg.content}");
      }
    });

    eventBus.on(WSEventType.ping, (msg) {
      print("收到心跳");
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: Text("WebSocket 测试")),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              final protoEvent = Event()
                ..type = 'chat'
                ..msgType = 'text'
                ..content = 'Hello'
                ..fromUser = Int64(12);

              ws.send(protoEvent); // 直接发 Event（记得你的 ws.send 支持判断是 ProtoBuf）
            },
            child: Text('发送 ProtoBuf 消息'),
          ),
        ),
      ),
    );
  }
}
