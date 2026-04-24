import 'dart:convert';
import 'dart:io';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:education/config/app_env.dart';
import 'package:education/core/utils/logger.dart';
import 'package:http/http.dart' as http;

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
  static const String _prodDomainJsonUrl = String.fromEnvironment(
    'PROD_DOMAIN_JSON_URL',
    defaultValue: '',
  );
  static late String wsUrl;
  static late String reqUrl;
  static late String agreeUrl;
  static late String privacyUrl;
  static late String newbieGuideUrl;
  static late bool isDebug;

  static Future<void> init() async {
    final env = currentEnv;
    wsUrl = await getWsUrl();
    reqUrl = env.reqUrl;
    if (kAppEnv == AppEnv.prod) {
      reqUrl = await _loadProdReqUrlFromOss(defaultReqUrl: reqUrl);
    }
    agreeUrl = env.agreeUrl;
    privacyUrl = env.privacyUrl;
    newbieGuideUrl = env.newbieGuideUrl;
    isDebug = env.isDebug;
  }

  static Future<String> _loadProdReqUrlFromOss({
    required String defaultReqUrl,
  }) async {
    if (_prodDomainJsonUrl.isEmpty) {
      AppLogger.w(
        '[APP_BOOT] PROD_DOMAIN_JSON_URL is empty, use default reqUrl',
      );
      return defaultReqUrl;
    }

    final uri = Uri.tryParse(_prodDomainJsonUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      AppLogger.w(
        '[APP_BOOT] PROD_DOMAIN_JSON_URL is invalid, use default reqUrl',
      );
      return defaultReqUrl;
    }

    try {
      final resp = await http.get(uri).timeout(const Duration(seconds: 8));
      if (resp.statusCode != 200) {
        AppLogger.w(
          '[APP_BOOT] fetch prod json failed(status=${resp.statusCode}), use default reqUrl',
        );
        return defaultReqUrl;
      }

      final data = jsonDecode(resp.body);
      if (data is! Map<String, dynamic>) {
        AppLogger.w(
          '[APP_BOOT] prod json format invalid, use default reqUrl',
        );
        return defaultReqUrl;
      }

      final reqUrlFromJson = data['reqUrl']?.toString().trim() ?? '';
      if (reqUrlFromJson.isEmpty) {
        AppLogger.w(
          '[APP_BOOT] reqUrl missing in prod json, use default reqUrl',
        );
        return defaultReqUrl;
      }

      AppLogger.i('[APP_BOOT] reqUrl loaded from $_prodDomainJsonUrl');
      return reqUrlFromJson;
    } catch (e, st) {
      AppLogger.w(
        '[APP_BOOT] read prod json failed, use default reqUrl',
        e,
        st,
      );
      return defaultReqUrl;
    }
  }
}

class HttpStatus {
  static const success = 200;
  static const fail = 201;
}
