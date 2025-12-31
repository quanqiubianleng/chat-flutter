import 'package:flutter/material.dart';
import '../core/global.dart';
import '../message_handler/message_handler.dart' as mh;
import '../widgets/custom_widgets.dart';
import '../pages/chat/chat_page.dart';
import '../pages/market/market_feed_page.dart';
import '../pages/contacts/contacts_page.dart';
import '../pages/profile/profile_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/tab_badge_provider.dart';

class MainTabScaffold extends ConsumerStatefulWidget {
  const MainTabScaffold({super.key});

  @override
  ConsumerState<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends ConsumerState<MainTabScaffold> {
  int _currentIndex = 0;

  // 页面列表
  final List<Widget> _pages = [
    const ChatPage(),
    const ContactsPage(),
    const MarketFeedPage(),
    const ProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    // 在这里注册全局 WebSocket 监听
    final messageHandler = mh.MessageHandler(ref);

    void listener(event) {
      print('全局收到消息 → type=${event.type}  from=${event.fromUser}  to=${event.toUser}');

      // 重要：这里 ref 已经可用，可以安全调用 messageHandler.process
      messageHandler.process(event);

      // 你可以在这里加其他全局逻辑，比如：
      // - 播放提示音
      // - 更新全局未读数
      // - 统计流量等
    }

    ws.onAll(listener);

  }

  @override
  void dispose() {
    // 清理监听（推荐写在这里）
    // ws.offAll(listener); // 如果你有 offAll 方法
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 在 build 方法中直接监听 provider
    final badgeCounts = ref.watch(tabBadgeProvider);
    print("badgeCounts");
    print(badgeCounts);
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          // 点击时清除对应tab的角标
          final tabKeys = ['chat', 'friend', 'market', 'profile'];
          final tabKey = tabKeys[index];
          // ref.read(tabBadgeProvider.notifier).clearBadge(tabKey);

          setState(() => _currentIndex = index);
        },
        items: [
          // Tab 1: 消息
          BottomNavigationBarItem(
            icon: BadgeIcon(
              icon: Icons.chat_bubble_outline_rounded,
              badgeCount: badgeCounts['chat'] ?? 0,
              isActive: _currentIndex == 0,
            ),
            label: '消息',
          ),
          // Tab 2: 朋友/通讯录
          BottomNavigationBarItem(
            icon: BadgeIcon(
              icon: Icons.contacts_outlined,
              badgeCount: badgeCounts['friend'] ?? 0,
              isActive: _currentIndex == 1,
            ),
            label: '通讯录',
          ),
          // Tab 3: 列表/动态
          BottomNavigationBarItem(
            icon: BadgeIcon(
              icon: Icons.article_outlined,
              badgeCount: badgeCounts['market'] ?? 0,
              isActive: _currentIndex == 2,
            ),
            label: '广场',
          ),
          // Tab 4: 我的
          BottomNavigationBarItem(
            icon: BadgeIcon(
              icon: Icons.person_outline,
              badgeCount: badgeCounts['profile'] ?? 0,
              isActive: _currentIndex == 3,
            ),
            label: '我的',
          ),
        ],
      ),
    );
  }
}