import './api_service.dart';

class GroupApi {
  final ApiClient _client = ApiClient();

  /// 添加群组
  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/create", data: data);
    return resp.data;
  }

  /// 获取群组成员
  Future<Map<String, dynamic>> getGroupMembers(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/getGroupMember", data: data);
    return resp.data;
  }

  /// 获取群组信息
  Future<Map<String, dynamic>> getGroupInfo(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/getGroupInfo", data: data);
    return resp.data;
  }

  /// 更新群组信息
  Future<Map<String, dynamic>> updateGroupInfo(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/updateGroupInfo", data: data);
    return resp.data;
  }

  /// 获取群组成员ids
  Future<Map<String, dynamic>> getGroupMemberIds(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/getGroupMemberIds", data: data);
    return resp.data;
  }

  /// 添加群组成员ids
  Future<Map<String, dynamic>> addGroupMember(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/addGroupMember", data: data);
    return resp.data;
  }

  /// 移除群组成员
  Future<Map<String, dynamic>> removeGroupMember(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/removeGroupMember", data: data);
    return resp.data;
  }

  /// 移除、添加管理员
  Future<Map<String, dynamic>> handleGroupManager(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/handleGroupManager", data: data);
    return resp.data;
  }

  /// 获取离线、同步消息
  Future<Map<String, dynamic>> getOfflineMessageList(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/getOfflineMessageList", data: data);
    return resp.data;
  }
}
