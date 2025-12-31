import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

class DeviceUtils {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static String? _deviceId;

  /// 获取设备唯一标识（iOS: identifierForVendor / Android: androidId）
  static Future<String> getDeviceId() async {
    if (_deviceId != null) return _deviceId!;

    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        _deviceId = androidInfo.id; // Android ID（最常用）
        // 或者用 androidInfo.androidId（Android 10+ 更稳定）
        // _deviceId = androidInfo.androidId;
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        _deviceId = iosInfo.identifierForVendor ?? 'unknown_ios_device';
      } else {
        _deviceId = 'unknown_device';
      }
    } catch (e) {
      _deviceId = 'unknown_device_$e';
    }

    return _deviceId!;
  }
}