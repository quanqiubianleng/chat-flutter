import 'package:education/services/public_service.dart';

/// OSS URL 解析与刷新工具
/// 用于解决 STS 签名 URL 过期（403）问题：从 URL 解析 objectKey，请求后端生成新签名 URL
class OssUrlHelper {
  /// 判断是否为 OSS 签名 URL（含 x-oss- 等参数，过期后会 403）
  static bool isOssSignedUrl(String url) {
    if (url.isEmpty) return false;
    return url.contains('x-oss-') ||
        url.contains('x-oss-credential') ||
        url.contains('OSSAccessKeyId');
  }

  /// 从 OSS URL 解析 objectKey
  /// 格式: https://bucket.endpoint/objectKey?x-oss-...
  /// 或: https://bucket.oss-accelerate.aliyuncs.com/images/2026/02/09/xxx.jpg?...
  static String? parseObjectKey(String url) {
    if (url.isEmpty) return null;
    try {
      final uri = Uri.parse(url);
      final path = uri.path;
      if (path.isEmpty || path == '/') return null;
      // 去掉开头的 /
      return path.startsWith('/') ? path.substring(1) : path;
    } catch (_) {
      return null;
    }
  }

  /// 刷新过期的 OSS 签名 URL
  /// 若 objectKey 解析失败或接口失败，返回 null
  static Future<String?> refreshSignedUrl(String oldUrl) async {
    final objectKey = parseObjectKey(oldUrl);
    if (objectKey == null || objectKey.isEmpty) return null;
    try {
      return await PublicApi().getOssSignedUrl(objectKey);
    } catch (_) {
      return null;
    }
  }
}
