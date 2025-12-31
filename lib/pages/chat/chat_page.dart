import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixnum/fixnum.dart';
import 'package:education/pages/chat/single_chat.dart'; // DeBoxChatPage 所在文件
import 'package:education/pages/search/search_type.dart';
import 'package:education/providers/chat_providers.dart'; // 你的 Riverpod providers 文件路径
import 'package:education/modules/chat/models/conversation_info.dart';

import 'package:education/core/sqlite/database_helper.dart';

import '../../providers/user_provider.dart'; // Conversation 类所在路径，根据你的项目调整

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // 页面首次显示也刷一次（保险）
    // 正确方式：延迟一帧，确保 userProvider 有值后再刷新
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final currentUid = ref.read(userProvider.select((value) => value.value));
      if (currentUid != null) {
        ref.refresh(conversationListProvider(currentUid));
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // App 从后台切回前台，强制刷新会话列表
      final currentUid = ref.read(userProvider.select((value) => value.value));
      if (currentUid != null) {
        ref.refresh(conversationListProvider(currentUid)); // 传入 userId
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 安全获取当前用户ID
    final userAsync = ref.watch(userProvider);

    return userAsync.when(
        loading: () => Scaffold(body: Center(child: CircularProgressIndicator())),
        error: (err, stack) => Scaffold(body: Center(child: Text('用户加载失败'))),
        data: (currentUid) {
          if (currentUid == null) {
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
                  'BBT',
                  style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
                ),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.search, size: 24),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SearchType()),
                      );
                    },
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
                          '全部',
                          isActive: _selectedIndex == 0,
                          onTap: () => setState(() => _selectedIndex = 0),
                        ),
                        _buildFilterChip(
                          '私信',
                          isActive: _selectedIndex == 1,
                          onTap: () => setState(() => _selectedIndex = 1),
                        ),
                        _buildFilterChip(
                          '群组',
                          isActive: _selectedIndex == 2,
                          onTap: () => setState(() => _selectedIndex = 2),
                        ),
                        _buildFilterChip(
                          'Club',
                          isActive: _selectedIndex == 3,
                          onTap: () => setState(() => _selectedIndex = 3),
                        ),
                        _buildFilterChip(
                          'DAO',
                          isActive: _selectedIndex == 4,
                          onTap: () => setState(() => _selectedIndex = 4),
                        ),
                      ],
                    ),
                  ),
                  Center(child: Text('未登录'))
                ],
              ),
            );
          }

          final asyncConversations = ref.watch(conversationListProvider(currentUid));
          print(currentUid);
          print(asyncConversations);

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
                'BBT',
                style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search, size: 24),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const SearchType()),
                    );
                  },
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
                        '全部',
                        isActive: _selectedIndex == 0,
                        onTap: () => setState(() => _selectedIndex = 0),
                      ),
                      _buildFilterChip(
                        '私信',
                        isActive: _selectedIndex == 1,
                        onTap: () => setState(() => _selectedIndex = 1),
                      ),
                      _buildFilterChip(
                        '群组',
                        isActive: _selectedIndex == 2,
                        onTap: () => setState(() => _selectedIndex = 2),
                      ),
                      _buildFilterChip(
                        'Club',
                        isActive: _selectedIndex == 3,
                        onTap: () => setState(() => _selectedIndex = 3),
                      ),
                      _buildFilterChip(
                        'DAO',
                        isActive: _selectedIndex == 4,
                        onTap: () => setState(() => _selectedIndex = 4),
                      ),
                    ],
                  ),
                ),

                // 动态会话列表
                Expanded(
                  child: asyncConversations.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, stack) => Center(child: Text('加载失败: $err')),
                    data: (conversations) {
                      if (conversations.isEmpty) {
                        return const Center(child: Text('暂无会话'));
                      }

                      // 在这里打印数据
                      print("会话数据: ${conversations.length} 条记录");
                      for (var conv in conversations) {
                        print("会话: type=${conv.type}, title=${conv.title}, server_conversation_id=${conv.serverConversationId}, "
                            "last_content=${conv.lastContent}, user_id=${conv.userId}");
                      }

                      // 根据当前筛选索引过滤（这里简单示例，实际可根据 Conversation.type 扩展）
                      List<Conversation> filteredList = conversations;
                      if (_selectedIndex == 1) {
                        filteredList = conversations.where((c) => c.type == 'single').toList();
                      } else if (_selectedIndex == 2) {
                        filteredList = conversations.where((c) => c.type == 'group').toList();
                      }
                      // Club / DAO 可以后续根据实际类型扩展

                      return ListView.builder(
                        itemCount: filteredList.length,
                        itemBuilder: (context, index) {
                          final conv = filteredList[index];
                          return _buildChatItem(
                            title: conv.title ?? '未知会话',
                            subtitle: conv.lastContent ?? '', // 建议在 Conversation 类中添加此字段
                            time: _formatTimestamp(conv.lastTimestamp),
                            avatarColor: const Color(0xFF00D29D),
                            icon: conv.type == 'group' ? Icons.group : Icons.person,
                            badgeCount: conv.unreadCount ?? 0,
                            isMuted: conv.muted == 1,
                            hasRedDot: (conv.unreadCount ?? 0) > 0 && conv.pinned != 1,
                            atMe:  false, // 如果你有 @ 我的标记字段
                            onTap: () async {
                              // 进入聊天前重置未读数
                              final convId = conv.serverConversationId ?? conv.serverConversationId;
                              await ref.read(messageRepositoryProvider).resetUnreadCount(convId);

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DeBoxChatPage(
                                    chatId: convId,
                                    chatName: conv.title ?? '',
                                    toUser: Int64(0),
                                    isGroup: conv.type == 'group',
                                  ),
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        }
    );



  }

  Widget _buildFilterChip(
      String label, {
        required bool isActive,
        required VoidCallback onTap,
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
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
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
                        ? DecorationImage(image: NetworkImage(imageUrl), fit: BoxFit.cover)
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
                        bottom: BorderSide(color: Colors.grey[100]!, width: 1.0),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (atMe)
                          Text(
                            '[有人@我] ',
                            style: TextStyle(color: Colors.red, fontSize: 13),
                          ),
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
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4D4F),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeCount > 99 ? '99+' : '$badgeCount',
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

  String _formatTimestamp(int? timestampSeconds) {
    if (timestampSeconds == null || timestampSeconds == 0) return '';
    final int timestampMs = timestampSeconds * 1000;
    final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (date.isAfter(today)) {
      return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.isAfter(today.subtract(const Duration(days: 1)))) {
      return '昨天';
    } else if (date.year == now.year) {
      return '${date.month}/${date.day}';
    } else {
      return '${date.year}/${date.month}/${date.day}';
    }
  }
}