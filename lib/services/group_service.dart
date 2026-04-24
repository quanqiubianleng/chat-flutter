import 'package:education/services/api_service.dart';

class GroupApi {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/create", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> getGroupMembers(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post("/v1/group/getGroupMember", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> getGroupInfo(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/getGroupInfo", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> updateGroupInfo(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post("/v1/group/updateGroupInfo", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> getGroupMemberIds(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post("/v1/group/getGroupMemberIds", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> addGroupMember(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/addGroupMember", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> removeGroupMember(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post("/v1/group/removeGroupMember", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> handleGroupManager(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post("/v1/group/handleGroupManager", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> getOfflineMessageList(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post(
      "/v1/group/getOfflineMessageList",
      data: data,
    );
    return ApiClient.getDataOrThrow(resp);
  }

  /// 搜索群组（按名称/简介/ID 关键字）
  Future<Map<String, dynamic>> searchGroup(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/searchGroup", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 直接加入群组（适用于 join_mode=0 等免审核场景）
  Future<Map<String, dynamic>> joinGroup(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/joinGroup", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 提交入群申请（适用于 join_mode=1 审核制场景）
  Future<Map<String, dynamic>> applyJoinGroup(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/applyJoinGroup", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取群组入群申请列表（管理员/群主）
  Future<Map<String, dynamic>> getJoinApplications(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post(
      "/v1/group/getJoinApplications",
      data: data,
    );
    return ApiClient.getDataOrThrow(resp);
  }

  /// 审批入群申请
  /// action: approve / reject
  Future<Map<String, dynamic>> handleJoinApplication(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post(
      "/v1/group/handleJoinApplication",
      data: data,
    );
    return ApiClient.getDataOrThrow(resp);
  }

  /// 初始化 BBT 官方群（需登录；网关需配置 OfficialGroupOwnerUserId，OfficialGroupId=0 时才会创建）
  Future<Map<String, dynamic>> initOfficialGroup() async {
    final resp = await _client.post(
      "/v1/group/initOfficial",
      data: <String, dynamic>{},
    );
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取群扩容/升级支付配置（档位、金额、金库地址、链）
  Future<Map<String, dynamic>> getGroupBbtPayOptions() async {
    final resp = await _client.post(
      "/v1/group/getGroupBbtPayOptions",
      data: <String, dynamic>{},
    );
    return ApiClient.getDataOrThrow(resp);
  }

  /// 提交链上支付哈希并执行扩容
  Future<Map<String, dynamic>> purchaseGroupCapacity(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post(
      "/v1/group/purchaseGroupCapacity",
      data: data,
    );
    return ApiClient.getDataOrThrow(resp);
  }

  /// 提交链上支付哈希并升级 Club
  Future<Map<String, dynamic>> upgradeGroupToClub(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post("/v1/group/upgradeGroupToClub", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 列出持仓门控规则（群主/管理员）
  Future<Map<String, dynamic>> listGroupGateRules(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post(
      "/v1/group/listGroupGateRules",
      data: data,
    );
    return ApiClient.getDataOrThrow(resp);
  }

  /// 全量保存持仓门控规则（群主/管理员；多条为 AND）
  Future<Map<String, dynamic>> setGroupGateRules(
    Map<String, dynamic> data,
  ) async {
    final resp = await _client.post(
      "/v1/group/setGroupGateRules",
      data: data,
    );
    return ApiClient.getDataOrThrow(resp);
  }
}
