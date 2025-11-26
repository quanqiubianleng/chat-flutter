import './api_service.dart';

class UserApi {
  final ApiClient _client = ApiClient();

  /// 导入钱包
  Future<Map<String, dynamic>> importWallet(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/wallet/import", data: data);
    return resp.data;
  }

  /// 创建钱包
  Future<Map<String, dynamic>> createWallet(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/wallet/create", data: data);
    return resp.data;
  }

  /// 获取用户信息
  Future<Map<String, dynamic>> getUserInfo([Map<String, dynamic>? query]) async {
    final resp = await _client.get("/v1/users", query: query);
    return resp.data;
  }

  /// 关注用户
  Future<Map<String, dynamic>> follower(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/follower", data: data);
    return resp.data;
  }
}
