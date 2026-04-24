import 'package:education/config/app_config.dart';
import 'package:education/modules/dynamic/models/post_info.dart';
import 'package:education/pages/market/dynamic_detail_page.dart';
import 'package:education/pages/market/market_quotes_tab.dart';
import 'package:education/providers/feed_refresh_provider.dart';
import 'package:education/providers/user_provider.dart';
import 'package:education/services/dynamic_service.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/chat/avatar.dart';
import 'package:education/widgets/follower/community_post_card.dart';
import 'package:education/widgets/follower/bbt_floating_menu.dart';
import 'package:education/widgets/follower/post_more_menu_sheet.dart';
import 'package:education/widgets/common/empty_state_view.dart';
import 'package:education/widgets/common/share_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class MarketFeedPage extends ConsumerWidget {
  const MarketFeedPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          titleSpacing: 0,
          title: Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: true,
                  labelColor: Colors.black,
                  labelStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  unselectedLabelColor: Colors.grey,
                  unselectedLabelStyle: const TextStyle(fontSize: 14),
                  indicatorColor: const Color(0xFF00D29D),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 2,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '广场'),
                    Tab(text: '行情'),
                    Tab(text: '活动'),
                    Tab(text: 'DApp'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () {},
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const PlazaFeedTab(),
            const MarketQuotesTab(),
            const ActivityTab(),
            const _DAppTab(),
          ],
        ),
        floatingActionButton: const BBTFloatingMenu(),
      ),
    );
  }
}

/// 默认数据布局：左侧头像 + 右侧内容
Widget _buildMessageWithAvatar({
  required String? avatarUrl,
  required Widget child,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Avatar(url: avatarUrl, size: 42, borderRadius: 6),
        const SizedBox(width: 12),
        Expanded(child: child),
      ],
    ),
  );
}

/// 广场 Tab：子栏「推荐」（公开动态全站倒序）+「广场」（原 following 关注流接口）
class PlazaFeedTab extends StatelessWidget {
  const PlazaFeedTab({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: 0,
      child: Column(
        children: [
          Material(
            color: Colors.white,
            child: TabBar(
              // 与行情页分类 Row 一致：从左侧起排，不占满整行居中
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: EdgeInsets.zero,
              labelPadding: const EdgeInsets.symmetric(horizontal: 16),
              labelColor: const Color(0xFF00D29D),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF00D29D),
              indicatorSize: TabBarIndicatorSize.label,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: '推荐'),
                Tab(text: '关注'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                FeedListTab(visibility: 'public'),
                FeedListTab(visibility: 'following'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FeedListTab extends ConsumerStatefulWidget {
  /// `public`：全站公开动态，按 post_id 倒序；`following`：原关注流（网关 following）
  final String visibility;

  const FeedListTab({super.key, required this.visibility});

  @override
  ConsumerState<FeedListTab> createState() => _FeedListTabState();
}

class _FeedListTabState extends ConsumerState<FeedListTab> {
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _posts = [];
      _cursor = 0;
      _hasMore = true;
    });
    try {
      final resp = await _api.getFeed(
        visibility: widget.visibility,
        cursor: 0,
        limit: 20,
      );
      final raw = resp['list'] as List<dynamic>? ?? [];
      if (AppConfig.isDebug && raw.isNotEmpty) {
        final first = raw.first as Map<String, dynamic>;
        debugPrint(
          '[Feed] 首条 raw likes_count=${first['likes_count']} comments_count=${first['comments_count']} keys=${first.keys.join(',')}',
        );
      }
      final list = raw
          .map((e) => PostInfo.fromMap(e as Map<String, dynamic>))
          .toList();
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
    if (!_hasMore || _loadingMore) return;
    if (!mounted) return;
    setState(() => _loadingMore = true);
    try {
      final resp = await _api.getFeed(
        visibility: widget.visibility,
        cursor: _cursor,
        limit: 20,
      );
      final raw = resp['list'] as List<dynamic>? ?? [];
      final list = raw
          .map((e) => PostInfo.fromMap(e as Map<String, dynamic>))
          .toList();
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

  void _showPostMoreMenu(PostInfo post, LayerLink link) {
    final currentUid = ref.read(userProvider).valueOrNull;
    final isOwn = currentUid != null && currentUid == post.userId;
    showPostMoreMenuOverlay(
      context: context,
      layerLink: link,
      isOwnPost: isOwn,
      onShare: () => _onShare(post),
      onPin: isOwn ? () => _onPin(post) : null,
      onEdit: isOwn ? () => _onEdit(post) : null,
      onPrivate: isOwn ? () => _onPrivate(post) : null,
      onDelete: isOwn ? () => _onDelete(post) : null,
    );
  }

  void _onShare(PostInfo post) {
    showDynamicShareSheet(
      context: context,
      post: post,
      onShared: () {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已分享到聊天')));
        }
      },
    );
  }

  Future<void> _onPin(PostInfo post) async {
    try {
      await _api.updatePost(postId: post.postId, isPinned: true);
      if (mounted) _load();
    } catch (_) {
      if (mounted) {
        /* 置顶失败，静默处理 */
      }
    }
  }

  void _onEdit(PostInfo post) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('编辑功能待实现')));
  }

  Future<void> _onPrivate(PostInfo post) async {
    try {
      await _api.updatePost(postId: post.postId, visibility: 'private');
      if (mounted) {
        _load();
      }
    } catch (_) {
      if (mounted) {
        /* 操作失败，静默处理 */
      }
    }
  }

  Future<void> _onDelete(PostInfo post) async {
    try {
      await _api.deletePost(postId: post.postId);
      if (mounted) {
        _load();
      }
    } catch (_) {
      if (mounted) {
        /* 删除失败，静默处理 */
      }
    }
  }

  Future<void> _onForward(PostInfo post) async {
    try {
      await _api.forwardPost(parentPostId: post.postId);
      if (mounted) {
        _load();
      }
    } catch (_) {
      if (mounted) {
        /* 转发失败，静默处理 */
      }
    }
  }

  void _openDetail(PostInfo post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DynamicDetailPage(postId: post.postId, initialPost: post),
      ),
    ).then((_) {
      if (mounted) _load();
    });
  }

  void _onLike(PostInfo p) async {
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
              likesCount: p.isLiked ? old.likesCount - 1 : old.likesCount + 1,
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

  void _onStar(PostInfo p) async {
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
              starsCount: p.isStarred ? old.starsCount - 1 : old.starsCount + 1,
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

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(feedRefreshTriggerProvider, (prev, next) {
      if (prev != next && mounted) {
        _load();
      }
    });
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
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
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          if (_posts.isEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.5,
              child: const EmptyStateView(),
            )
          else
            ..._posts.map(
              (p) => _FeedPostItem(
                post: p,
                onTap: () => _openDetail(p),
                onLike: () => _onLike(p),
                onComment: () => _openDetail(p),
                onStar: () => _onStar(p),
                onForward: () => _onForward(p),
                onShare: () => _onShare(p),
                onMoreWithLink: (link) => _showPostMoreMenu(p, link),
              ),
            ),
          if (_loadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

/// 动态项：左侧头像 + 右侧内容（默认数据布局）
class _FeedPostItem extends StatefulWidget {
  final PostInfo post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onStar;
  final VoidCallback? onForward;
  final VoidCallback? onShare;
  final void Function(LayerLink link)? onMoreWithLink;

  const _FeedPostItem({
    required this.post,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onStar,
    this.onForward,
    this.onShare,
    this.onMoreWithLink,
  });

  @override
  State<_FeedPostItem> createState() => _FeedPostItemState();
}

class _FeedPostItemState extends State<_FeedPostItem> {
  Map<String, dynamic>? _userInfo;
  final LayerLink _moreLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final data = await UserApi().getUserOtherInfo({
        'userId': widget.post.userId,
      });
      if (mounted) setState(() => _userInfo = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _userInfo?['avatar_url'] as String?;
    return _buildMessageWithAvatar(
      avatarUrl: avatarUrl,
      child: CommunityPostCard(
        post: widget.post,
        userInfo: _userInfo,
        showLeadingAvatar: false,
        onTap: widget.onTap,
        onLike: widget.onLike,
        onComment: widget.onComment,
        onStar: widget.onStar,
        onForward: widget.onForward,
        onShare: widget.onShare,
        moreButtonLink: _moreLink,
        onMoreWithLink: widget.onMoreWithLink,
      ),
    );
  }
}

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('活动网格内容'));
  }
}

class _DAppTab extends StatelessWidget {
  const _DAppTab();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('DApp'));
  }
}
