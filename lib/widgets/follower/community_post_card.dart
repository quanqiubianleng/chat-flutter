import 'package:education/modules/dynamic/models/post_info.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/chat/avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// 动态卡片（DeBox 风格，支持真实数据）
/// [showLeadingAvatar] 为 true 时，左侧显示头像；为 false 时由父级提供（用于 _buildMessageWithAvatar 布局）
class CommunityPostCard extends StatefulWidget {
  final PostInfo post;
  final Map<String, dynamic>? userInfo;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onStar;
  final VoidCallback? onForward;
  final VoidCallback? onShare;
  final VoidCallback? onMore;
  /// 用于 overlay 式菜单（与聊天加号弹窗一致），需配合 onMoreWithLink 使用
  final LayerLink? moreButtonLink;
  /// 当使用 overlay 时，会传入 layerLink 以便定位弹窗
  final void Function(LayerLink link)? onMoreWithLink;
  /// 是否在卡片内显示左侧头像，false 时仅显示内容区（供 _buildMessageWithAvatar 使用）
  final bool showLeadingAvatar;

  const CommunityPostCard({
    super.key,
    required this.post,
    this.userInfo,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onStar,
    this.onForward,
    this.onShare,
    this.onMore,
    this.moreButtonLink,
    this.onMoreWithLink,
    this.showLeadingAvatar = true,
  });

  @override
  State<CommunityPostCard> createState() => _CommunityPostCardState();
}

class _CommunityPostCardState extends State<CommunityPostCard> {
  Map<String, dynamic>? _userInfo;
  bool _loadingUser = false;

  @override
  void initState() {
    super.initState();
    _userInfo = widget.userInfo;
    if (_userInfo == null && widget.post.userId > 0) {
      _loadUser();
    }
  }

  Future<void> _loadUser() async {
    if (_loadingUser) return;
    _loadingUser = true;
    try {
      final data = await UserApi().getUserOtherInfo({'userId': widget.post.userId});
      if (mounted) setState(() => _userInfo = data);
    } catch (_) {}
    _loadingUser = false;
  }

  String get _username => _userInfo?['username'] as String? ?? '用户${widget.post.userId}';
  String get _avatarUrl => _userInfo?['avatar_url'] as String? ?? '';

  String _timeAgo(int ts) {
    if (ts <= 0) return '';
    final ms = ts < 10000000000 ? ts * 1000 : ts;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(2, 0, 0, 8),
        padding: const EdgeInsets.only(bottom: 12, right: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border(
            bottom: BorderSide(color: const Color(0xFFE5E5E5), width: 1),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.showLeadingAvatar) ...[
                  Avatar(url: _avatarUrl, size: 42, borderRadius: 6),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _username,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              if (widget.moreButtonLink != null && widget.onMoreWithLink != null) {
                                widget.onMoreWithLink!(widget.moreButtonLink!);
                              } else {
                                widget.onMore?.call();
                              }
                            },
                            child: widget.moreButtonLink != null
                                ? CompositedTransformTarget(
                                    link: widget.moreButtonLink!,
                                    child: const Padding(
                                      padding: EdgeInsets.all(4),
                                      child: Icon(Icons.more_horiz, size: 22, color: Colors.grey),
                                    ),
                                  )
                                : const Padding(
                                    padding: EdgeInsets.all(4),
                                    child: Icon(Icons.more_horiz, size: 22, color: Colors.grey),
                                  ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _timeAgo(p.createdAt),
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (p.content.isNotEmpty)
              Text(
                p.content,
                style: const TextStyle(fontSize: 15, height: 1.5),
                maxLines: 10,
                overflow: TextOverflow.ellipsis,
              ),
            if (p.mediaList.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildMedia(p.mediaList),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                _action(Icons.favorite, p.isLiked ? Icons.favorite : Icons.favorite_border,
                    p.likesCount, p.isLiked ? const Color(0xFFE91E63) : Colors.grey, widget.onLike, showCount: true),
                const SizedBox(width: 24),
                _action(Icons.chat_bubble_outline, null, p.commentsCount, Colors.grey, widget.onComment, showCount: true),
                const SizedBox(width: 24),
                _action(Icons.star, p.isStarred ? Icons.star : Icons.star_border,
                    p.starsCount, p.isStarred ? Colors.amber : Colors.grey, widget.onStar, showCount: false),
                if (widget.onForward != null) ...[
                  const SizedBox(width: 24),
                  _action(Icons.repeat, null, 0, Colors.grey, widget.onForward, showCount: false),
                ],
                const SizedBox(width: 24),
                _action(Icons.share, null, 0, Colors.grey, widget.onShare, showCount: false),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(IconData icon, IconData? altIcon, int count, Color color, VoidCallback? onTap, {bool showCount = true}) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(altIcon ?? icon, size: 20, color: color),
          if (showCount) ...[
            const SizedBox(width: 4),
            Text(
              count >= 1000 ? '${(count / 1000).toStringAsFixed(1)}k' : '$count',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }

  void _showImagePreview(String url, {List<String>? urls, int initialIndex = 0}) {
    final images = (urls?.isNotEmpty ?? false) ? urls! : [url];
    final idx = (initialIndex >= 0 && initialIndex < images.length) ? initialIndex : 0;
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.pop(ctx),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.zero,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4,
                  child: Image.network(
                    images[idx],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 80, color: Colors.white70),
                  ),
                ),
              ),
              Positioned(
                top: MediaQuery.of(context).padding.top + 8,
                right: 16,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMedia(List<MediaInfo> list) {
    final imageUrls = list.where((m) => m.mediaType == 'image').map((m) => m.url).toList();
    if (list.length == 1) {
      final m = list.first;
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: m.mediaType == 'video'
            ? _videoPreview(m.url)
            : GestureDetector(
                onTap: m.mediaType == 'image' ? () => _showImagePreview(m.url, urls: imageUrls) : null,
                child: Image.network(
                  m.url,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 200,
                  errorBuilder: (_, __, ___) => _mediaError(200),
                ),
              ),
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: list.length == 2 ? 2 : 3,
        crossAxisSpacing: 4,
        mainAxisSpacing: 4,
        childAspectRatio: 1,
      ),
      itemCount: list.length,
      itemBuilder: (_, i) {
        final m = list[i];
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: m.mediaType == 'video'
              ? _videoPreview(m.thumbnailUrl.isNotEmpty ? m.thumbnailUrl : m.url)
              : GestureDetector(
                  onTap: m.mediaType == 'image' ? () => _showImagePreview(m.url, urls: imageUrls, initialIndex: imageUrls.indexOf(m.url).clamp(0, imageUrls.length - 1)) : null,
                  child: Image.network(
                    m.url,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _mediaError(80),
                  ),
                ),
        );
      },
    );
  }

  Widget _videoPreview(String url) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.play_circle_outline, size: 48)),
        ),
        const Center(child: Icon(Icons.play_circle_filled, size: 48, color: Colors.white70)),
      ],
    );
  }

  Widget _mediaError(double size) => Container(
        color: Colors.grey[300],
        child: Icon(Icons.broken_image, size: size * 0.5, color: Colors.grey),
      );
}
