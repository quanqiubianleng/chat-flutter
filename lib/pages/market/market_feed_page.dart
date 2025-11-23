import 'package:flutter/material.dart';

class MarketFeedPage extends StatelessWidget {
  const MarketFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          title: const TabBar(
            isScrollable: true,
            labelColor: Colors.black,
            labelStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            unselectedLabelColor: Colors.grey,
            unselectedLabelStyle: TextStyle(fontSize: 16),
            indicatorColor: Color(0xFF00D29D),
            indicatorSize: TabBarIndicatorSize.label,
            indicatorWeight: 3,
            dividerColor: Colors.transparent,
            tabs: [
              Tab(text: '关注'),
              Tab(text: '行情'),
              Tab(text: '活动'),
            ],
          ),
          actions: [
            IconButton(icon: const Icon(Icons.notifications_none), onPressed: () {}),
            const SizedBox(width: 8),
          ],
        ),
        body: const TabBarView(
          children: [
            FollowTab(),
            MarketTab(),
            ActivityTab(),
          ],
        ),
      ),
    );
  }
}

// --- 下面是三个子Tab的代码，也可以继续拆分为单独文件 ---

class FollowTab extends StatelessWidget {
  const FollowTab({super.key});
  // ... (复制之前 FollowTab 的 build 代码) ...
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildFollowCard('3天前', '抽奖 100vBOX', '2025-11-17 22:34:25'),
        _buildFollowCard('4天前', '抽奖 🎟️ 1U', '2025-11-17 01:22:34'),
      ],
    );
  }

  Widget _buildFollowCard(String timeAgo, String title, String date) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(timeAgo, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(12)
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  Text(date, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}

class MarketTab extends StatelessWidget {
  const MarketTab({super.key});
  // ... (复制之前 MarketTab 的代码) ...
  @override
  Widget build(BuildContext context) {
    return Center(child: Text("行情列表内容"));
  }
}

class ActivityTab extends StatelessWidget {
  const ActivityTab({super.key});
  // ... (复制之前 ActivityTab 的代码) ...
  @override
  Widget build(BuildContext context) {
    return Center(child: Text("活动网格内容"));
  }
}