import 'package:education/modules/dynamic/models/comment_info.dart';
import 'package:education/modules/dynamic/models/post_info.dart';
import 'package:education/pages/market/publish_dynamic_page.dart';
import 'package:education/providers/user_provider.dart';
import 'package:education/services/dynamic_service.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/chat/avatar.dart';
import 'package:education/widgets/follower/community_post_card.dart';
import 'package:education/widgets/follower/post_more_menu_sheet.dart';
import 'package:education/widgets/common/share_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 动态详情页（BBT 风格：详情 + 评论列表 + 点赞/收藏/评论）
class DynamicDetailPage extends ConsumerStatefulWidget {
  final int postId;
  final PostInfo? initialPost;

  const DynamicDetailPage({super.key, required this.postId, this.initialPost});

  @override
  ConsumerState<DynamicDetailPage> createState() => _DynamicDetailPageState();
}

class _DynamicDetailPageState extends ConsumerState<DynamicDetailPage> {
  final DynamicApi _api = DynamicApi();
  final LayerLink _moreLink = LayerLink();
  PostInfo? _post;
  List<CommentInfo> _comments = [];
  int _nextCursor = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingComments = false;
  String? _error;
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _post = widget.initialPost;
    _load();
    _loadComments();
  }

  bool get _isOwnPost {
    final currentUid = ref.read(userProvider).valueOrNull;
    return currentUid != null && _post != null && currentUid == _post!.userId;
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_post != null && _post!.postId == widget.postId) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _api.getPostDetail(postId: widget.postId);
      final p = resp['post'] as Map<String, dynamic>?;
      if (mounted && p != null) {
        setState(() {
          _post = PostInfo.fromMap(p);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _loadComments() async {
    if (_loadingComments) return;
    setState(() => _loadingComments = true);
    try {
      final resp = await _api.getComments(
        postId: widget.postId,
        cursor: _nextCursor,
        limit: 20,
      );
      final raw = resp['list'] as List<dynamic>? ?? [];
      final list = raw.map((e) => CommentInfo.fromMap(e as Map<String, dynamic>)).toList();
      final next = (resp['next_cursor'] as num?)?.toInt() ?? 0;
      final hasMore = resp['has_more'] as bool? ?? false;
      if (mounted) {
        setState(() {
          _comments.addAll(list);
          _nextCursor = next;
          _hasMore = hasMore;
          _loadingComments = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingComments = false);
    }
  }

  Future<void> _submitComment() async {
    final content = _commentController.text.trim();
    if (content.isEmpty) return;
    _commentController.clear();
    try {
      await _api.commentPost(postId: widget.postId, content: content);
      if (mounted) {
        FocusScope.of(context).unfocus();
        setState(() {
          _comments = [];
          _nextCursor = 0;
          _hasMore = true;
        });
        _loadComments();
        if (_post != null) {
          setState(() => _post = PostInfo(
            postId: _post!.postId,
            userId: _post!.userId,
            content: _post!.content,
            type: _post!.type,
            visibility: _post!.visibility,
            parentPostId: _post!.parentPostId,
            onChainData: _post!.onChainData,
            likesCount: _post!.likesCount,
            commentsCount: _post!.commentsCount + 1,
            rewardsAmount: _post!.rewardsAmount,
            starsCount: _post!.starsCount,
            createdAt: _post!.createdAt,
            updatedAt: _post!.updatedAt,
            mediaList: _post!.mediaList,
            isLiked: _post!.isLiked,
            isStarred: _post!.isStarred,
          ));
        }
      }
    } catch (e) {
      if (mounted) {/* 评论失败，静默处理 */}
    }
  }

  Future<void> _toggleLike() async {
    if (_post == null) return;
    try {
      if (_post!.isLiked) {
        await _api.unlikePost(postId: widget.postId);
        if (mounted) setState(() => _post = PostInfo(
          postId: _post!.postId,
          userId: _post!.userId,
          content: _post!.content,
          type: _post!.type,
          visibility: _post!.visibility,
          parentPostId: _post!.parentPostId,
          onChainData: _post!.onChainData,
          likesCount: (_post!.likesCount - 1).clamp(0, 999999),
          commentsCount: _post!.commentsCount,
          rewardsAmount: _post!.rewardsAmount,
          starsCount: _post!.starsCount,
          createdAt: _post!.createdAt,
          updatedAt: _post!.updatedAt,
          mediaList: _post!.mediaList,
          isLiked: false,
          isStarred: _post!.isStarred,
        ));
      } else {
        await _api.likePost(postId: widget.postId);
        if (mounted) setState(() => _post = PostInfo(
          postId: _post!.postId,
          userId: _post!.userId,
          content: _post!.content,
          type: _post!.type,
          visibility: _post!.visibility,
          parentPostId: _post!.parentPostId,
          onChainData: _post!.onChainData,
          likesCount: _post!.likesCount + 1,
          commentsCount: _post!.commentsCount,
          rewardsAmount: _post!.rewardsAmount,
          starsCount: _post!.starsCount,
          createdAt: _post!.createdAt,
          updatedAt: _post!.updatedAt,
          mediaList: _post!.mediaList,
          isLiked: true,
          isStarred: _post!.isStarred,
        ));
      }
    } catch (e) {
      if (mounted) {/* 操作失败，静默处理 */}
    }
  }

  Future<void> _toggleStar() async {
    if (_post == null) return;
    try {
      if (_post!.isStarred) {
        await _api.unstarPost(postId: widget.postId);
        if (mounted) setState(() => _post = PostInfo(
          postId: _post!.postId,
          userId: _post!.userId,
          content: _post!.content,
          type: _post!.type,
          visibility: _post!.visibility,
          parentPostId: _post!.parentPostId,
          onChainData: _post!.onChainData,
          likesCount: _post!.likesCount,
          commentsCount: _post!.commentsCount,
          rewardsAmount: _post!.rewardsAmount,
          starsCount: (_post!.starsCount - 1).clamp(0, 999999),
          createdAt: _post!.createdAt,
          updatedAt: _post!.updatedAt,
          mediaList: _post!.mediaList,
          isLiked: _post!.isLiked,
          isStarred: false,
        ));
      } else {
        await _api.starPost(postId: widget.postId);
        if (mounted) setState(() => _post = PostInfo(
          postId: _post!.postId,
          userId: _post!.userId,
          content: _post!.content,
          type: _post!.type,
          visibility: _post!.visibility,
          parentPostId: _post!.parentPostId,
          onChainData: _post!.onChainData,
          likesCount: _post!.likesCount,
          commentsCount: _post!.commentsCount,
          rewardsAmount: _post!.rewardsAmount,
          starsCount: _post!.starsCount + 1,
          createdAt: _post!.createdAt,
          updatedAt: _post!.updatedAt,
          mediaList: _post!.mediaList,
          isLiked: _post!.isLiked,
          isStarred: true,
        ));
      }
    } catch (e) {
      if (mounted) {/* 操作失败，静默处理 */}
    }
  }

  void _showMoreMenu(LayerLink link) {
    if (_post == null) return;
    final currentUid = ref.read(userProvider).valueOrNull;
    final isOwn = currentUid != null && currentUid == _post!.userId;
    showPostMoreMenuOverlay(
      context: context,
      layerLink: link,
      isOwnPost: isOwn,
      onShare: _onShare,
      onPin: isOwn ? _onPin : null,
      onEdit: isOwn ? _onEdit : null,
      onPrivate: isOwn ? _onPrivate : null,
      onDelete: isOwn ? _onDelete : null,
    );
  }

  void _onShare() {
    if (_post == null) return;
    showDynamicShareSheet(
      context: context,
      post: _post!,
      onShared: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已分享到聊天')),
        );
      },
    );
  }

  Future<void> _onPin() async {
    try {
      await _api.updatePost(postId: widget.postId, isPinned: true);
      if (mounted) _load();
    } catch (_) {
      if (mounted) {/* 置顶失败，静默处理 */}
    }
  }

  void _onEdit() {
    if (_post == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PublishDynamicPage(editPost: _post!),
      ),
    ).then((_) { if (mounted) _load(); });
  }

  Future<void> _onPrivate() async {
    try {
      await _api.updatePost(postId: widget.postId, visibility: 'private');
      if (mounted) {
        if (_post != null) {
          setState(() => _post = PostInfo(
            postId: _post!.postId,
            userId: _post!.userId,
            content: _post!.content,
            type: _post!.type,
            visibility: 'private',
            parentPostId: _post!.parentPostId,
            onChainData: _post!.onChainData,
            likesCount: _post!.likesCount,
            commentsCount: _post!.commentsCount,
            rewardsAmount: _post!.rewardsAmount,
            starsCount: _post!.starsCount,
            createdAt: _post!.createdAt,
            updatedAt: _post!.updatedAt,
            mediaList: _post!.mediaList,
            isLiked: _post!.isLiked,
            isStarred: _post!.isStarred,
          ));
        }
      }
    } catch (_) {
      if (mounted) {/* 操作失败，静默处理 */}
    }
  }

  Future<void> _onDelete() async {
    try {
      await _api.deletePost(postId: widget.postId);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (_) {
      if (mounted) {/* 删除失败，静默处理 */}
    }
  }

  Future<void> _onForward() async {
    try {
      await _api.forwardPost(parentPostId: widget.postId);
      if (mounted) {
        if (_post != null) {
          setState(() => _post = PostInfo(
            postId: _post!.postId,
            userId: _post!.userId,
            content: _post!.content,
            type: _post!.type,
            visibility: _post!.visibility,
            parentPostId: _post!.parentPostId,
            onChainData: _post!.onChainData,
            likesCount: _post!.likesCount,
            commentsCount: _post!.commentsCount,
            rewardsAmount: _post!.rewardsAmount,
            starsCount: _post!.starsCount,
            createdAt: _post!.createdAt,
            updatedAt: _post!.updatedAt,
            mediaList: _post!.mediaList,
            isLiked: _post!.isLiked,
            isStarred: _post!.isStarred,
          ));
        }
      }
    } catch (_) {
      if (mounted) {/* 转发失败，静默处理 */}
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      behavior: HitTestBehavior.opaque,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('动态详情', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
        body: _loading && _post == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _post == null
              ? Center(child: Text('加载失败: $_error', style: TextStyle(color: Colors.red[700])))
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_post != null)
                              CommunityPostCard(
                                post: _post!,
                                onLike: _toggleLike,
                                onComment: () {},
                                onStar: _toggleStar,
                                onForward: _isOwnPost ? null : _onForward,
                                onShare: _onShare,
                                moreButtonLink: _moreLink,
                                onMoreWithLink: _showMoreMenu,
                              ),
                            Padding(
                              padding: const EdgeInsets.only(top: 12, bottom: 8),
                              child: Text(
                                '评论 ${_post?.commentsCount ?? 0}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                            ..._comments.map((c) => _CommentTile(comment: c)),
                            if (_loadingComments)
                              const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                            if (_hasMore && !_loadingComments && _comments.isNotEmpty)
                              TextButton(
                                onPressed: _loadComments,
                                child: const Text('加载更多'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const Divider(height: 1),
                    SafeArea(
                      top: false,
                      child:                             Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _commentController,
                                style: const TextStyle(fontSize: 13),
                                decoration: InputDecoration(
                                  hintText: '输入评论~',
                                  hintStyle: const TextStyle(fontSize: 13),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey[300]!),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    borderSide: BorderSide(color: Colors.grey[400]!),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                maxLines: 1,
                                onSubmitted: (_) => _submitComment(),
                              ),
                            ),
                            const SizedBox(width: 8),
                            FilledButton(
                              onPressed: _submitComment,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFF00C853),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                              child: const Text('发送'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }
}

class _CommentTile extends StatefulWidget {
  final CommentInfo comment;

  const _CommentTile({required this.comment});

  @override
  State<_CommentTile> createState() => _CommentTileState();
}

class _CommentTileState extends State<_CommentTile> {
  Map<String, dynamic>? _userInfo;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final data = await UserApi().getUserOtherInfo({'userId': widget.comment.userId});
      if (mounted) setState(() => _userInfo = data);
    } catch (_) {}
  }

  String get _username => _userInfo?['username'] as String? ?? '用户${widget.comment.userId}';
  String get _avatarUrl => _userInfo?['avatar_url'] as String? ?? '';

  String _timeStr(int ts) {
    if (ts <= 0) return '';
    final ms = ts < 10000000000 ? ts * 1000 : ts;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.month}-${d.day} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.comment;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(url: _avatarUrl, size: 36, borderRadius: 6),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _username,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(c.content, style: const TextStyle(fontSize: 14, height: 1.4)),
                const SizedBox(height: 4),
                Text(
                  _timeStr(c.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
