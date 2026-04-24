import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixnum/fixnum.dart';
import 'package:uuid/uuid.dart';
import 'package:education/config/app_env.dart';
import 'package:education/core/sqlite/database_helper.dart';
import 'package:education/core/websocket/ws_event.dart';
import 'package:education/core/utils/conversation.dart';
import 'package:education/modules/dynamic/models/post_info.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/user_repository.dart';
import 'package:education/providers/chat_providers.dart';
import 'package:education/providers/user_provider.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/chat/group/group_avatar.dart';
import 'package:education/pb/protos/chat.pb.dart' as pb;

/// BBT 风格分享弹窗：搜索、建议会话、复制链接、保存图片、更多
/// 用于将动态分享到聊天
void showDynamicShareSheet({
  required BuildContext context,
  required PostInfo post,
  required VoidCallback onShared,
}) {
  final parentContext = context; // 保存父级 context，pop 后仍可用
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _DynamicShareSheet(
      post: post,
      parentContext: parentContext,
      // 仅通知父级（如 SnackBar），不在此 pop；sheet 的关闭由 _shareToConversation 负责
      onShared: onShared,
      onDismiss: () => Navigator.pop(ctx),
    ),
  );
}

class _DynamicShareSheet extends ConsumerWidget {
  final PostInfo post;
  final BuildContext parentContext;
  final VoidCallback onShared;
  final VoidCallback onDismiss;

  const _DynamicShareSheet({
    required this.post,
    required this.parentContext,
    required this.onShared,
    required this.onDismiss,
  });

  String _getShareLink() {
    final base = currentEnv.reqUrl;
    return '$base/dynamic/post/${post.postId}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final uidAsync = ref.watch(userProvider);
    return uidAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (currentUid) {
        if (currentUid == null) return const SizedBox.shrink();
        final conversationsAsync = ref.watch(conversationListProvider(currentUid));
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                // 拖动条
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                // 搜索框
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: '搜索',
                        hintStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
                        prefixIcon: Icon(Icons.search, size: 20, color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // 建议分享对象（会话列表）
                SizedBox(
                  height: 100,
                  child: conversationsAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (e, _) => Center(child: Text('加载失败: $e')),
                    data: (conversations) {
                      if (conversations.isEmpty) {
                        return Center(
                          child: Text('暂无会话', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
                        );
                      }
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        itemCount: conversations.length,
                        itemBuilder: (_, i) {
                          final c = conversations[i];
                          final avatars = c.avatar
                              .split('、')
                              .map((s) => s.trim())
                              .where((s) => s.isNotEmpty)
                              .toList();
                          return _ConversationShareItem(
                            title: c.title,
                            avatars: avatars,
                            isGroup: c.type == WSDelivery.group,
                            onTap: () => _shareToConversation(context, parentContext, ref, c, currentUid),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                // 操作按钮行
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.link,
                          label: '复制链接',
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: _getShareLink()));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('链接已复制'), duration: Duration(seconds: 1)),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.download_outlined,
                          label: '保存图片',
                          onTap: () {
                            // 若有首图则保存，否则提示
                            final firstMedia = post.mediaList.isNotEmpty ? post.mediaList.first : null;
                            if (firstMedia != null && firstMedia.url.isNotEmpty) {
                              // TODO: 实现图片保存到相册
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('保存功能开发中')),
                              );
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('该动态无图片可保存')),
                              );
                            }
                          },
                        ),
                      ),
                      Expanded(
                        child: _ActionButton(
                          icon: Icons.more_horiz,
                          label: '更多',
                          onTap: () {
                            // 可扩展：系统分享、生成海报等
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('更多功能开发中')),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // 取消按钮
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: onDismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[700],
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('取消'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _shareToConversation(BuildContext sheetContext, BuildContext parentContext, WidgetRef ref, Conversation conv, int currentUid) {
    // 必须用 sheet 的 context 来 pop，否则会触发 _history.isNotEmpty 断言
    if (sheetContext.mounted) Navigator.of(sheetContext).pop();
    onShared();
    // 延迟执行，避免 pop 后 ref 失效；使用 parentContext 确保 SnackBar 能正确显示
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _sendDynamicShareToConversation(parentContext, ref, conv, currentUid);
    });
  }

  /// 获取发布者昵称（后端动态接口未返回，需从本地缓存或接口拉取）
  Future<String> _resolveUserNickname(int userId) async {
    if (userId <= 0) return '';
    try {
      final u = await UserRepository(Global.db).getUser(userId);
      if (u?.username != null && u!.username!.isNotEmpty) return u.username!;
      final map = await UserApi().getUserOtherInfo({'userId': userId});
      return map['username']?.toString() ?? '';
    } catch (_) {
      return '';
    }
  }

  Future<void> _sendDynamicShareToConversation(BuildContext parentContext, WidgetRef ref, Conversation conv, int currentUid) async {
    try {
      final convId = conv.serverConversationId;
      if (convId.isEmpty) return;

      // 补齐昵称（后端动态接口未返回）
      final userNickname = (post.userNickname != null && post.userNickname!.isNotEmpty)
          ? post.userNickname!
          : await _resolveUserNickname(post.userId);

      int toUserOrGroupId;
      if (conv.type == WSDelivery.group) {
        if (!convId.startsWith('temp_group_')) {
          _showError(parentContext, '暂不支持分享到该群聊');
          return;
        }
        toUserOrGroupId = getGroupIdByConversationId(convId);
      } else {
        if (!convId.startsWith('temp_single_')) {
          _showError(parentContext, '暂不支持分享到该会话');
          return;
        }
        toUserOrGroupId = getUserIDsByConversationId(convId, currentUid);
      }

      final extra = <String, dynamic>{
        'post_id': post.postId,
        'user_id': post.userId,
        'user_nickname': userNickname,
        'content': post.content,
        'type': post.type,
        'likes_count': post.likesCount,
        'comments_count': post.commentsCount,
        'media_list': post.mediaList.map((m) => m.thumbnailUrl.isNotEmpty ? m.thumbnailUrl : m.url).toList(),
        'created_at': post.createdAt,
      };
      final mediaUrl = post.mediaList.isNotEmpty ? (post.mediaList.first.thumbnailUrl.isNotEmpty ? post.mediaList.first.thumbnailUrl : post.mediaList.first.url) : '';
      final tempClientMsgId = const Uuid().v4();
      final tempTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final tempMessage = pb.Event()
        ..clientMsgId = tempClientMsgId
        ..fromUser = Int64(currentUid)
        ..conversationId = convId
        ..delivery = conv.type == WSDelivery.group ? WSDelivery.group : WSDelivery.single
        ..type = WSEventType.dynamicShare
        ..content = '分享了一条动态'
        ..timestamp = Int64(tempTimestamp)
        ..mediaUrl = mediaUrl
        ..extra = utf8.encode(jsonEncode(extra))
        ..status = WSMessageStatus.sending;

      if (conv.type == WSDelivery.group) {
        tempMessage.groupId = Int64(toUserOrGroupId);
        tempMessage.toUser = Int64(toUserOrGroupId);
      } else {
        tempMessage.toUser = Int64(toUserOrGroupId);
      }

      ref.read(messageRepositoryProvider).saveMessage(tempMessage);
      try {
        ws.send(tempMessage);
      } catch (_) {
        ref.read(messageRepositoryProvider).updateMessageStatusByClientMsgId(tempMessage.clientMsgId, 'failed');
      }
    } catch (e, st) {
      debugPrint('分享失败: $e\n$st');
      _showError(parentContext, '分享失败');
    }
  }

  void _showError(BuildContext context, String msg) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class _ConversationShareItem extends StatelessWidget {
  final String title;
  final List<String> avatars;
  final bool isGroup;
  final VoidCallback onTap;

  const _ConversationShareItem({
    required this.title,
    required this.avatars,
    required this.isGroup,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: avatars.isEmpty
                    ? Icon(Icons.chat_bubble_outline, color: Colors.grey[500], size: 28)
                    : avatars.length == 1
                        ? Image.network(
                            avatars.first,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Icon(Icons.person, color: Colors.grey[500]),
                          )
                        : GroupAvatar(avatarUrls: avatars),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 64,
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black87),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 24, color: Colors.grey[700]),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          ],
        ),
      ),
    );
  }
}
