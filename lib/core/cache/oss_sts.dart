import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/public_service.dart';

// STS 凭证的 Dart 数据模型（与你后端返回的结构对应）
class OssStsCredentials {
  final String accessKeyId;
  final String accessKeySecret;
  final String securityToken;
  final String expiration; // ISO8601 格式，例如 "2025-12-29T08:43:30Z"

  OssStsCredentials({
    required this.accessKeyId,
    required this.accessKeySecret,
    required this.securityToken,
    required this.expiration,
  });

  // 从 JSON 构造
  factory OssStsCredentials.fromJson(Map<String, dynamic> json) {
    return OssStsCredentials(
      accessKeyId: json['AccessKeyId'] as String,
      accessKeySecret: json['AccessKeySecret'] as String,
      securityToken: json['SecurityToken'] as String,
      expiration: json['Expiration'] as String,
    );
  }

  // 转成 JSON
  Map<String, dynamic> toJson() {
    return {
      'AccessKeyId': accessKeyId,
      'AccessKeySecret': accessKeySecret,
      'SecurityToken': securityToken,
      'Expiration': expiration,
    };
  }

  // 转成 JSON 字符串（方便存储）
  String toJsonString() => jsonEncode(toJson());
}

class OssStsCache {
  static const _ossStsKey = 'oss_sts';

  /// 保存 STS 凭证到本地缓存
  static Future<void> saveOssSts(OssStsCredentials credentials) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ossStsKey, credentials.toJsonString());
  }

  /// 读取缓存的 STS 凭证，如果没有返回 null
  static Future<OssStsCredentials?> getOssSts() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_ossStsKey);
    if (jsonString == null || jsonString.isEmpty) {
      return null;
    }
    try {
      final jsonMap = jsonDecode(jsonString) as Map<String, dynamic>;
      return OssStsCredentials.fromJson(jsonMap);
    } catch (e) {
      // 如果解析失败（数据损坏），返回 null
      print('Failed to parse cached STS credentials: $e');
      return null;
    }
  }

  /// 清空缓存（比如登出或凭证失效时使用）
  static Future<void> clearOssSts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_ossStsKey);
  }

  /// 检查缓存的凭证是否已过期
  /// 返回 true 表示过期或无缓存，false 表示有效
  static Future<bool> isStsExpired() async {
    final credentials = await getOssSts();
    if (credentials == null) return true;

    try {
      final expirationTime = DateTime.parse(credentials.expiration);
      return DateTime.now().isAfter(expirationTime);
    } catch (e) {
      print('Invalid expiration format: $e');
      return true; // 格式不对也认为过期
    }
  }

  /// 获取有效的 STS 凭证（优先缓存，未过期则直接返回；否则请求后端并缓存）
  static Future<OssStsCredentials> getValidStsCredentials() async {
    // 先检查缓存是否有效
    if (!await isStsExpired()) {
      final cached = await getOssSts();
      if (cached != null) {
        return cached;
      }
    }

    // 缓存无效或不存在 → 请求后端
    final pub = PublicApi();
    try {
      final response = await pub.getOssSts({});
      // 假设后端返回格式是小写键（如 accessKeyId）
      final credentials = OssStsCredentials(
        accessKeyId: response['accessKeyId'],
        accessKeySecret: response['accessKeySecret'],
        securityToken: response['securityToken'],
        expiration: response['expiration'],
      );

      await saveOssSts(credentials);
      return credentials;
    } catch (e) {
      print('获取 STS 失败: $e');
      rethrow; // 上传时会失败，建议在外层处理
    }
  }
}
