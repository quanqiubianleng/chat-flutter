import 'package:education/core/sqlite/database_helper.dart';
import 'package:education/core/sqlite/message_repository.dart';
import 'package:education/core/utils/conversation.dart';
import 'package:education/core/utils/logger.dart';
import 'package:education/modules/chat/models/group.dart';
import 'package:education/services/group_service.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/user/user.dart';

/// 会话列表空昵称/空头像统一补全服务。
/// 在列表展示时调用 [fillIfNeeded]，
/// 对 title 或 avatar 为空的会话按需拉取用户/群信息并回写，带防抖、去重与并发限制。
class ConversationFillService {
  ConversationFillService({
    required MessageRepository messageRepository,
    required UserApi userApi,
    required GroupApi groupApi,
  })  : _messageRepository = messageRepository,
        _userApi = userApi,
        _groupApi = groupApi;

  final MessageRepository _messageRepository;
  final UserApi _userApi;
  final GroupApi _groupApi;

  /// 已发起过补全的会话 ID，避免重复请求（失败不移除，避免刷屏重试）
  final Set<String> _requestedConvIds = {};
  /// 当前正在执行的补全数量
  int _inFlight = 0;
  /// 待补全队列：(convId, type)
  final List<_ConvToFill> _queue = [];
  static const int _maxConcurrent = 2;

  /// 对会话列表里 title 或 avatar 为空的会话触发补全（去重 + 最多 2 个并发）。
  void fillIfNeeded(List<Conversation> conversations, int currentUserId) {
    if (currentUserId <= 0) return;

    for (final conv in conversations) {
      final convId = conv.serverConversationId;
      if (convId.isEmpty) continue;
      final needFill =
          conv.title.trim().isEmpty || conv.avatar.trim().isEmpty;
      if (!needFill) continue;
      if (_requestedConvIds.contains(convId)) continue;

      _requestedConvIds.add(convId);
      _queue.add(_ConvToFill(convId, conv.type));
    }

    _drainQueue(currentUserId);
  }

  void _drainQueue(int currentUserId) {
    while (_inFlight < _maxConcurrent && _queue.isNotEmpty) {
      final item = _queue.removeAt(0);
      _inFlight++;
      _fillOne(item.convId, item.type, currentUserId).whenComplete(() {
        _inFlight--;
        _drainQueue(currentUserId);
      });
    }
  }

  Future<void> _fillOne(String convId, String type, int currentUserId) async {
    try {
      if (type == 'single') {
        final otherUserId = tryParseOtherUserIdFromConvId(convId, currentUserId);
        if (otherUserId == null || otherUserId <= 0) {
          AppLogger.d('ConversationFill: skip single conv, invalid convId or userId: $convId');
          return;
        }
        final userInfo = await _userApi.getUserOtherInfo({'userId': otherUserId});
        final user = User.fromMap(userInfo);
        final title = user.username.trim().isEmpty ? '用户$otherUserId' : user.username;
        final avatar = user.avatarUrl.trim();
        await _messageRepository.updateConvTitle(convId, title);
        if (avatar.isNotEmpty) {
          await _messageRepository.updateConvAvatar(convId, avatar);
        }
        AppLogger.d('ConversationFill: single conv filled: $convId -> $title');
      } else if (type == 'group') {
        final groupId = tryParseGroupIdFromConvId(convId);
        if (groupId == null || groupId <= 0) {
          AppLogger.d('ConversationFill: skip group conv, invalid convId: $convId');
          return;
        }
        final groupInfoMap = await _groupApi.getGroupInfo({'group_id': groupId});
        final groupInfo = GroupInfo.fromJson(groupInfoMap);
        final title = groupInfo.Name.trim().isEmpty ? '群聊' : groupInfo.Name;
        final avatar = groupInfo.Avatar.trim();
        await _messageRepository.updateConvTitle(convId, title);
        if (avatar.isNotEmpty) {
          await _messageRepository.updateConvAvatar(convId, avatar);
        }
        AppLogger.d('ConversationFill: group conv filled: $convId -> $title');
      }
    } catch (e, st) {
      AppLogger.e('ConversationFill: fill failed convId=$convId type=$type', e, st);
    }
  }
}

class _ConvToFill {
  final String convId;
  final String type;
  _ConvToFill(this.convId, this.type);
}
