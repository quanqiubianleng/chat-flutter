import './websocket/ws_service.dart';
import './websocket/ws_event.dart';
import 'package:education/config/app_config.dart';

final eventBus = WSEventBus();
final ws = WSService(url: AppConfig.wsUrl, eventBus: eventBus);