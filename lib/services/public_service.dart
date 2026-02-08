import 'package:education/services/api_service.dart';

class PublicApi {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> getOssSts(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/oss/sts", data: data);
    return ApiClient.getDataOrThrow(resp);
  }
}
