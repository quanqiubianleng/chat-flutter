// lib/core/websocket/ws_service.dart  → 保留我上面给你的单例代码不变

// lib/core/global.dart 或新建一个文件 lib/core/instances.dart
import 'websocket/ws_service.dart';
import 'package:education/config/app_config.dart';
import 'package:sqflite/sqflite.dart';

late final WSService ws;   // 全局唯一实例

Future<void> initGlobalServices() async {
  ws = WSService.instance;
  
  // 通过 setter 或 config 方法设置 URL（我偷偷给你加了一个）
  ws.configure(
    baseUrl: AppConfig.wsUrl,
    heartbeatInterval: const Duration(seconds: 15),
    reconnectDelay: const Duration(seconds: 5),
  );

  await ws.initAndConnect();  // 立即连接
}

class Global {
  static Database? _db;
  static Database get db {
    if (_db == null) {
      throw StateError('Database not initialized');
    }
    return _db!;
  }

  static set db(Database database) {
    _db = database;
  }

  static int? currentUserId;
}