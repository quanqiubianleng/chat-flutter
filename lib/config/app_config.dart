import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';

Future<bool> isAndroidEmulator() async {
  if (!Platform.isAndroid) return false;

  final info = await DeviceInfoPlugin().androidInfo;

  return !info.isPhysicalDevice;
}

Future<String> getWsUrl() async {
  if (Platform.isAndroid && await isAndroidEmulator()) {
    return 'ws://10.0.2.2:8899/ws';
  }

  return 'ws://192.168.1.103:8899/ws';
}


class AppConfig {
  static late String wsUrl;
  static const reqUrl = 'http://129.211.215.59:8860';
  // 用户协议
  static const agreeUrl = 'https://uat-dev.fadada.com/api-doc/4GSRGR45LY/WEOBQWTXXXMJPCPW/5-1';
  
  // 隐私政策（强烈建议加上）
  static const privacyUrl = 'https://uat-dev.fadada.com/api-doc/4GSRGR45LY/WEOBQWTXXXMJPCPW/5-1';

  static Future<void> init() async {
    wsUrl = await getWsUrl();
  }
}
