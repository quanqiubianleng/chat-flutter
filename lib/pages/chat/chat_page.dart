import 'package:flutter/material.dart';

class ChatPage extends StatefulWidget {
  // ← 改为 StatefulWidget
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // ← 添加 State 类
  int _selectedIndex = 0; // ← 添加状态管理

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.grey[200],
        surfaceTintColor: Colors.grey[200],
        elevation: 0,
        toolbarHeight: 48,
        leading: IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 24),
          onPressed: () {},
        ),
        title: const Text(
          'DeBox',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, size: 24),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, size: 24),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          // 顶部筛选胶囊
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              border: Border(
                bottom: BorderSide(color: Colors.grey[100]!, width: 1.0),
              ),
            ),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                _buildFilterChip(
                  '全部 3',
                  isActive: _selectedIndex == 0, // ← 根据状态判断是否激活
                  onTap: () {
                    setState(() {
                      // ← 更新状态
                      _selectedIndex = 0;
                    });
                    print('点击了全部');
                  },
                ),
                _buildFilterChip(
                  '私信 3',
                  isActive: _selectedIndex == 1, // ← 根据状态判断是否激活
                  onTap: () {
                    setState(() {
                      // ← 更新状态
                      _selectedIndex = 1;
                    });
                    print('点击了私信');
                  },
                ),
                _buildFilterChip(
                  '群组',
                  isActive: _selectedIndex == 2, // ← 根据状态判断是否激活
                  onTap: () {
                    setState(() {
                      // ← 更新状态
                      _selectedIndex = 2;
                    });
                    print('点击了群组');
                  },
                ),
                _buildFilterChip(
                  'Club',
                  isActive: _selectedIndex == 3, // ← 根据状态判断是否激活
                  onTap: () {
                    setState(() {
                      // ← 更新状态
                      _selectedIndex = 3;
                    });
                    print('点击了Club');
                  },
                ),
                _buildFilterChip(
                  'DAO',
                  isActive: _selectedIndex == 4, // ← 根据状态判断是否激活
                  onTap: () {
                    setState(() {
                      // ← 更新状态
                      _selectedIndex = 4;
                    });
                    print('点击了DAO');
                  },
                ),
              ],
            ),
          ),
          // 消息列表
          Expanded(
            child: ListView(
              children: [
                _buildChatItem(
                  title: '(CBD) 链盒数据 📊 全面启航...',
                  subtitle: '[有人@我]2d8dfc10 加入了群组',
                  time: '17:24',
                  avatarColor: const Color(0xFF00D29D),
                  icon: Icons.token,
                  subtitleColor: Colors.grey,
                  atMe: true,
                  isMuted: true,
                ),
                _buildChatItem(
                  title: 'DeBox Support | 新手群',
                  subtitle: '[有人@我]宇宙联盟-勋-贵州:怎么肥事...',
                  time: '17:21',
                  avatarColor: const Color(0xFF00D29D),
                  icon: Icons.support_agent,
                  hasRedDot: true,
                  atMe: true,
                  subtitlePrefixColor: Colors.red,
                ),
                _buildChatItem(
                  title: 'BlockBeats',
                  subtitle: '「比特币 11月跌破 8万美元」概率升至 55%',
                  time: '17:20',
                  avatarColor: Colors.blueAccent,
                  icon: Icons.flash_on,
                  badgeCount: 15,
                ),
                // ... 其他列表项保持不变
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(
    String label, {
    bool isActive = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFEaffF5) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? const Color(0xFF00D29D) : Colors.grey[600],
            fontSize: 13,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // _buildChatItem 方法保持不变
  Widget _buildChatItem({
    required String title,
    required String subtitle,
    required String time,
    Color? avatarColor,
    IconData? icon,
    String? imageUrl,
    int badgeCount = 0,
    bool hasRedDot = false,
    bool isMuted = false,
    bool atMe = false,
    Color? subtitlePrefixColor,
    Color? subtitleColor,
  }) {
    return InkWell(
      onTap: () {},
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarColor ?? Colors.grey[300],
                    borderRadius: BorderRadius.circular(12),
                    image: imageUrl != null
                        ? DecorationImage(image: NetworkImage(imageUrl))
                        : null,
                  ),
                  child: imageUrl == null
                      ? Icon(
                          icon ?? Icons.person,
                          color: Colors.white,
                          size: 28,
                        )
                      : null,
                ),
                if (hasRedDot)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ),
                      Text(
                        time,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 1),
                  Container(
                    padding: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[100]!,
                          width: 1.0,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subtitleColor ?? Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ),
                        if (badgeCount > 0)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D4F),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '$badgeCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
