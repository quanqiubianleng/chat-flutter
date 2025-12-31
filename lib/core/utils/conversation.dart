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
    return "temp_group_-${userIdB.abs()}";
  } else {
    // 单聊：确保排序一致
    final min = userIdA < userIdB ? userIdA : userIdB;
    final max = userIdA > userIdB ? userIdA : userIdB;

    return "temp_single_${min}_${max}";
  }
}

/// 根据会话ID获取userID
int getUserIDsByConversationId(String conversationId, int userId){
  List<String> parts = conversationId.split('_');
  if(int.parse(parts[2]) == userId){
    return int.parse(parts[3]);
  }
  return int.parse(parts[2]);
}