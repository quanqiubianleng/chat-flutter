import 'package:education/services/api_service.dart';

class PublicApi {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> getOssSts(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/oss/sts", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 根据 objectKey 获取新的签名 URL（用于刷新过期的 STS 签名 URL）
  Future<String> getOssSignedUrl(String objectKey) async {
    final resp = await _client.post("/v1/oss/signedUrl", data: {'objectKey': objectKey});
    final data = ApiClient.getDataOrThrow(resp);
    return (data['url'] as String?) ?? '';
  }
}
