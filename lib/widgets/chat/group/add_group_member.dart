import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_config.dart';
import '../../../core/global.dart';
import '../../../core/utils/conversation.dart';
import '../../../core/utils/get_string_uuid.dart';
import '../../../core/utils/timer.dart';
import '../../../core/websocket/ws_event.dart';
import '../../../pb/protos/chat.pb.dart' as pb;
import '../../../providers/chat_providers.dart';
import '../../../providers/user_provider.dart';
import '../../../services/group_service.dart';
import '../../../services/user_service.dart';
import 'package:fixnum/fixnum.dart';
import 'package:uuid/uuid.dart';

/// 选择成员弹窗组件（多选，固定高度80%，列表可滚动）
class AddGroupMember extends ConsumerStatefulWidget {
  final int groupId;
  final VoidCallback? onSaved; // 保存成功后的回调（可选）

  const AddGroupMember({super.key, required this.groupId, this.onSaved,});

  @override
  ConsumerState<AddGroupMember> createState() => _AddGroupMemberState();
}

class _AddGroupMemberState extends ConsumerState<AddGroupMember> {
  bool isLoading = true;      // 首次加载
  String? errorMessage;       // 错误信息
  late final UserApi api;
  late final GroupApi groupApi;

  // 新关注者列表
  List<Map<String, dynamic>> followList = [];
  // 群组成员id
  List<int> _groupMemberIds = [];

  // 记录选中的索引（多选）
  final Set<int> selectedIndices = {};

  @override
  void initState() {
    super.initState();
    api = UserApi();
    groupApi = GroupApi();
    _loadNewFollowers();
    _getGroupMemberIds();
  }

  /// 加载新关注者（支持下拉刷新）
  Future<void> _loadNewFollowers({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        isLoading = true;
        errorMessage = null;
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
      });
    }
  }

  /// 获取群组成员ids
  Future<void> _getGroupMemberIds() async {
    try {
      final response = await groupApi.getGroupMemberIds({
        "group_id": widget.groupId,
        "page": 1,
        "page_size": 100000,
      });

      print("GET Response: $response");

      final List<int> rawList =
      List<int>.from(response['member_ids'] ?? []);

      print("rawList");
      print(rawList);

      setState(() {
        _groupMemberIds = rawList;
      });
    } on DioError catch (e) {
      print("请求出错: ${e.message}");
      setState(() {
        errorMessage =
            e.response?.data?['message'] ?? e.message ?? '网络请求失败';
      });
    } catch (e) {
      print("解析异常: $e");   // 👈 建议加这个，方便以后排雷
      setState(() {
        errorMessage = '发生未知错误';
      });
    }
  }


  /// 添加群组成员
  Future<void> _addGroupMember() async {
    if (selectedIndices.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请至少选择一项！')),
      );
      return;
    }
    final curUserId = ref.watch(userProvider).value;
    List<int> memberIds = [];
    List<String> avatars = [];
    List<String> names = [];
    for (final index in selectedIndices) {
      final item = followList[index];

      final int userId = item['userId'];
      final String avatar = item['avatar_url'] ?? '';
      final String name = item['username'] ?? '';

      memberIds.add(userId);
      avatars.add(avatar);
      names.add(name);
    }
    try {
      final response = await groupApi.addGroupMember({"group_id": widget.groupId, "user_ids": memberIds, "avatar": avatars});
      print("GET Response: $response");

      if(response['code'] == HttpStatus.success){
        final tempClientMsgId = const Uuid().v4();
        final tempTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
        final convID = generateTempConversationId(userIdA: 0, userIdB: widget.groupId, isGroup: true);
        final myNick = ref.read(myNicknameProvider).valueOrNull?.trim();
        final myAvatar = ref.read(myAvatarProvider).valueOrNull ?? '';
        final tempMessage = pb.Event()
          ..clientMsgId = tempClientMsgId
          ..fromUser = Int64(curUserId!)
          ..toUser = Int64(widget.groupId)
          ..conversationId = convID
          ..groupId =  Int64(widget.groupId)
          ..delivery = WSDelivery.group
          ..type = WSEventType.addGroupMembers
          ..content = "添加了新成员 ${names.join('、')}"
          ..timestamp = Int64(tempTimestamp)
          ..senderNickname = (myNick != null && myNick.isNotEmpty) ? myNick : '群成员'
          ..senderAvatar = myAvatar
          ..status = WSMessageStatus.sent;

        // 保存到本地数据库 → 触发 Riverpod 实时更新 UI
        await ref.read(messageRepositoryProvider).saveMessage(tempMessage);
        // 发送消息
        if(response['show_new_member_tip'] == 0){
          ws.send(tempMessage);
        }
        print(tempMessage);

        // ✅ 2. 再显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('添加群组新成员成功'),
            duration: Duration(seconds: 2),
          ),
        );
        // 调用外部传入的回调
        widget.onSaved?.call();
        // 返回上一页（带结果可选）
        Navigator.pop(context, true);
        return; // 提前返回，避免重复关闭
      }
      // 如果失败，显示错误信息但不关闭弹窗
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['Msg'] ?? '添加新成员失败'),
          backgroundColor: Colors.red,
        ),
      );
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
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final dialogHeight = screenHeight * 0.9;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        toolbarHeight: 48,
        leading: const BackButton(color: Color.fromARGB(255, 56, 55, 55)),
        title: const Text(
          '邀请新成员',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        actions: [
          GestureDetector(
            onTap: () {
              print('点击了用户: ');
              print(selectedIndices);
              _addGroupMember();
            },
            child: Padding(
              padding: const EdgeInsets.only(right: 20),
              child: const Text(
                "完成",
                style: TextStyle(fontSize: 16, color: Colors.green),
              ),
            )
          )
        ],
      ),
      body: Container(
        height: dialogHeight,
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Divider(height: 1, color: Colors.grey[100]),
              // 搜索框
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: '搜索用户备注、名称或地址',
                    hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[600]),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),

              // 成员列表 - 可滚动
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  itemCount: followList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final item = followList[index];
                    // 是否存在群组内
                    bool exists = _groupMemberIds.contains(item['userId']);
                    final bool isSelected = exists || selectedIndices.contains(index);

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

                    return Stack(
                        children: [
                          InkWell(
                            onTap:  exists ? null : () {
                              setState(() {
                                if (isSelected) {
                                  selectedIndices.remove(index);
                                } else {
                                  selectedIndices.add(index);
                                }
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  // 头像
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: item['avatar_url'] != null
                                    ? Image.network(
                                      item['avatar_url'],
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                    )
                                        : Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.grey[300],
                                          child: const Icon(Icons.person, color: Colors.white, size: 28),
                                        ),
                                  ),
                                  const SizedBox(width: 12),

                                  // 名称和地址
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item['username'],
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          truncateString(item['wallet_address']),
                                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 类型标签 + 多选圆圈
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        item['is_friend']==2 ? "互为好友" : "我的关注",
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                                      ),
                                      const SizedBox(width: 16),
                                      Container(
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isSelected ? const Color(0xFF00D29D) : Colors.transparent,
                                          border: Border.all(
                                            color: isSelected ? const Color(0xFF00D29D) : Colors.grey[400]!,
                                            width: 2,
                                          ),
                                        ),
                                        child: isSelected ? const Icon(
                                          Icons.check,
                                          size: 14,
                                          color: Colors.white,
                                        ) : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // 👇 如果已在群内，覆盖一层白色半透明蒙层
                          if (exists)
                            Positioned.fill(
                              child: Container(
                                color: Colors.white.withOpacity(0.6),
                              ),
                            ),
                        ],
                    );
                  },
                ),
              ),

            ],
          ),
        ),
      )
    );
  }
}