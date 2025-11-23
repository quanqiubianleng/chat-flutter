import 'package:flutter/material.dart';
import '../widgets/custom_widgets.dart';
import '../pages/chat/chat_page.dart';
import '../pages/market/market_feed_page.dart';
import '../pages/contacts/contacts_page.dart';
import '../pages/profile/profile_page.dart';

class MainTabScaffold extends StatefulWidget {
  const MainTabScaffold({super.key});

  @override
  State<MainTabScaffold> createState() => _MainTabScaffoldState();
}

class _MainTabScaffoldState extends State<MainTabScaffold> {
  int _currentIndex = 0;

  // 页面列表
  final List<Widget> _pages = [
    const ChatPage(),
    const MarketFeedPage(),
    const ContactsPage(),
    const ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          // Tab 1: 消息
          BottomNavigationBarItem(
            icon: BadgeIcon(
              icon: Icons.chat_bubble_outline_rounded, 
              badgeCount: 45,
              isActive: _currentIndex == 0,
            ),
            label: '',
          ),
          // Tab 2: 朋友/通讯录
          BottomNavigationBarItem(
            icon: Icon(Icons.contacts_outlined, size: 28),
            activeIcon: Icon(Icons.contacts, size: 28),
            label: '',
          ),
          // Tab 3: 列表/动态
          BottomNavigationBarItem(
            icon: Icon(Icons.article_outlined, size: 28),
            activeIcon: Icon(Icons.article, size: 28),
            label: '',
          ),
          
          // Tab 4: 我的
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline, size: 28),
            activeIcon: Icon(Icons.person, size: 28),
            label: '',
          ),
        ],
      ),
    );
  }
}