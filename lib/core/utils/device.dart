import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';

class DeviceUtils {
  static final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static final Random _random = Random();
  static String? _deviceId;

  /// 获取设备唯一标识（基于密码 + 微秒时间戳 + 设备信息的MD5哈希）
  static Future<String> getDeviceId(String password) async {
    if (_deviceId != null) return _deviceId!;

    try {
      // 获取当前微秒时间戳
      final microsecondTimestamp = DateTime.now().microsecondsSinceEpoch;

      // 获取设备基本信息作为盐值
      String deviceSalt;
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceSalt = '${androidInfo.id}_${androidInfo.model}_${androidInfo.brand}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceSalt = '${iosInfo.identifierForVendor ?? 'ios_unknown'}_${iosInfo.model}_${iosInfo.systemName}';
      } else {
        deviceSalt = 'unknown_platform_${Platform.operatingSystem}';
      }

      // 添加随机盐值增加熵值
      final randomSalt = _random.nextInt(999999).toString();

      // 构建待加密的字符串：密码 + 时间戳 + 设备信息 + 随机盐
      final inputString = '$password|$microsecondTimestamp|$deviceSalt|$randomSalt';

      // 生成MD5哈希
      final bytes = utf8.encode(inputString);
      final md5Hash = md5.convert(bytes);

      _deviceId = md5Hash.toString();

    } catch (e) {
      // 如果出错，回退到简单的时间戳+密码的MD5
      final fallbackString = '$password|${DateTime.now().microsecondsSinceEpoch}';
      final fallbackHash = md5.convert(utf8.encode(fallbackString));
      _deviceId = fallbackHash.toString();
    }

    return _deviceId!;
  }
}