import 'package:education/modules/dynamic/models/post_info.dart';
import 'package:education/pages/market/dynamic_detail_page.dart';
import 'package:education/services/dynamic_service.dart';
import 'package:education/widgets/follower/community_post_card.dart';
import 'package:flutter/material.dart';

/// 用户收藏列表 Tab（自选，仅用于当前用户自己的收藏）
class UserStarredTab extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? userInfo;

  const UserStarredTab({super.key, required this.userId, this.userInfo});

  @override
  State<UserStarredTab> createState() => _UserStarredTabState();
}

class _UserStarredTabState extends State<UserStarredTab> {
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

  Future<void> _toggleStar(PostInfo p) async {
    try {
      await _api.unstarPost(postId: p.postId);
      if (mounted) {
        setState(() {
          _posts.removeWhere((e) => e.postId == p.postId);
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
      final resp = await _api.getStarredPosts(cursor: 0, limit: 20);
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text('暂无收藏', style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      );
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
              onLike: () {},
              onStar: () => _toggleStar(p),
            ),
          );
        },
      ),
    );
  }
}
