/// 生成一个客户端临时的 conversationId（负数）
///
/// 参数：
/// - userIdA: 当前用户 ID
/// - userIdB: 对方用户 ID（单聊） 或 groupId（群聊）
/// - isGroup: 是否群聊
String generateTempConversationId({
  required int userIdA,
  required int userIdB,
  bool isGroup = false,
}) {
  if (isGroup) {
    // 群聊：格式 "temp_group_负groupId"
    return "temp_group_${userIdB.abs()}";
  } else {
    // 单聊：确保排序一致
    final min = userIdA < userIdB ? userIdA : userIdB;
    final max = userIdA > userIdB ? userIdA : userIdB;

    return "temp_single_${min}_${max}";
  }
}

/// 根据会话ID获取userID（单聊 temp_single_min_max）
int getUserIDsByConversationId(String conversationId, int userId) {
  List<String> parts = conversationId.split('_');
  if (parts.length < 4) return 0;
  final a = int.tryParse(parts[2]);
  final b = int.tryParse(parts[3]);
  if (a == null || b == null) return 0;
  return a == userId ? b : a;
}

/// 根据会话ID获取groupId（群聊 temp_group_id）
int getGroupIdByConversationId(String conversationId) {
  List<String> parts = conversationId.split('_');
  if (parts.length < 3) return 0;
  return int.tryParse(parts[2]) ?? 0;
}

/// 安全解析：单聊时返回对方 userId，解析失败返回 null
int? tryParseOtherUserIdFromConvId(String conversationId, int currentUserId) {
  if (conversationId.isEmpty) return null;
  final parts = conversationId.split('_');
  if (parts.length < 4 || parts[1] != 'single') return null;
  final a = int.tryParse(parts[2]);
  final b = int.tryParse(parts[3]);
  if (a == null || b == null) return null;
  return a == currentUserId ? b : a;
}

/// 安全解析：群聊时返回 groupId，解析失败返回 null
int? tryParseGroupIdFromConvId(String conversationId) {
  if (conversationId.isEmpty) return null;
  final parts = conversationId.split('_');
  if (parts.length < 3 || parts[1] != 'group') return null;
  return int.tryParse(parts[2]);
}