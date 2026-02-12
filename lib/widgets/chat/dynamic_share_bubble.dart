import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/pb/protos/chat.pb.dart';
import 'package:education/pages/market/dynamic_detail_page.dart';
import 'package:education/modules/dynamic/models/post_info.dart';
import 'package:education/providers/user_provider.dart';
import 'package:education/widgets/chat/avatar.dart';
import 'package:education/widgets/common/oss_refreshable_image.dart';

/// 动态分享消息气泡：第一行头像+昵称，第二行内容，第三行图片（无图则默认背景）
class DynamicShareBubble extends ConsumerWidget {
  final Event message;

  const DynamicShareBubble({super.key, required this.message});

  Map<String, dynamic>? get _extraMap {
    if (message.extra.isEmpty) return null;
    try {
      final str = utf8.decode(message.extra);
      return jsonDecode(str) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  PostInfo? get _postInfo {
    final m = _extraMap;
    if (m == null) return null;
    final mediaRaw = m['media_list'] as List<dynamic>? ?? [];
    final mediaList = mediaRaw.map((e) {
      final url = e is String ? e : '';
      return MediaInfo(mediaId: 0, mediaType: 'image', url: url, thumbnailUrl: url);
    }).toList();
    return PostInfo(
      postId: (m['post_id'] as num?)?.toInt() ?? 0,
      userId: (m['user_id'] as num?)?.toInt() ?? 0,
      userNickname: m['user_nickname'] as String?,
      content: m['content'] as String? ?? '',
      type: m['type'] as String? ?? 'post',
      visibility: 'public',
      parentPostId: 0,
      onChainData: '',
      likesCount: (m['likes_count'] as num?)?.toInt() ?? 0,
      commentsCount: (m['comments_count'] as num?)?.toInt() ?? 0,
      rewardsAmount: 0,
      starsCount: 0,
      createdAt: (m['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: 0,
      mediaList: mediaList,
      isLiked: false,
      isStarred: false,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final post = _postInfo;
    if (post == null) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text('[动态内容解析失败]', style: TextStyle(color: Colors.grey)),
      );
    }

    final userAsync = post.userId > 0 ? ref.watch(userInfoProvider(post.userId)) : null;
    // 昵称：优先用 extra 中的 user_nickname，否则用 userInfo 的 username（后端动态接口未返回昵称）
    final displayName = (post.userNickname != null && post.userNickname!.isNotEmpty)
        ? post.userNickname!
        : (userAsync?.valueOrNull?.username ?? '用户');

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DynamicDetailPage(postId: post.postId, initialPost: post),
          ),
        );
      },
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 第一行：发布者头像 + 昵称
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: userAsync != null
                        ? userAsync.when(
                            data: (u) => Avatar(url: u?.avatarUrl, size: 28, borderRadius: 6),
                            loading: () => _defaultAvatar(28),
                            error: (_, __) => _defaultAvatar(28),
                          )
                        : _defaultAvatar(28),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    displayName,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // 第二行：动态内容
              _buildRichContent(post.content),
              const SizedBox(height: 10),
              // 第三行：图片（无图则默认背景，支持 OSS 签名过期自动刷新）
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: post.mediaList.isNotEmpty
                    ? OssRefreshableImage(
                        url: post.mediaList.first.thumbnailUrl.isNotEmpty
                            ? post.mediaList.first.thumbnailUrl
                            : post.mediaList.first.url,
                        width: double.infinity,
                        height: 120,
                        fit: BoxFit.cover,
                        loadingBuilder: (_, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            width: double.infinity,
                            height: 120,
                            color: Colors.grey[100],
                            child: const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
                          );
                        },
                        errorBuilder: (_, __, ___) => _defaultImageArea(),
                      )
                    : _defaultImageArea(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 解析并渲染含 @ 和 # 的文本（DeBox 风格高亮）
  Widget _buildRichContent(String text) {
    if (text.isEmpty) return const SizedBox.shrink();
    final spans = <TextSpan>[];
    final regex = RegExp(r'(@[^\s@#]+|#[^\s@#]+)|([^@#]+)');
    final matches = regex.allMatches(text);

    for (final m in matches) {
      final g1 = m.group(1);
      final g2 = m.group(2);
      final s = g1 ?? g2 ?? '';
      if (s.isEmpty) continue;
      if (s.startsWith('@') || s.startsWith('#')) {
        spans.add(TextSpan(
          text: s,
          style: const TextStyle(color: Color(0xFF00D29D), fontSize: 14, fontWeight: FontWeight.w500),
        ));
      } else {
        spans.add(TextSpan(
          text: s,
          style: const TextStyle(color: Colors.black87, fontSize: 14, height: 1.4),
        ));
      }
    }

    return RichText(
      maxLines: 4,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(children: spans),
    );
  }

  Widget _defaultAvatar(double size) => Container(
        width: size,
        height: size,
        color: Colors.grey[200],
        child: const Icon(Icons.person, color: Colors.grey, size: 18),
      );

  Widget _defaultImageArea() => Container(
        width: double.infinity,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(Icons.image_outlined, size: 40, color: Colors.grey[400]),
      );
}
