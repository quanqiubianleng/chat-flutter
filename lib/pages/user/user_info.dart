import 'package:education/config/app_config.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/follower_repository.dart';
import 'package:education/pb/protos/chat.pb.dart';
import 'package:education/services/user_service.dart';
import 'package:education/pages/profile/user_posts_tab.dart';
import 'package:education/pages/profile/user_comments_tab.dart';
import 'package:education/pages/profile/user_liked_posts_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import 'package:education/core/websocket/ws_event.dart';
import 'package:education/pages/chat/single_chat.dart';
import 'package:education/providers/user_provider.dart';

import '../../core/utils/conversation.dart';
import '../../core/utils/logger.dart';
import '../../providers/follower_provider.dart';

class UserInfo extends ConsumerStatefulWidget {
  final int userId;

  const UserInfo({
    super.key,
    required this.userId,
  });

  @override
  ConsumerState<UserInfo> createState() => _UserInfoState();
}

class _UserInfoState extends ConsumerState<UserInfo> with SingleTickerProviderStateMixin {
  final api = UserApi();

  String _convID = ""; // 存储当前会话ID
  bool _isLoading = false;      // 按钮加载状态
  int _isFollowed = 0;     // 当前是否已关注
  late TabController _tabController;
  late FollowerRepository followerRepo;

  Map<String, dynamic>? currentUser; // 使用 Map 存储用户信息

  static const List<String> _tabs = ['动态', '评论', '点赞', '自选', '语音房'];

  // 加载状态
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    followerRepo = ref.read(followerRepositoryProvider);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 加载用户信息 + 模拟多账号列表
  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final userInfo = await api.getUserOtherInfo({"userId": widget.userId});
      // 获取当前用户ID
      final uidAsync = await ref.read(userProvider.future);
      final currentUserId = uidAsync!;
      final convID = generateTempConversationId(userIdA: currentUserId, userIdB: widget.userId, isGroup: false);

      AppLogger.d("userInfo");
      AppLogger.d(userInfo);
      setState(() {
        currentUser = userInfo;
        isLoading = false;
        _isFollowed = userInfo['is_friend'];
        _convID = convID;
      });
    } catch (e) {
      AppLogger.d("加载用户信息失败1: $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("加载失败，下拉重试")));
      }
    }
  }

  /// 关注 / 取消关注
  Future<void> _toggleFollow() async {

    final uidAsync = ref.read(userProvider);
    final uid = uidAsync.value;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }

    if (_isLoading || uid == 0) return; // UID 未准备好
    setState(() {
      _isLoading = true;
    });

    try {
      final resp = await api.follower({"userId": widget.userId});
      bool success = resp['code'] == HttpStatus.success;
      String msg = resp['msg'] ?? (_isFollowed > 0 ? '取消关注成功' : '关注成功');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
      _loadUserData();
      if (success) {
        // 关注更新sqlite
        if(_isFollowed > 0){
          await followerRepo.unfollow(uid, widget.userId);
        }else{
          await followerRepo.follow(uid, widget.userId);
        }

        final type = _isFollowed > 0 ? "unfollow" : "follow";
        setState(() {
          _isLoading = false;
        });

        final tempClientMsgId = const Uuid().v4();
        final tempTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
        final convID = generateTempConversationId(isGroup: false, userIdA: widget.userId, userIdB: uid);

        final msg = Event()
        ..delivery = WSDelivery.single
        ..type = type
        ..fromUser = Int64(uid)
        ..toUser = Int64(widget.userId)
        ..clientMsgId = tempClientMsgId          // 客户端防重
        ..content = '关注了你'
        ..timestamp = Int64(tempTimestamp);
        ws.send(msg);

        if (resp["isFriend"]){
          final msg2 = Event()
          ..delivery = WSDelivery.single
          ..type = WSEventType.message
          ..fromUser = Int64(uid)
          ..toUser = Int64(widget.userId)
          ..conversationId = convID
          ..clientMsgId = tempClientMsgId          // 客户端防重
          ..content = '我们已互相关注，可以开始聊天了'
          ..timestamp = Int64(tempTimestamp);

          ws.send(msg2);
        }
      }
    } catch (e) {
      AppLogger.d(e.toString());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_isFollowed > 0 ? '取消关注失败' : '关注失败')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading || currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('用户信息')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: 100,
              automaticallyImplyLeading: false,
              leading: const SizedBox.shrink(),
              flexibleSpace: Stack(
                fit: StackFit.expand,
                children: [
                  FlexibleSpaceBar(
                    background: _buildAppBarBackground(),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: () => Navigator.pop(context),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Color(0x4D000000),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: const BoxDecoration(
                                color: Color(0x4D000000),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.share_outlined, color: Colors.white, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SliverToBoxAdapter(
              child: _buildUserInfoCard(),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverTabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: const Color(0xFF00D1A7),
                  unselectedLabelColor: const Color(0xFF666666),
                  indicatorColor: const Color(0xFF00D1A7),
                  tabs: _tabs.map((e) => Tab(text: e)).toList(),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            UserPostsTab(userId: widget.userId, userInfo: currentUser),
            UserCommentsTab(userId: widget.userId, userInfo: currentUser),
            UserLikedPostsTab(userId: widget.userId, userInfo: currentUser),
            _buildPlaceholderTab('自选'),
            _buildPlaceholderTab('语音房'),
          ],
        ),
      ),
    );
  }

  Widget _buildUserInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  currentUser!['avatar_url'] ?? '',
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 60),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  currentUser!['username'] ?? '未知用户',
                  style: const TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DeBoxChatPage(chatId: _convID),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF08AD56)),
                  ),
                  child: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Color(0xFF08AD56)),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: _toggleFollow,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  decoration: BoxDecoration(
                    color: _isFollowed > 0 ? Colors.grey : const Color(0xFF08AD56),
                    borderRadius: BorderRadius.circular(20),
                    border: _isFollowed > 0 ? Border.all(color: Colors.white) : null,
                  ),
                  child: Text(
                    currentUser!['is_friend'] == 0 ? '关注' : (currentUser!['is_friend'] == 1 ? '已关注' : '朋友'),
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '备注：${currentUser!["remark"]}',
            style: const TextStyle(color: Colors.grey, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text('${currentUser!['i_follow'] ?? 0}', style: const TextStyle(color: Colors.black, fontSize: 15)),
              const Text(' 关注', style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(width: 15),
              Text('${currentUser!['follow_me'] ?? 0}', style: const TextStyle(color: Colors.black, fontSize: 15)),
              const Text(' 粉丝', style: TextStyle(color: Colors.grey, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            (currentUser!['intro'] ?? '').toString().isEmpty
                ? 'MOD 很懒，还没有设置简介～'
                : (currentUser!['intro'] as String),
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab(String name) {
    return Center(child: Text('$name - 待接入'));
  }

  Widget _buildAppBarBackground() {
    final bgUrl = currentUser == null ? '' : (currentUser!['background_url'] ?? '').toString();
    final hasBg = bgUrl.isNotEmpty;
    return Container(
      decoration: BoxDecoration(
        gradient: hasBg ? null : const LinearGradient(
          colors: [Color(0xFF07C160), Color(0xFF009A4A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: hasBg
          ? Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  bgUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF07C160), Color(0xFF009A4A)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ),
                Container(color: Colors.black26),
              ],
            )
          : null,
    );
  }

}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => tabBar != oldDelegate.tabBar;
}