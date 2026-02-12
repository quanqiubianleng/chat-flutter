// 关注页：数据与通讯录「关注数」一致，来自本地 SQLite

import 'package:education/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/core/utils/get_string_uuid.dart';
import 'package:education/core/utils/timer.dart';
import 'package:education/services/user_service.dart';
import 'package:education/providers/user_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import 'package:education/core/global.dart';
import 'package:education/core/utils/conversation.dart';
import 'package:education/core/websocket/ws_event.dart';
import 'package:education/pb/protos/chat.pb.dart';

import 'package:education/core/sqlite/follower_repository.dart';
import 'package:education/providers/follower_provider.dart';
import 'package:education/widgets/common/empty_state_view.dart';
import 'package:education/modules/chat/models/offline_follower.dart';

import '../user/user_info.dart';

class ISubscribersPage extends ConsumerStatefulWidget {
  const ISubscribersPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ISubscribersPage> createState() => _ISubscribersPageState();
}

class _ISubscribersPageState extends ConsumerState<ISubscribersPage> {
  late final UserApi api;
  late FollowerRepository followerRepo;

  @override
  void initState() {
    super.initState();
    api = UserApi();
    followerRepo = ref.read(followerRepositoryProvider);
  }

  static String _formatCreatedAt(int ts) {
    if (ts <= 0) return '未知时间';
    final sec = ts > 10000000000 ? ts ~/ 1000 : ts;
    return timestampToDateManual(sec);
  }

  Future<void> _toggleFollow(int toUserId, bool isFollowed) async {
    final uid = ref.read(userProvider).value;
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

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
          ..clientMsgId = tempClientMsgId
          ..content = '关注了你'
          ..timestamp = Int64(tempTimestamp);
        ws.send(msg);
        if (resp["isFriend"] == true) {
          final msg2 = Event()
            ..delivery = WSDelivery.single
            ..type = WSEventType.message
            ..fromUser = Int64(uid)
            ..toUser = Int64(toUserId)
            ..conversationId = convID
            ..clientMsgId = tempClientMsgId
            ..content = '我们已互相关注，可以开始聊天了'
            ..timestamp = Int64(tempTimestamp);
          ws.send(msg2);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isFollowed ? '取消关注失败' : '关注失败')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final followingAsync = ref.watch(followerMyProvider);
    final fansFromMe = ref.watch(followerMeProvider).valueOrNull ?? [];
    final fansFromMeIds = fansFromMe.map((e) => e.fromUserId).toSet();

    final list = followingAsync.valueOrNull ?? [];
    final displayList = list.map((f) {
      return {
        'userId': f.toUserId,
        'username': f.name ?? '匿名用户',
        'wallet_address': f.address ?? '',
        'avatar_url': f.avatarUrl ?? '',
        'create_at': _formatCreatedAt(f.createdAt),
        'is_friend': fansFromMeIds.contains(f.toUserId),
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
          '关注',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
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
                final uid = ref.read(userProvider).value;
                if (uid != null) await getOfflineFollowerList(uid);
              },
              child: Builder(
                builder: (context) {
                  if (followingAsync.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (displayList.isEmpty) {
                    return const EmptyStateView();
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
                              truncateString((follower['wallet_address'] as String?) ?? ''),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                final uid = follower['userId'] as int;
                                if (isMutual) {
                                  showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                      title: const Text('提示信息'),
                                      content: const Text('确定取消关注吗？'),
                                      actions: <Widget>[
                                        TextButton(
                                          child: const Text('取消'),
                                          onPressed: () => Navigator.of(ctx).pop(),
                                        ),
                                        TextButton(
                                          child: const Text('确定'),
                                          onPressed: () {
                                            Navigator.of(ctx).pop();
                                            _toggleFollow(uid, isMutual);
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                } else {
                                  _toggleFollow(uid, isMutual);
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
                                isMutual ? '朋友' : '已关注',
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