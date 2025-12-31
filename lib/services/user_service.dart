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
    final resp = await _client.get("/v1/users/userInfo", data: query);
    return resp.data;
  }

  /// 关注用户
  Future<Map<String, dynamic>> follower(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/follower", data: data);
    return resp.data;
  }

  /// 获取当前设备下的账号
  Future<Map<String, dynamic>> getAccountDevice(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/getAccountDevice", data: data);
    return resp.data;
  }
  

  /// 切换账号
  Future<Map<String, dynamic>> changeAccount(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/changeAccount", data: data);
    return resp.data;
  }

  /// 搜索账号
  Future<Map<String, dynamic>> searchAccount(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/searchAccount", data: data);
    return resp.data;
  }
}
