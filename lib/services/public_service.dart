import './api_service.dart';

class PublicApi {
  final ApiClient _client = ApiClient();

  /// 搜索账号
  Future<Map<String, dynamic>> getOssSts(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/oss/sts", data: data);
    return resp.data;
  }
}
