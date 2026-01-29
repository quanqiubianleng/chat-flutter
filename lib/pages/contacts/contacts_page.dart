// lib/pages/contacts_page.dart 或你的文件

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/providers/follower_provider.dart';
import 'package:education/providers/user_provider.dart';

import '../../core/utils/get_string_uuid.dart';
import '../../modules/chat/models/friend.dart';
import '../../providers/tab_badge_provider.dart';
import '../../services/user_service.dart';
import '../user/user_info.dart';
import 'follow_me.dart';
import 'follow_me_new.dart';
import 'i_follow.dart';

class ContactsPage extends ConsumerStatefulWidget {
  const ContactsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ContactsPage> createState() => _ContactsPageState();
}

class _ContactsPageState extends ConsumerState<ContactsPage> {

  late final UserApi api;
  // 朋友列表
  List<Friend> friendList = [];
  bool isLoading = true;        // 加载中
  bool hasError = false;        // 是否出错
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    api = UserApi();
    loadFriends();
  }

  Future<void> loadFriends() async {
    setState(() {
      isLoading = true;
      hasError = false;
    });

    try {
      final response = await api.getMyFriend({});

      print("loadFriends response");
      print(response);

      final List<dynamic> rawList = response['data'] ?? [];

      final List<Friend> friends = rawList
          .map((item) => Friend.fromJson(item as Map<String, dynamic>))
          .toList();

      friends.sort((a, b) => a.username.compareTo(b.username));

      setState(() {
        friendList = friends;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      print("loadFriends error: $e");
      print(stackTrace);

      setState(() {
        isLoading = false;
        hasError = true;
        errorMessage = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final followersAsync = ref.watch(followerListProvider);

    // 新增关注
    final followCounts = ref.watch(friendTabUnreadProvider).maybeWhen(
      data: (v) => v,
      orElse: () => 0,
    );
    final iFollowCounts = ref.watch(iFollowCountsProvider);
    final followMeCounts = ref.watch(followMeCountsProvider);

    print('followMeCounts = $followMeCounts');
    print('iFollowCounts = $iFollowCounts');

    // 新增：监听 followerListProvider 的变化
    ref.listen(followerListProvider, (previous, next) {
      // next.isLoading 或 next.hasError 时不处理
      if (next.isLoading || next.hasError) return;

      final previousCount = previous?.value?.length ?? 0;
      final nextCount = next.value?.length ?? 0;

      // 当朋友数量发生变化时，重新加载朋友列表
      if (previousCount != nextCount) {
        loadFriends();
      }
    });


    return Scaffold(
      appBar: AppBar(
        title: Text('朋友 (${followersAsync.value?.length ?? 0})'), // 自动更新数量
      ),
      body: Column(
        children: [
          // 搜索栏
          Container(
            margin: const EdgeInsets.only(top: 2, left: 16, right: 16, bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: Colors.grey, size: 20),
                const SizedBox(width: 8),
                Text(
                  '${followersAsync.value?.length ?? 0}个朋友',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          _buildMenuItem(Icons.person_add_alt_1, '新增关注', Colors.orange, badgeCount: followCounts,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NewSubscribersPage()),
              );
            },
          ),
          _buildMenuItem(Icons.person_outline, '关注 ($iFollowCounts)', const Color(0xFF00D29D),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ISubscribersPage()),
              );
            },
          ),
          _buildMenuItem(Icons.person_outline, '粉丝 ($followMeCounts)', const Color(0xFF00D29D),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SubscribersPage()),
              );
            },
          ),
          /*_buildMenuItem(Icons.person_outline, 'Ai Bot (9)', const Color(0xFF00D29D)),
          _buildMenuItem(Icons.person_outline, '金标号 (9)', const Color(0xFF00D29D)),*/

          // 字母分组标题可保留或动态生成

          // 动态好友列表
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadFriends,  // 下拉刷新直接调用本地方法
              child: _buildFriendListContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
      IconData icon,
      String title,
      Color color, {
        VoidCallback? onTap,
        int badgeCount = 0,  // 新增：角标数量，0 表示不显示
      }) {
    final bool showBadge = badgeCount > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          leading: Stack(
            clipBehavior: Clip.none, // 允许角标溢出
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              if (showBadge)
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      badgeCount > 99 ? '99+' : '$badgeCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
          title: Text(title, style: const TextStyle(
            fontSize: 16,
          ),),
          dense: true,
          visualDensity: const VisualDensity(vertical: 0),
          onTap: onTap,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 72, right: 20),
          child: Container(height: 1, color: Colors.grey[200]),
        ),
      ],
    );
  }

  Widget _buildFriendListContent() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (hasError) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('加载失败: $errorMessage'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: loadFriends,
              child: const Text('重试'),
            ),
          ],
        ),
      );
    }

    if (friendList.isEmpty) {
      return const Center(
        child: Text('暂无朋友', style: TextStyle(fontSize: 16, color: Colors.grey)),
      );
    }

    return ListView.builder(
      itemCount: friendList.length,
      itemBuilder: (context, index) {
        final friend = friendList[index];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 46,
              height: 46,
              child: (friend.avatarUrl as String?)?.isNotEmpty == true
                  ? Image.network(
                friend.avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 30, color: Colors.orange),
              )
                  : const Icon(Icons.person, size: 30, color: Colors.orange),
            ),
          ),
          title: Text(
            friend.username ?? "昵称",
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            truncateString(friend.walletAddress) ?? "地址",
            style: const TextStyle(fontSize: 12, color: Colors.grey),
          ),
          onTap: () {
            // TODO: 跳转个人信息页
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => UserInfo(
                  userId: friend.userId ?? 0,
                  // 你可以根据需要传更多字段
                ),
              ),
            );
          },
        );
      },
    );
  }
}