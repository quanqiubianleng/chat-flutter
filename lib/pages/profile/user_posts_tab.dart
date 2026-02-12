import 'package:education/modules/dynamic/models/post_info.dart';
import 'package:education/pages/market/dynamic_detail_page.dart';
import 'package:education/services/dynamic_service.dart';
import 'package:education/widgets/common/empty_state_view.dart';
import 'package:education/widgets/follower/community_post_card.dart';
import 'package:flutter/material.dart';

/// 用户动态列表 Tab（用于 MyInfoPage）
class UserPostsTab extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? userInfo;

  const UserPostsTab({super.key, required this.userId, this.userInfo});

  @override
  State<UserPostsTab> createState() => _UserPostsTabState();
}

class _UserPostsTabState extends State<UserPostsTab> {
  final DynamicApi _api = DynamicApi();
  List<PostInfo> _posts = [];
  int _cursor = 0;
  bool _hasMore = true;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _toggleLike(PostInfo p) async {
    try {
      if (p.isLiked) {
        await _api.unlikePost(postId: p.postId);
      } else {
        await _api.likePost(postId: p.postId);
      }
      if (mounted) {
        setState(() {
          final i = _posts.indexWhere((e) => e.postId == p.postId);
          if (i >= 0) {
            final old = _posts[i];
            _posts[i] = PostInfo(
              postId: old.postId,
              userId: old.userId,
              content: old.content,
              type: old.type,
              visibility: old.visibility,
              parentPostId: old.parentPostId,
              onChainData: old.onChainData,
              likesCount: p.isLiked ? (old.likesCount - 1).clamp(0, 999999) : old.likesCount + 1,
              commentsCount: old.commentsCount,
              rewardsAmount: old.rewardsAmount,
              starsCount: old.starsCount,
              createdAt: old.createdAt,
              updatedAt: old.updatedAt,
              mediaList: old.mediaList,
              isLiked: !p.isLiked,
              isStarred: old.isStarred,
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleStar(PostInfo p) async {
    try {
      if (p.isStarred) {
        await _api.unstarPost(postId: p.postId);
      } else {
        await _api.starPost(postId: p.postId);
      }
      if (mounted) {
        setState(() {
          final i = _posts.indexWhere((e) => e.postId == p.postId);
          if (i >= 0) {
            final old = _posts[i];
            _posts[i] = PostInfo(
              postId: old.postId,
              userId: old.userId,
              content: old.content,
              type: old.type,
              visibility: old.visibility,
              parentPostId: old.parentPostId,
              onChainData: old.onChainData,
              likesCount: old.likesCount,
              commentsCount: old.commentsCount,
              rewardsAmount: old.rewardsAmount,
              starsCount: p.isStarred ? (old.starsCount - 1).clamp(0, 999999) : old.starsCount + 1,
              createdAt: old.createdAt,
              updatedAt: old.updatedAt,
              mediaList: old.mediaList,
              isLiked: old.isLiked,
              isStarred: !p.isStarred,
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _posts = [];
      _cursor = 0;
      _hasMore = true;
    });
    try {
      final resp = await _api.getUserPosts(userId: widget.userId, cursor: 0, limit: 20);
      final raw = resp['list'] as List<dynamic>? ?? [];
      final list = raw.map((e) => PostInfo.fromMap(e as Map<String, dynamic>)).toList();
      final next = (resp['next_cursor'] as num?)?.toInt() ?? 0;
      final hasMore = resp['has_more'] as bool? ?? false;
      if (mounted) {
        setState(() {
          _posts = list;
          _cursor = next;
          _hasMore = hasMore;
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

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error', style: TextStyle(color: Colors.red[700])),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_posts.isEmpty) {
      return const EmptyStateView();
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _posts.length,
        itemBuilder: (_, i) {
          final p = _posts[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CommunityPostCard(
              post: p,
              userInfo: widget.userInfo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DynamicDetailPage(postId: p.postId, initialPost: p),
                ),
              ).then((_) => _load()),
              onComment: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DynamicDetailPage(postId: p.postId, initialPost: p),
                ),
              ).then((_) => _load()),
              onLike: () => _toggleLike(p),
              onStar: () => _toggleStar(p),
            ),
          );
        },
      ),
    );
  }
}
