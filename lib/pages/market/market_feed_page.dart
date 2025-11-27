import 'package:flutter/material.dart';
import '../../widgets/follower/OfficialRewardCard.dart';
import '../../widgets/follower/CommunityPostCard.dart';
import '../../widgets/follower/DeBoxFloatingMenu.dart';

class MarketFeedPage extends StatelessWidget {
  const MarketFeedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: 0,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false, // 不要默认 back 按钮空间
          titleSpacing: 0, // 让内容完全贴左边
          title: Row(
            children: [
              Expanded(
                child: TabBar(
                  isScrollable: true,
                  labelColor: Colors.black,
                  labelStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  unselectedLabelColor: Colors.grey,
                  unselectedLabelStyle: TextStyle(fontSize: 14),
                  indicatorColor: Color(0xFF00D29D),
                  indicatorSize: TabBarIndicatorSize.label,
                  indicatorWeight: 2,
                  dividerColor: Colors.transparent,
                  tabs: [
                    Tab(text: '关注'),
                    Tab(text: '行情'),
                    Tab(text: '活动'),
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
        body: const TabBarView(
          children: [FollowTab(), MarketTab(), ActivityTab()],
        ),
        // 右下角绿色 + 按钮（和截图一模一样）
        floatingActionButton: const DeBoxFloatingMenu(),
      ),
    );
  }
}

Widget _buildMessageWithAvatar({
  required Widget child,   // 就是 OfficialRewardCard 或 CommunityPostCard 的内容部分
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start, // 顶部对齐
      children: [
        // 左侧：头像 + 时间
        Column(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 24),
            ),
          ],
        ),
        const SizedBox(width: 12),

        // 右侧：原组件内容（去掉自己的时间和标题，专心展示卡片）
        Expanded(child: child),
      ],
    ),
  );
}

// --- 下面是三个子Tab的代码，也可以继续拆分为单独文件 ---

class FollowTab extends StatelessWidget {
  const FollowTab({super.key});
  // ... (复制之前 FollowTab 的 build 代码) ...
  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        // 官方红包（带头像）
        _buildMessageWithAvatar(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficialRewardCard( 
                timeAgo: "4天前", // ← 我们新建一个「纯内容版」
                amount: "1USDT",
                timestamp: "2025-11-27 00:41:42",
                url: "https://m.debox.pro/reward/detail?id=...",
              ),
            ],
          ),
        ),

        // 社区用户消息
        _buildMessageWithAvatar(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CommunityPostCard( 
                username: "(CBD) 链上数据 | 全面启航",
                timeAgo: "4天前",
                content:
                    "CBD 链上数据 | DeBox 生态重磅新品\nDeFi+社交挖矿+DAO三角驱动\n\n11亿总量永不增发\n10% 节点、10% 空投、50% 挖矿、5% 保...",
                imageUrl:
                    "https://tc.newscdn.cn/tcfile/image/202411/27/cbd_debox_post_screenshot.jpg",
                likeCount: 112,
                commentCount: 3,
                link: "https://idap.cbd.ink/#/?login?...",
              ),
            ],
          ),
        ),

        // 再来一条官方红包
        _buildMessageWithAvatar(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficialRewardCard( 
                timeAgo: "4天前", // ← 我们新建一个「纯内容版」
                amount: "1USDT",
                timestamp: "2025-11-27 00:41:42",
                url: "https://m.debox.pro/reward/detail?id=...",
              ),
            ],
          ),
        ),
      ],
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
