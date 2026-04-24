import 'package:education/services/api_service.dart';

class UserApi {
  final ApiClient _client = ApiClient();

  /// 导入钱包（助记词）
  Future<Map<String, dynamic>> importWallet(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/wallet/import", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 导入私钥（EVM 链）
  Future<Map<String, dynamic>> importWalletByPrivateKey(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post("/v1/wallet/importPrivateKey", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 创建钱包
  Future<Map<String, dynamic>> createWallet(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/wallet/create", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取用户信息
  Future<Map<String, dynamic>> getUserInfo([
    Map<String, dynamic>? query,
  ]) async {
    final resp = await _client.get("/v1/users/userInfo", data: query);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 分享页数据：昵称、头像、背景、等级、动态数、关注、粉丝、分享链接
  Future<Map<String, dynamic>> getShareProfile() async {
    final resp = await _client.get("/v1/users/shareProfile");
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取其他用户信息
  Future<Map<String, dynamic>> getUserOtherInfo([
    Map<String, dynamic>? query,
  ]) async {
    final resp = await _client.get("/v1/users/userOtherInfo", data: query);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 关注用户
  Future<Map<String, dynamic>> follower(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/follower", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取关注我、我关注的列表
  Future<Map<String, dynamic>> getFollowerList(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post("/v1/users/getFollowerList", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取好友
  Future<Map<String, dynamic>> getMyFriend(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/users/getMyFriend", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取当前设备下的账号
  Future<Map<String, dynamic>> getAccountDevice(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post("/v1/users/getAccountDevice", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 转账选择联系人：当前设备用户 + 我关注的人（带关系标签）
  Future<Map<String, dynamic>> getTransferContactList(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post(
      "/v1/users/getTransferContactList",
      data: data,
    );
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
  Future<Map<String, dynamic>> getFollowerData(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post("/v1/users/getFollowerData", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 标记「关注我的」为已读（查看新增关注页后调用，同步服务端未读状态）
  Future<Map<String, dynamic>> markFollowRead() async {
    final resp = await _client.post(
      "/v1/users/markFollowRead",
      data: <String, dynamic>{},
    );
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

  /// 获取隐私设置
  Future<Map<String, dynamic>> getPrivacySettings() async {
    final resp = await _client.get("/v1/users/privacySettings");
    return ApiClient.getDataOrThrow(resp);
  }

  /// 更新隐私设置（部分字段 JSON，如 {"show_assets_publicly": false}）
  Future<Map<String, dynamic>> updatePrivacySettings(
    Map<String, dynamic> privacy,
  ) async {
    final resp = await _client.post("/v1/users/privacySettings", data: privacy);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取屏蔽用户列表
  Future<Map<String, dynamic>> getBlockedUsers() async {
    final resp = await _client.get("/v1/users/blockedUsers");
    return ApiClient.getDataOrThrow(resp);
  }

  /// 屏蔽用户
  Future<Map<String, dynamic>> blockUser(int targetUserId) async {
    final resp = await _client.post(
      "/v1/users/blockUser",
      data: {"target_user_id": targetUserId},
    );
    return ApiClient.getDataOrThrow(resp);
  }

  /// 取消屏蔽
  Future<Map<String, dynamic>> unblockUser(int targetUserId) async {
    final resp = await _client.post(
      "/v1/users/unblockUser",
      data: {"target_user_id": targetUserId},
    );
    return ApiClient.getDataOrThrow(resp);
  }

  /// 检查当前用户能否给 targetUserId 发私信（对方「谁可以私信我」+ 屏蔽）
  Future<Map<String, dynamic>> canSendPmTo(int targetUserId) async {
    final resp = await _client.get(
      "/v1/users/canSendPmTo",
      // 兼容后端未声明 json tag 的场景：同时传 snake_case + PascalCase。
      // 若后端已修正 json tag，保留 target_user_id 仍然正常。
      data: {
        "target_user_id": targetUserId,
        "TargetUserId": targetUserId,
      },
    );
    return ApiClient.getDataOrThrow(resp);
  }
}
