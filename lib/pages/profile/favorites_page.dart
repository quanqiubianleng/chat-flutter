import 'package:education/modules/dynamic/models/post_info.dart';
import 'package:education/pages/market/dynamic_detail_page.dart';
import 'package:education/services/dynamic_service.dart';
import 'package:education/widgets/common/empty_state_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 我的收藏页面（实验室 → 收藏进入）
/// 展示用户收藏的动态列表，支持取消收藏、点击进入详情
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  final DynamicApi _api = DynamicApi();
  List<PostInfo> _posts = [];
  int _cursor = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_loadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      _loadMore();
    }
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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _cursor == 0) return;
    setState(() => _loadingMore = true);
    try {
      final resp = await _api.getStarredPosts(cursor: _cursor, limit: 20);
      final raw = resp['list'] as List<dynamic>? ?? [];
      final list = raw.map((e) => PostInfo.fromMap(e as Map<String, dynamic>)).toList();
      final next = (resp['next_cursor'] as num?)?.toInt() ?? 0;
      final hasMore = resp['has_more'] as bool? ?? false;
      if (mounted) {
        setState(() {
          _posts.addAll(list);
          _cursor = next;
          _hasMore = hasMore;
          _loadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _openDetail(PostInfo p) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DynamicDetailPage(postId: p.postId, initialPost: p),
      ),
    ).then((_) {
      // 从详情返回时刷新（可能取消了收藏）
      _load();
    });
  }

  Future<void> _onUnstar(PostInfo p) async {
    try {
      await _api.unstarPost(postId: p.postId);
      if (mounted) {
        setState(() {
          _posts.removeWhere((e) => e.postId == p.postId);
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => Navigator.maybePop(context),
        ),
        title: const Text('我的收藏', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading && _posts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _posts.isEmpty) {
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
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 20),
        itemCount: _posts.length + (_loadingMore ? 1 : 0),
        itemBuilder: (_, i) {
          if (i >= _posts.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final p = _posts[i];
          return _FavoritesPostItem(
            post: p,
            onTap: () => _openDetail(p),
            onUnstar: () => _onUnstar(p),
          );
        },
      ),
    );
  }
}

class _FavoritesPostItem extends StatelessWidget {
  final PostInfo post;
  final VoidCallback? onTap;
  final VoidCallback? onUnstar;

  const _FavoritesPostItem({
    required this.post,
    this.onTap,
    this.onUnstar,
  });

  String _typeLabel(String type) {
    switch (type) {
      case 'social': return '动态';
      case 'onchain': return '链上';
      case 'forward': return '转发';
      case 'other': return '其他';
      default: return '动态';
    }
  }

  String _formatDate(int ts) {
    if (ts <= 0) return '';
    final ms = ts < 10000000000 ? ts * 1000 : ts;
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = post;
    final nickname = p.userNickname ?? '用户${p.userId}';
    final hasImage = p.mediaList.isNotEmpty && (p.mediaList.first.thumbnailUrl.isNotEmpty || p.mediaList.first.url.isNotEmpty);
    final thumbUrl = hasImage ? (p.mediaList.first.thumbnailUrl.isNotEmpty ? p.mediaList.first.thumbnailUrl : p.mediaList.first.url) : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5), width: 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.content.trim().isEmpty ? '无内容' : p.content,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, color: Color(0xFF1C1C1E), height: 1.3),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${_typeLabel(p.type)} | $nickname',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 72,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildThumbnail(thumbUrl, p.content),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(p.createdAt),
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThumbnail(String? imageUrl, String content) {
    const size = 72.0;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildPlaceholder(content, size),
        ),
      );
    }
    return _buildPlaceholder(content, size);
  }

  Widget _buildPlaceholder(String content, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Text(
          content.trim().isEmpty ? '' : content,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Colors.grey[600], height: 1.2),
        ),
      ),
    );
  }
}
