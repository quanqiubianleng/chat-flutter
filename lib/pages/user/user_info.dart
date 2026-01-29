import 'package:education/config/app_config.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/follower_repository.dart';
import 'package:education/pb/protos/chat.pb.dart';
import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import 'package:education/core/websocket/ws_event.dart';
import 'package:education/pages/chat/single_chat.dart';
import 'package:education/providers/user_provider.dart';

import '../../core/utils/conversation.dart';
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

class _UserInfoState extends ConsumerState<UserInfo> {
  final api = UserApi();

  String _convID = ""; // 存储当前会话ID
  bool _isLoading = false;      // 按钮加载状态
  int _isFollowed = 0;     // 当前是否已关注
  int tabIndex = 0;     // tabIndex
  late FollowerRepository followerRepo;

  Map<String, dynamic>? currentUser; // 使用 Map 存储用户信息

  // 加载状态
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // 延迟获取 context
    followerRepo = ref.read(followerRepositoryProvider);
    _loadUserData();
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

      print("userInfo");
      print(userInfo);
      setState(() {
        currentUser = userInfo;
        isLoading = false;
        _isFollowed = userInfo['is_friend'];
        _convID = convID;
      });
    } catch (e) {
      print("加载用户信息失败1: $e");
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
      print(e.toString());
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
    return Scaffold(
      backgroundColor: Colors.grey[200], // 浅灰
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(100),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF07C160), Color(0xFF009A4A)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
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
      ),

      body: isLoading ? const Center(child: CircularProgressIndicator()) : Stack(
        children: [
          Column(
            children: [
              // 顶部用户信息（绿色渐变区）
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                decoration: const BoxDecoration(
                  color: Colors.white
                ),
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

                        // 聊天
                        GestureDetector(
                          onTap:  (){
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => DeBoxChatPage(
                                  chatId: _convID,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF08AD56)),
                            ),
                            child: Container(
                              child: const Icon(
                                  Icons.chat_bubble_outline_rounded,
                                  size: 18,
                                  color: const Color(0xFF08AD56)
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // 关注按钮（关键修改部分）
                        GestureDetector(
                          onTap:  _toggleFollow,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                            decoration: BoxDecoration(
                              color: _isFollowed > 0 ? Colors.grey : const Color(0xFF08AD56),
                              borderRadius: BorderRadius.circular(20),
                              border: _isFollowed > 0 ? Border.all(color: Colors.white) : null,
                            ),
                            child: Text(
                              currentUser!['is_friend'] == 0 ? '关注' : (currentUser!['is_friend'] == 1 ? '已关注' : '朋友'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
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
                        Text(
                          '${currentUser!['i_follow'] ?? 0}',
                          style: TextStyle(color: Colors.black, fontSize: 15),
                        ),
                        const Text(
                          ' 关注',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                        const SizedBox(width: 15),
                        Text(
                          '${currentUser!['follow_me'] ?? 0}',
                          style: TextStyle(color: Colors.black, fontSize: 15),
                        ),
                        const Text(
                          ' 粉丝',
                          style: TextStyle(color: Colors.grey, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'MOD 很懒，还没有设置简介～',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  ],
                ),
              ),

              // Tab
              Container(
                color: Colors.white,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    const SizedBox(width: 16),
                    _buildTab('精选', tabIndex == 0,
                      () {
                        setState(() {
                          tabIndex = 0;  // 切换到 精选
                        });
                      },
                    ),
                    const SizedBox(width: 32),
                    _buildTab('自选', tabIndex == 1,
                      () {
                        setState(() {
                          tabIndex = 1;  // 切换到 精选
                        });
                      },
                    ),
                  ],
                ),
              ),

              // 内容区空状态
              Expanded(
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(), // 允许下拉刷新手感（可选）
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height -
                          MediaQuery.of(context).padding.top -
                          kToolbarHeight -
                          200, // 粗略预留其他区域高度，可根据实际调整
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Image.asset(
                            'assets/images/error.png',
                            height: 150,
                            color: Colors.grey[300],
                            colorBlendMode: BlendMode.modulate,
                            errorBuilder: (context, error, stackTrace) {
                              print('Asset 加载失败: $error');
                              return const Icon(Icons.error, color: Colors.red, size: 120);
                            },
                          ),
                          const SizedBox(height: 20),
                          const Text('什么都没有', style: TextStyle(fontSize: 16, color: Colors.grey)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // 右下角 + 按钮
          Positioned(
            right: 20,
            bottom: 30,
            child: FloatingActionButton(
              backgroundColor: const Color(0xFF07C160),
              onPressed: () {
                // 发送消息或加好友逻辑
              },
              child: const Icon(Icons.add, color: Colors.white, size: 30),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String title, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              color: selected ? Colors.black87 : Colors.grey,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          if (selected) Container(height: 3, width: 20, color: const Color(0xFF07C160)),
        ],
      ),
    );
  }
}