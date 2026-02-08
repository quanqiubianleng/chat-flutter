import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:education/config/app_env.dart';

Future<bool> isAndroidEmulator() async {
  if (!Platform.isAndroid) return false;
  final info = await DeviceInfoPlugin().androidInfo;
  return !info.isPhysicalDevice;
}

/// WS 地址：优先使用当前环境配置；模拟器时可选替换为 10.0.2.2
Future<String> getWsUrl() async {
  final base = currentEnv.wsUrl;
  if (Platform.isAndroid && await isAndroidEmulator()) {
    // 可选：本地调试时用模拟器指向宿主
    // return base.replaceFirst(RegExp(r'[\d.]+'), '10.0.2.2');
  }
  return base;
}

class AppConfig {
  static const title = "BBT";
  static late String wsUrl;
  static late String reqUrl;
  static late String agreeUrl;
  static late String privacyUrl;
  static late bool isDebug;

  static Future<void> init() async {
    final env = currentEnv;
    wsUrl = await getWsUrl();
    reqUrl = env.reqUrl;
    agreeUrl = env.agreeUrl;
    privacyUrl = env.privacyUrl;
    isDebug = env.isDebug;
  }
}

class HttpStatus {
  static const success = 200;
  static const fail = 201;
}
