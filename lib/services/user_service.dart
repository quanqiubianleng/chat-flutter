import 'package:education/services/api_service.dart';

class UserApi {
  final ApiClient _client = ApiClient();

  /// 导入钱包
  Future<Map<String, dynamic>> importWallet(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/wallet/import", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 创建钱包
  Future<Map<String, dynamic>> createWallet(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/wallet/create", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取用户信息
  Future<Map<String, dynamic>> getUserInfo([Map<String, dynamic>? query]) async {
    final resp = await _client.get("/v1/users/userInfo", data: query);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取其他用户信息
  Future<Map<String, dynamic>> getUserOtherInfo([Map<String, dynamic>? query]) async {
    final resp = await _client.get("/v1/users/userOtherInfo", data: query);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 关注用户
  Future<Map<String, dynamic>> follower(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/follower", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取关注我、我关注的列表
  Future<Map<String, dynamic>> getFollowerList(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/getFollowerList", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取好友
  Future<Map<String, dynamic>> getMyFriend(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/getMyFriend", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取当前设备下的账号
  Future<Map<String, dynamic>> getAccountDevice(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/getAccountDevice", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 切换账号
  Future<Map<String, dynamic>> changeAccount(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/changeAccount", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 搜索账号
  Future<Map<String, dynamic>> searchAccount(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/searchAccount", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 同步关注数据
  Future<Map<String, dynamic>> getFollowerData(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/getFollowerData", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 保存用户信息（昵称、简介、头像、背景等），接口路径与参数由你后续完善
  Future<Map<String, dynamic>> updateUserInfo(Map<String, dynamic> data) async {
    // TODO: 替换为实际保存信息接口路径，如 POST /v1/users/updateUserInfo
    final resp = await _client.post("/v1/users/updateUserInfo", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 移除账号
  Future<Map<String, dynamic>> removeAccount(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/removeAccount", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 重置密码
  Future<Map<String, dynamic>> resetPassword(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/resetPassword", data: data);
    return ApiClient.getDataOrThrow(resp);
  }
}
