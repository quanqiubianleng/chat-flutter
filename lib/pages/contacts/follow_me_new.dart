// lib/pages/new_subscribers_page.dart

import 'package:dio/dio.dart';
import 'package:education/config/app_config.dart';
import 'package:flutter/material.dart';

import 'package:education/core/global.dart';
import 'package:education/core/utils/conversation.dart';
import 'package:education/core/utils/timer.dart';
import 'package:education/core/websocket/ws_event.dart';
import 'package:education/pb/protos/chat.pb.dart';
import 'package:education/providers/user_provider.dart';
import 'package:education/services/user_service.dart';
import 'package:education/core/sqlite/follower_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';

import '../../modules/chat/models/offline_follower.dart';
import '../../providers/follower_provider.dart';
import '../user/user_info.dart';

class NewSubscribersPage extends ConsumerStatefulWidget {
  const NewSubscribersPage({Key? key}) : super(key: key);

  @override
  ConsumerState<NewSubscribersPage> createState() => _NewSubscribersPageState();
}

class _NewSubscribersPageState extends ConsumerState<NewSubscribersPage> {
  late final UserApi api;
  late FollowerRepository followerRepo;

  @override
  void initState() {
    super.initState();
    api = UserApi();
    followerRepo = ref.read(followerRepositoryProvider);
    // 进入「新增关注」页时：本地标记已读并通知服务端，角标与列表统一清零
    WidgetsBinding.instance.addPostFrameCallback((_) => _markNewFollowAsRead());
  }

  /// 本地 + 服务端均标记「关注我的」为已读
  Future<void> _markNewFollowAsRead() async {
    final userId = ref.read(userProvider).value;
    if (userId == null || userId <= 0) return;
    await followerRepo.markAllFollowAsRead(userId);
    try {
      await api.markFollowRead();
    } catch (_) {}
  }

  /// 时间戳转展示文案（支持秒或毫秒）
  static String _formatCreatedAt(int ts) {
    if (ts <= 0) return '未知时间';
    final sec = ts > 10000000000 ? ts ~/ 1000 : ts;
    return timestampToDateManual(sec);
  }

  /// 关注 / 取消关注（列表由 provider 驱动，无需 setState 更新列表）
  Future<void> _toggleFollow(int toUserId, bool isFollowed) async {
    final uidAsync = ref.read(userProvider);
    final uid = uidAsync.value;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }

    try {
      final resp = await api.follower({"userId": toUserId});

      bool success = resp['code'] == HttpStatus.success;
      String msg = resp['msg'] ?? (isFollowed ? '取消关注成功' : '关注成功');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

      if (success) {
        if (isFollowed) {
          await followerRepo.unfollow(uid, toUserId);
        } else {
          await followerRepo.follow(uid, toUserId);
        }

        final type = isFollowed ? "unfollow" : "follow";

        final tempClientMsgId = const Uuid().v4();
        final tempTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
        final convID = generateTempConversationId(isGroup: false, userIdA: toUserId, userIdB: uid);

        final msg = Event()
          ..delivery = WSDelivery.single
          ..type = type
          ..fromUser = Int64(uid)
          ..toUser = Int64(toUserId)
          ..clientMsgId = tempClientMsgId          // 客户端防重
          ..content = '关注了你'
          ..timestamp = Int64(tempTimestamp);

        ws.send(msg);

        if (resp["isFriend"]){
          final msg2 = Event()
            ..delivery = WSDelivery.single
            ..type = WSEventType.message
            ..fromUser = Int64(uid)
            ..toUser = Int64(toUserId)
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
        SnackBar(content: Text(isFollowed ? '取消关注失败' : '关注失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uidAsync = ref.watch(userProvider);
    final userId = uidAsync.value;
    // 列表展示「所有关注我的人」，不区分是否已读；角标仍为未读数量
    final fansAsync = ref.watch(followerMeProvider);
    final followingList = ref.watch(followerMyProvider).valueOrNull ?? [];
    final followingIds = followingList.map((e) => e.toUserId).toSet();

    final allFans = fansAsync.valueOrNull ?? [];
    final displayList = allFans.map((f) {
      return {
        'userId': f.fromUserId,
        'username': f.name ?? '匿名用户',
        'wallet_address': f.address ?? '',
        'avatar_url': f.avatarUrl ?? '',
        'create_at': _formatCreatedAt(f.createdAt),
        'is_friend': followingIds.contains(f.fromUserId),
      };
    }).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '新关注者',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const TextField(
                decoration: InputDecoration(
                  hintText: '搜索',
                  hintStyle: TextStyle(color: Colors.grey),
                  prefixIcon: Icon(Icons.search, color: Colors.grey),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
          const Divider(height: 1, thickness: 0.5, color: Color(0xFFE5E5E5)),

          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await getOfflineFollowerList(userId);
              },
              child: Builder(
                builder: (context) {
                  if (fansAsync.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (displayList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Image.asset(
                            'assets/images/error.png',
                            height: 150,
                            color: Colors.grey[300],
                            colorBlendMode: BlendMode.modulate,
                            errorBuilder: (context, error, stackTrace) {
                              return const Icon(Icons.image_not_supported, size: 120, color: Colors.grey);
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '暂无新关注者哦',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: displayList.length,
                    itemBuilder: (context, index) {
                      final follower = displayList[index];
                      final bool isMutual = follower['is_friend'] == true || follower['is_friend'] == 2;

                      return Column(
                        children: [
                          ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserInfo(
                                    userId: (follower['userId'] as int?) ?? 0,
                                    // 你可以根据需要传更多字段
                                  ),
                                ),
                              );
                            },
                            contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            leading: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: SizedBox(
                                width: 46,
                                height: 46,
                                child: ((follower['avatar_url'] as String?) ?? '').isNotEmpty
                                    ? Image.network(
                                  (follower['avatar_url'] as String?) ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    size: 30,
                                    color: Colors.orange,
                                  ),
                                )
                                    : const Icon(
                                  Icons.person,
                                  size: 30,
                                  color: Colors.orange,
                                ),
                              ),
                            ),
                            title: Text(
                              (follower['username'] as String?) ?? '未知用户',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              '${follower['create_at']}   关注了你',
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                // TODO: 调用关注接口
                                // await api.followUser(follower['userId']);

                                if (isMutual) {
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: const Text('提示信息'),
                                        content: const Text('确定取消关注吗？'),
                                        actions: <Widget>[
                                          TextButton(
                                            child: const Text('取消'),
                                            onPressed: () => Navigator.of(context).pop(),
                                          ),
                                          TextButton(
                                            child: const Text('确定'),
                                            onPressed: () {
                                              Navigator.of(context).pop();
                                              _toggleFollow(follower['userId'] as int, isMutual);
                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                } else {
                                  _toggleFollow(follower['userId'] as int, isMutual);
                                }
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: isMutual ? Colors.grey : Colors.green,
                                side: BorderSide(
                                  color: isMutual ? Colors.grey : Colors.green,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                elevation: 0,
                                minimumSize: const Size(80, 32),
                              ),
                              child: Text(
                                isMutual ? '朋友' : '关注',
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                          ),
                          Divider(
                            height: 1,
                            thickness: 0.5,
                            indent: 78, // 与头像右侧对齐
                            endIndent: 16,
                            color: Colors.grey[200],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}