import 'package:dio/dio.dart';
import 'package:education/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
class SelectMemberDialog extends ConsumerStatefulWidget {
  const SelectMemberDialog({super.key});

  @override
  ConsumerState<SelectMemberDialog> createState() => _SelectMemberDialogState();
}

class _SelectMemberDialogState extends ConsumerState<SelectMemberDialog> {
  bool isLoading = true;      // 首次加载
  String? errorMessage;       // 错误信息
  late final UserApi api;
  late final GroupApi groupApi;

  // 新关注者列表
  List<Map<String, dynamic>> followList = [];

  // 记录选中的索引（多选）
  final Set<int> selectedIndices = {};

  @override
  void initState() {
    super.initState();
    api = UserApi();
    groupApi = GroupApi();
    _loadNewFollowers();
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

  /// 创建群组
  Future<void> _createGroup(List<int> memberIds, List<String> names, List<String> avatars) async {
    if (memberIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('参数错误！')),
      );
      return;
    }

    final currentUid = ref.read(userProvider).value;
    final nickname = ref.read(myNicknameProvider).value;
    final avatar = ref.read(myAvatarProvider).value;
    names.insert(0, nickname!);
    avatars.insert(0, avatar!);
    String groupName = names.join('、 ');
    try {
      final response = await groupApi.createGroup({"owner_user_id": currentUid, "member_ids": memberIds, "name": groupName, "avatar": avatars});
      print("GET Response: $response");
      print(response['conversation_id']);
      print(response['group_id']);

      if(response['code'] == HttpStatus.success){
        final tempClientMsgId = const Uuid().v4();
        final tempTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000);
        final tempMessage = pb.Event()
          ..clientMsgId = tempClientMsgId
          ..fromUser = Int64(currentUid!)
          ..toUser = Int64(currentUid)
          ..conversationId = response['conversation_id']
          ..groupId =  Int64(response['group_id'])
          ..delivery = WSDelivery.group
          ..type = WSEventType.createGroup
          ..content = " 创建了群组"
          ..timestamp = Int64(tempTimestamp)
          ..senderNickname = groupName
          ..senderAvatar = avatars.join('、')
          ..status = WSMessageStatus.sent;

        // 保存到本地数据库 → 触发 Riverpod 实时更新 UI
        await ref.read(messageRepositoryProvider).saveMessage(tempMessage);
        // 发送消息
        ws.send(tempMessage);
        print(tempMessage);
        // 发送邀请提示
        for (String name in names) {
          print('名字: $name');
          tempMessage.content = " 邀请 $name 加入了群组";
          ws.send(tempMessage);
        }

        // ✅ 1. 先关闭底部弹窗
        if (Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        // ✅ 2. 再显示成功提示
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('创建群组 "${groupName}" 成功'),
            duration: Duration(seconds: 2),
          ),
        );

        return; // 提前返回，避免重复关闭
      }
      // 如果失败，显示错误信息但不关闭弹窗
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['Msg'] ?? '创建失败'),
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

    return Container(
      height: dialogHeight,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '选择成员',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 搜索框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: followList.length,
                separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
                itemBuilder: (context, index) {
                  final item = followList[index];
                  final bool isSelected = selectedIndices.contains(index);

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

                  return InkWell(
                    onTap: () {
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
                                child: isSelected
                                    ? const Icon(
                                  Icons.check,
                                  size: 14,
                                  color: Colors.white,
                                )
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            // 底部创建按钮
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: selectedIndices.isNotEmpty
                      ? () {
                    // TODO: 执行创建逻辑，例如获取选中的成员
                    final selectedMembers = selectedIndices.map((i) => followList[i]).toList();
                    print(selectedMembers);

                    // 提取三个数组
                    final List<int> userIds = selectedMembers
                        .map((member) => member['userId'] as int)
                        .toList();

                    final List<String> usernames = selectedMembers
                        .map((member) => member['username'] as String)
                        .toList();

                    final List<String> avatarUrls = selectedMembers
                        .map((member) => member['avatar_url'] as String? ?? '')
                        .toList();

                    _createGroup(userIds, usernames, avatarUrls);
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D29D),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text(
                    '创建',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}