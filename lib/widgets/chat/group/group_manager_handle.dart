import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_config.dart';
import '../../../core/utils/get_string_uuid.dart';
import '../../../modules/chat/models/group_member.dart';
import '../../../services/group_service.dart';
import '../../../services/user_service.dart';

/// 选择成员弹窗组件（多选，固定高度80%，列表可滚动）
class GroupManagerHandle extends ConsumerStatefulWidget {
  final int groupId;

  const GroupManagerHandle({super.key, required this.groupId,});

  @override
  ConsumerState<GroupManagerHandle> createState() => _GroupManagerHandleState();
}

class _GroupManagerHandleState extends ConsumerState<GroupManagerHandle> {
  bool isLoading = true;      // 首次加载
  String? errorMessage;       // 错误信息
  late final UserApi api;
  late final GroupApi groupApi;

  // 群组成员列表
  List<GroupMember> _groupMemberList = [];
  int page = 1;
  int pageSize = 100;

  // 记录选中的索引（多选）
  final Set<int> selectedIndices = {};

  @override
  void initState() {
    super.initState();
    api = UserApi();
    groupApi = GroupApi();
    _loadNewFollowers();
  }

  /// 加载群组成员（支持下拉刷新）
  Future<void> _loadNewFollowers({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });
    }

    try {
      final response = await groupApi.getGroupMembers({"group_id": widget.groupId, "page": page, "page_size": pageSize});
      print("GET Response: $response");

      final List<dynamic> rawList = response['data'] ?? [];

      final List<GroupMember> members = rawList
          .map((item) => GroupMember.fromJson(item as Map<String, dynamic>))
          .toList();

      setState(() {
        _groupMemberList = members;
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

  // 移除、添加管理员
  Future<void> _handleManager(int index) async {

    final old = _groupMemberList[index];
    final newRole = old.role == 1 ? 0 : 1;
    Map<String, dynamic> params = {
      "group_id": widget.groupId,
      "user_id": _groupMemberList[index].userId,
      "role":  newRole
    };
    try {
      final response = await groupApi.handleGroupManager(params);

      print("_handleManager");
      print(response);
      if(response['code'] == HttpStatus.success){
        // 模拟保存成功
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg']),
            duration: Duration(seconds: 2),
          ),
        );
        setState(() {
          _groupMemberList[index] = old.copyWith(role: newRole);
        });
        return;
      }
      // 模拟保存失败
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['msg']),
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误：$e')),
      );
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
          '管理员',
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 18),
        ),
        actions: [

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
                  itemCount: _groupMemberList.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, thickness: 0.5),
                  itemBuilder: (context, index) {
                    final item = _groupMemberList[index];
                    // 是否是管理员
                    bool exists = item.role > 0;

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
                    if (_groupMemberList.isEmpty) {
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
                            onTap: () {
                              // _handleManager(index);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  // 头像
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: item.avatarUrl != ""
                                    ? Image.network(
                                      item.avatarUrl,
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
                                        Row(
                                          children: [
                                            Text(
                                              item.username,
                                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                            ),
                                            const SizedBox(width: 5),
                                            if(exists) Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.green[300], // 淡绿色
                                                borderRadius: BorderRadius.circular(8), // 小圆角
                                              ),
                                              child: Text(
                                                item.role == 2 ? "群主" : "管理员",
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.black45,
                                                  height: 1.2,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          truncateString(item.walletAddress),
                                          style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // 类型标签 + 多选圆圈
                                  if(item.role < 2) Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        onTap: () {
                                          _handleManager(index);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.only(right: 20),
                                          child: Text(
                                            exists ? "移除" : "添加",
                                            style: const TextStyle(fontSize: 16, color: Colors.green),
                                          ),
                                        )
                                      )
                                    ],
                                  ),
                                ],
                              ),
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