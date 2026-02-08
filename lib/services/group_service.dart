import 'package:education/services/api_service.dart';

class GroupApi {
  final ApiClient _client = ApiClient();

  Future<Map<String, dynamic>> createGroup(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/create", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> getGroupMembers(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/getGroupMember", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> getGroupInfo(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/getGroupInfo", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> updateGroupInfo(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/updateGroupInfo", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> getGroupMemberIds(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/getGroupMemberIds", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> addGroupMember(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/addGroupMember", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> removeGroupMember(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/removeGroupMember", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> handleGroupManager(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/handleGroupManager", data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  Future<Map<String, dynamic>> getOfflineMessageList(Map<String, dynamic> data) async {
    final resp = await _client.post("/v1/group/getOfflineMessageList", data: data);
    return ApiClient.getDataOrThrow(resp);
  }
}
