// lib/pages/new_subscribers_page.dart

import 'package:dio/dio.dart';
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

import '../user/user_info.dart';

class ISubscribersPage extends ConsumerStatefulWidget {
  const ISubscribersPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ISubscribersPage> createState() => _ISubscribersPageState();
}

class _ISubscribersPageState extends ConsumerState<ISubscribersPage> {
  // 新关注者列表
  List<Map<String, dynamic>> followList = [];

  // 界面状态
  bool isLoading = true;      // 首次加载
  bool isRefreshing = false;  // 下拉刷新中
  String? errorMessage;       // 错误信息

  late final UserApi api;
  late FollowerRepository followerRepo;

  @override
  void initState() {
    super.initState();
    api = UserApi();
    // 延迟获取 context
    followerRepo = ref.read(followerRepositoryProvider);
    _loadNewFollowers();
  }

  /// 加载新关注者（支持下拉刷新）
  Future<void> _loadNewFollowers({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    } else {
      setState(() {
        isRefreshing = true;
      });
    }

    try {
      final response = await api.getFollowerList({"type": 1});
      print("GET Response: $response");

      final List<dynamic> rawList = response['data'] ?? [];
      final List<Map<String, dynamic>> processedList = rawList.map((item) {
        final map = item as Map<String, dynamic>;
        return {
          "userId": map['userId'] ?? '',
          "username": map['username'] ?? "匿名用户",
          "wallet_address": map['wallet_address'] ?? '',
          "avatar_url": map['avatar_url'] ?? '',
          "create_at": timestampToDateManual(map['create_at'] ?? 0),
          "is_friend": map['is_friend'], // 是否已互关
        };
      }).toList();

      setState(() {
        followList = processedList;
      });
    } on DioError catch (e) {
      print("请求出错: ${e.message}");
      setState(() {
        errorMessage = e.response?.data?['message'] ?? e.message ?? '网络请求失败';
      });
    } catch (e) {
      setState(() {
        errorMessage = '发生未知错误';
      });
    } finally {
      setState(() {
        isLoading = false;
        isRefreshing = false;
      });
    }
  }

  /// 关注 / 取消关注
  Future<void> _toggleFollow(int toUserId, bool _isFollowed, int index) async {

    final uidAsync =  ref.read(userProvider);
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
      String msg = resp['msg'] ?? (_isFollowed ? '取消关注成功' : '关注成功');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );

      if (success) {
        // 1. 更新本地状态
        setState(() {
          followList[index] = {
            ...followList[index], // 保留原有字段
            "is_friend": !_isFollowed, // 切换状态
          };
        });
        // 关注更新sqlite
        if(_isFollowed){
          await followerRepo.unfollow(uid, toUserId);
          _loadNewFollowers();
        }else{
          await followerRepo.follow(uid, toUserId);
        }

        final type = _isFollowed ? "unfollow" : "follow";
        setState(() {
          _isFollowed = !_isFollowed;
        });

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
        SnackBar(content: Text(_isFollowed ? '取消关注失败' : '关注失败')),
      );
    } finally {

    }
  }

  @override
  Widget build(BuildContext context) {
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
          // 搜索栏（预留）
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

          // 列表主体
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _loadNewFollowers(isRefresh: true),
              child: Builder(
                builder: (context) {
                  // 加载中（首次）
                  if (isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // 错误状态
                  if (errorMessage != null) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, size: 64, color: Colors.grey),
                          const SizedBox(height: 16),
                          Text(
                            '加载失败：$errorMessage',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadNewFollowers,
                            child: const Text('重试'),
                          ),
                        ],
                      ),
                    );
                  }

                  // 空数据
                  if (followList.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,  // 让 Column 只占用内容所需空间
                        children: [
                          Image.asset(
                            'assets/images/error.png',
                            height: 150,
                            color: Colors.grey[300],
                            colorBlendMode: BlendMode.modulate,
                            errorBuilder: (context, error, stackTrace) {
                              print('Asset 加载失败: $error');
                              return const Icon(Icons.image_not_supported, size: 120, color: Colors.grey);
                            },
                          ),
                          const SizedBox(height: 20),
                          Text(
                            '您还没有关注任何人哦',
                            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
                          ),

                        ],
                      ),
                    );
                  }

                  // 正常列表
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(), // 确保能下拉刷新
                    itemCount: followList.length,
                    itemBuilder: (context, index) {
                      final follower = followList[index];
                      final bool isMutual = follower['is_friend'] == 2;

                      return Column(
                        children: [
                          ListTile(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => UserInfo(
                                    userId: follower['userId'] ?? 0,
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
                                child: (follower['avatar_url'] as String?)?.isNotEmpty == true
                                    ? Image.network(
                                  follower['avatar_url'],
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
                              follower['username'] ?? '未知用户',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              truncateString(follower['wallet_address']),
                              style: const TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () async {
                                // TODO: 调用关注接口
                                if(isMutual){
                                  showDialog(
                                    context: context,
                                    builder: (BuildContext context) {
                                      return AlertDialog(
                                        title: Text('提示信息'),
                                        content: Text('确定取消关注吗？'),
                                        actions: <Widget>[
                                          TextButton(
                                            child: Text('取消'),
                                            onPressed: () {
                                              Navigator.of(context).pop(); // 关闭对话框
                                              print('用户点击了取消');
                                            },
                                          ),
                                          TextButton(
                                            child: Text('确定'),
                                            onPressed: () {
                                              Navigator.of(context).pop(); // 关闭对话框
                                              print('用户点击了确定');
                                              _toggleFollow(follower['userId'], isMutual, index);
                                              // 执行确定操作

                                            },
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                }else{
                                  _toggleFollow(follower['userId'], isMutual, index);
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