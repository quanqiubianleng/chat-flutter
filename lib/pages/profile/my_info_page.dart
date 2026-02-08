import 'dart:io';
import 'package:education/pages/profile/edit_profile_page.dart';
import 'package:education/pages/profile/user_posts_tab.dart';
import 'package:education/pages/profile/user_comments_tab.dart';
import 'package:education/pages/profile/user_liked_posts_tab.dart';
import 'package:education/pages/profile/user_starred_tab.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/user/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../core/utils/logger.dart';

class MyInfoPage extends ConsumerStatefulWidget {
  final User? initialUser;

  const MyInfoPage({super.key, this.initialUser});

  @override
  ConsumerState<MyInfoPage> createState() => _MyInfoPageState();
}

class _MyInfoPageState extends ConsumerState<MyInfoPage> with SingleTickerProviderStateMixin {
  final UserApi _api = UserApi();
  User? _user;
  bool _loading = true;
  String? _backgroundUrl;
  String? _intro;
  int _followCount = 0;
  int _fansCount = 0;
  late TabController _tabController;

  static const List<String> _tabs = ['动态', '评论', '点赞', '自选', '语音房'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _user = widget.initialUser;
    _refreshUser();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // 修改 _loadUser 签名
  Future<bool> _refreshUser() async {
    try {
      final data = await _api.getUserInfo();
      if (!mounted) return false;

      final newUser = User.fromMap(data);
      final newBg = data['background_url'] as String?;
      final newIntro = data['intro'] as String?;
      final newFollow = (data['follow_count'] as num?)?.toInt() ?? (data['i_follow'] as num?)?.toInt() ?? 0;
      final newFans = (data['fans_count'] as num?)?.toInt() ?? (data['follow_me'] as num?)?.toInt() ?? 0;

      setState(() {
        _user = newUser;
        _backgroundUrl = newBg;
        _intro = newIntro;
        _followCount = newFollow;
        _fansCount = newFans;
      });
      return true;
    } catch (e, st) {
      AppLogger.e('刷新用户失败', e, st);
      return false;
    }
  }

  String get _displayName {
    if (_user == null) return '--';
    final u = _user!;
    if (u.username.isNotEmpty && u.username != 'null') return u.username;
    if (u.walletAddress.length > 10) return 'User#${u.walletAddress.substring(2, 8).toUpperCase()}';
    return '匿名用户';
  }

  String get _shortAddress {
    if (_user == null || _user!.walletAddress.length <= 10) return _user?.walletAddress ?? '';
    final w = _user!.walletAddress;
    return '${w.substring(0, 6)}...${w.substring(w.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('我的')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverAppBar(
              pinned: true,
              expandedHeight: 344,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Center(
                  child: Material(
                    color: Colors.black26,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => Navigator.maybePop(context),
                      child: const SizedBox(
                        width: 34,
                        height: 34,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Icon(Icons.arrow_back_ios, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              title: Text(
                _displayName,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildExpandHeader(),
              ),
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
            _buildFeedTab(),
            _buildCommentsTab(),
            _buildLikedTab(),
            _buildStarredTab(),
            _buildPlaceholderTab('语音房'),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandHeader() {
    const double headerTopHeight = 180;
    const double avatarSize = 80;
    const double avatarOverlap = 20;

    return Stack(
      fit: StackFit.expand,
      children: [
        // 正常流：背景 + 白底内容区（不用 Positioned）
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 背景
            Container(
              height: headerTopHeight + avatarOverlap,
              decoration: BoxDecoration(
                gradient: _backgroundUrl == null || _backgroundUrl!.isEmpty
                    ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF2C3E50), Color(0xFF4A6FA5)],
                )
                    : null,
              ),
              child: _backgroundUrl != null && _backgroundUrl!.isNotEmpty
                  ? ClipRect(child: _buildBackgroundImage() ?? const SizedBox.shrink())
                  : null,
            ),
            // 白底 + 資訊區域（正常排版，不用 SingleChildScrollView）
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Padding(
                  padding: EdgeInsets.only(
                    top: 10,
                    left: 20,
                    right: 20,
                    bottom: 20,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          SizedBox(width: avatarSize + 16),
                          const Spacer(),
                          Material(
                            color: const Color(0xFFF0F0F0),
                            borderRadius: BorderRadius.circular(18),
                            child: InkWell(
                              onTap: () async {
                                if (_user == null) return;

                                final saved = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => EditProfilePage(
                                      user: _user!,
                                      intro: _intro,
                                      backgroundUrl: _backgroundUrl,
                                      onSaved: () {}, // 如果 EditProfilePage 内部有自己的保存逻辑
                                    ),
                                  ),
                                );

                                // 无论是否 saved，只要返回了就尝试刷新（更稳）
                                if (mounted) {
                                  await _refreshUser();   // 现在是安全的
                                }
                              },
                              borderRadius: BorderRadius.circular(18),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                                child: Text('编辑资料', style: TextStyle(fontSize: 14, color: Color(0xFF666666))),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _displayName,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _user?.level ?? 'Lv.1',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF666666), fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(width: 4),
                                Icon(Icons.check_circle, size: 14, color: Colors.grey[600]),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$_followCount 关注  $_fansCount 粉丝',
                        style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
                      ),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: () {
                          if (_user != null && _user!.walletAddress.isNotEmpty) {
                            Clipboard.setData(ClipboardData(text: _user!.walletAddress));
                            Fluttertoast.showToast(msg: '已复制地址');
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _shortAddress,
                            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        // 仅头像使用 Positioned 排版
        Positioned(
          left: 20,
          top: headerTopHeight - (avatarSize/2) + avatarOverlap,
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: _buildAvatarImage() != null
                  ? Image(image: _buildAvatarImage()!, fit: BoxFit.cover)
                  : Container(
                color: Colors.grey[200],
                child: const Icon(Icons.person, size: 40, color: Colors.grey),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget? _buildBackgroundImage() {
    if (_backgroundUrl == null || _backgroundUrl!.isEmpty) return null;
    if (_backgroundUrl!.startsWith('http')) {
      return Image.network(_backgroundUrl!, fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    if (File(_backgroundUrl!).existsSync()) {
      return Image.file(File(_backgroundUrl!), fit: BoxFit.cover, width: double.infinity, height: double.infinity);
    }
    return null;
  }

  ImageProvider? _buildAvatarImage() {
    final u = _user;
    if (u == null) return null;
    if (u.avatarUrl.isNotEmpty) {
      if (u.avatarUrl.startsWith('http')) return NetworkImage(u.avatarUrl);
      if (File(u.avatarUrl).existsSync()) return FileImage(File(u.avatarUrl));
    }
    return null;
  }

  Widget _buildFeedTab() {
    final userId = _user?.userId ?? 0;
    if (userId <= 0) {
      return const Center(child: Text('请先登录'));
    }
    final userInfo = _user != null
        ? {'username': _user!.username, 'avatar_url': _user!.avatarUrl}
        : null;
    return UserPostsTab(userId: userId, userInfo: userInfo);
  }

  Widget _buildCommentsTab() {
    final userId = _user?.userId ?? 0;
    if (userId <= 0) return const Center(child: Text('请先登录'));
    final userInfo = _user != null
        ? {'username': _user!.username, 'avatar_url': _user!.avatarUrl}
        : null;
    return UserCommentsTab(userId: userId, userInfo: userInfo);
  }

  Widget _buildLikedTab() {
    final userId = _user?.userId ?? 0;
    if (userId <= 0) return const Center(child: Text('请先登录'));
    final userInfo = _user != null
        ? {'username': _user!.username, 'avatar_url': _user!.avatarUrl}
        : null;
    return UserLikedPostsTab(userId: userId, userInfo: userInfo);
  }

  Widget _buildStarredTab() {
    final userId = _user?.userId ?? 0;
    if (userId <= 0) return const Center(child: Text('请先登录'));
    final userInfo = _user != null
        ? {'username': _user!.username, 'avatar_url': _user!.avatarUrl}
        : null;
    return UserStarredTab(userId: userId, userInfo: userInfo);
  }

  Widget _buildPlaceholderTab(String name) {
    return Center(child: Text('$name - 待接入'));
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