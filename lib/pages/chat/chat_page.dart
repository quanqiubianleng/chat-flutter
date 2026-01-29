import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fixnum/fixnum.dart';
import 'package:education/pages/chat/single_chat.dart'; // DeBoxChatPage 所在文件
import 'package:education/pages/search/search_type.dart';
import 'package:education/providers/chat_providers.dart'; // 你的 Riverpod providers 文件路径
import 'package:education/modules/chat/models/conversation_info.dart';
import 'package:education/core/utils/timer.dart';

import 'package:education/core/sqlite/database_helper.dart';

import '../../core/websocket/ws_event.dart';
import '../../core/websocket/ws_service.dart';
import '../../providers/user_provider.dart';
import '../../widgets/chat/group/create_group_sheet.dart';
import '../../widgets/chat/group/group_avatar.dart';
import './group/group_chat.dart'; // Conversation 类所在路径，根据你的项目调整

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  late LayerLink _layerLink;
  OverlayEntry? _overlayEntry = null;

  @override
  void initState() {
    super.initState();
    _layerLink = LayerLink();
    WidgetsBinding.instance.addObserver(this);

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
    _removeOverlay();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
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
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.add_circle_outline, size: 24),
                    offset: const Offset(0, 50), // 向下偏移一点，避免遮挡按钮
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    itemBuilder: (BuildContext context) => [
                      const PopupMenuItem<String>(
                        value: 'dao',
                        child: Row(
                          children: [
                            Icon(Icons.public, color: Colors.black54),
                            SizedBox(width: 12),
                            Text('创建 DAO'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'club',
                        child: Row(
                          children: [
                            Icon(Icons.group, color: Colors.black54),
                            SizedBox(width: 12),
                            Text('创建 Club'),
                          ],
                        ),
                      ),
                      const PopupMenuItem<String>(
                        value: 'live',
                        child: Row(
                          children: [
                            Icon(Icons.live_tv, color: Colors.black54),
                            SizedBox(width: 12),
                            Text('创建 Live'),
                          ],
                        ),
                      ),
                      // 如果需要扫描，可以加一个
                      // const PopupMenuItem<String>(
                      //   value: 'scan',
                      //   child: Row(
                      //     children: [
                      //       Icon(Icons.qr_code_scanner, color: Colors.black54),
                      //       SizedBox(width: 12),
                      //       Text('扫一扫'),
                      //     ],
                      //   ),
                      // ),
                    ],
                    onSelected: (String value) {
                      // 根据选择执行对应逻辑
                      switch (value) {
                        case 'dao':
                        // TODO: 跳转到创建 DAO 页面
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('即将创建 DAO...')),
                          );
                          break;
                        case 'club':
                        // TODO: 跳转到创建 Club 页面
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('即将创建 Club...')),
                          );
                          break;
                        case 'live':
                        // TODO: 跳转到创建 Live 页面
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('即将创建 Live...')),
                          );
                          break;
                      // case 'scan':
                      //   // 开启扫码
                      //   break;
                      }
                    },
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

          return Scaffold(
            backgroundColor: Colors.grey[200],
            appBar: AppBar(
              backgroundColor: Colors.grey[200],
              surfaceTintColor: Colors.grey[200],
              elevation: 0,
              toolbarHeight: 48,
              leading: IconButton(
                icon: const Icon(Icons.chat_bubble_outline, size: 24),
                onPressed: () {},
              ),
              title: StreamBuilder<WSStatus>(
                stream: ws.statusStream,
                initialData: ws.status,
                builder: (_, snap) {
                  final st = snap.data ?? WSStatus.disconnected;

                  if (st == WSStatus.connected) {
                    return const Text(
                      "BBT",
                      style: TextStyle(fontSize: 16),
                    );
                  }

                  if (st == WSStatus.connecting) {
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text("连接中…", style: TextStyle(fontSize: 14)),
                      ],
                    );
                  }

                  // disconnected
                  return GestureDetector(
                    onTap: () {
                      ws.initAndConnect();
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.refresh, size: 16),
                        SizedBox(width: 6),
                        Text("未连接 · 点击重试", style: TextStyle(fontSize: 14)),
                      ],
                    ),
                  );
                },
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
                Padding(
                  padding: const EdgeInsets.only(right: 10), // 这里控制 + 号往左移的距离
                  child: CompositedTransformTarget(
                    link: _layerLink,
                    child: IconButton(
                      icon: const Icon(Icons.add_circle_outline, size: 24),
                      onPressed: () {
                        if (_overlayEntry != null) {
                          _removeOverlay();
                          return;
                        }

                        _overlayEntry = _createOverlayEntry();
                        Overlay.of(context, debugRequiredFor: widget).insert(_overlayEntry!);
                      },
                    ),
                  ),
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
                      /*print("会话数据: ${conversations.length} 条记录");
                      for (var conv in conversations) {
                        print("会话: type=${conv.type}, title=${conv.title}, server_conversation_id=${conv.serverConversationId}, "
                            "last_content=${conv.lastContent}, user_id=${conv.userId}, avatar=${conv.avatar}");
                      }*/

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
                          final List<String> avatarUrls = conv.avatar
                              .split('、')                    // 用中文顿号分割
                              .map((url) => url.trim())       // 去除每个url前后的空格
                              .where((url) => url.isNotEmpty) // 过滤掉可能的空字符串
                              .toList();
                          return _buildChatItem(
                            imageUrl: avatarUrls,
                            title: conv.title ?? '未知会话',
                            subtitle: conv.lastContent ?? '', // 建议在 Conversation 类中添加此字段
                            time: formatTimestamp(conv.lastTimestamp),
                            avatarColor: const Color(0xFF00D29D),
                            icon: conv.type == WSDelivery.group ? Icons.group : Icons.person,
                            badgeCount: conv.unreadCount ?? 0,
                            isMuted: conv.muted == 1,
                            delivery: conv.type,
                            hasRedDot: (conv.unreadCount ?? 0) > 0 && conv.pinned != 1,
                            atMe:  false, // 如果你有 @ 我的标记字段
                            onTap: () async {
                              // 进入聊天前重置未读数
                              final convId = conv.serverConversationId ?? conv.serverConversationId;
                              await ref.read(messageRepositoryProvider).resetUnreadCount(convId);

                              if(conv.type == WSDelivery.group){
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => GroupChatPage(
                                      chatId: convId,
                                    ),
                                  ),
                                );
                              }else{
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => DeBoxChatPage(
                                      chatId: convId,
                                    ),
                                  ),
                                );
                              }

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
    List<String>? imageUrl,
    int badgeCount = 0,
    bool hasRedDot = false,
    bool isMuted = false,
    bool atMe = false,
    String? delivery,
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
                // 基础圆角容器（背景色）
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarColor ?? Colors.grey[300],
                    borderRadius: BorderRadius.circular(8), // 你原来是5，建议改成12更圆润常见
                  ),
                ),

                // 如果有有效网络图片，才显示
                if (imageUrl != null && imageUrl.length == 1)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl[0],
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(color: Colors.grey[300]); // 加载中显示灰底
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(color: Colors.grey[300]); // 加载失败也显示灰底
                      },
                    ),
                  ),

                // 如果没有有效图片，显示默认图标或 GroupAvatar
                if (imageUrl != null && imageUrl.length > 1 && delivery == WSDelivery.group)
                  Center(
                    child: GroupAvatar(avatarUrls: imageUrl),
                  ),
                // 未读红点
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


  OverlayEntry _createOverlayEntry() {
    return OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _removeOverlay,
        child: Stack(
          children: [
            Positioned.fill(child: Container()),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              // 关键调整：
              // -130：菜单宽度150，减去按钮宽度约48的一半，再左移一点让它右对齐偏左
              // 60：向下偏移，留出空间给小三角 + 阴影
              offset: const Offset(-100, 60),
              child: Material(
                color: Colors.transparent,
                child: Stack(
                  clipBehavior: Clip.none, // 关键！允许小三角溢出显示
                  children: [
                    // 小三角（向上指向 + 按钮）
                    Positioned(
                      right: 18, // 距离右边缘18dp（微调后对准 + 图标中心偏右）
                      top: -10,  // 向上露出10dp
                      child: CustomPaint(
                        size: const Size(16, 10),
                        painter: _TrianglePainter(color: Colors.black.withOpacity(0.7)),
                      ),
                    ),
                    // 菜单本体（带圆角和阴影）
                    Container(
                      width: 150,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildOverlayMenuItem('创建 小群', Icons.group_add, () {
                            _removeOverlay();
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true, // 允许高度自适应
                              backgroundColor: Colors.transparent,
                              builder: (context) => const SelectMemberDialog(),
                            );
                          }),
                          _buildOverlayMenuItem('创建 DAO', Icons.public, () {
                            _removeOverlay();
                            _showSnackBar('即将创建 DAO...');
                          }),
                          _buildOverlayMenuItem('创建 Club', Icons.group, () {
                            _removeOverlay();
                            _showSnackBar('即将创建 Club...');
                          }),
                          _buildOverlayMenuItem('创建 Live', Icons.live_tv, () {
                            _removeOverlay();
                            _showSnackBar('即将创建 Live...');
                          }),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverlayMenuItem(String title, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.white70),
            const SizedBox(width: 12),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.black87,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

