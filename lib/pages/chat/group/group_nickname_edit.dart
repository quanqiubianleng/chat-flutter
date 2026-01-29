import 'dart:ffi';

import 'package:education/config/app_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/global.dart';
import '../../../core/utils/conversation.dart';
import '../../../core/websocket/ws_event.dart';
import '../../../pb/protos/chat.pb.dart' as pb;
import '../../../providers/chat_providers.dart';
import '../../../providers/user_provider.dart';
import '../../../services/group_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';

class GroupEditPage extends ConsumerStatefulWidget {
  final int groupId;
  final int role;
  final String name;
  final String avatar;
  final String description;
  final VoidCallback? onSaved; // 保存成功后的回调（可选）

  const GroupEditPage({
    super.key,
    required this.groupId,
    required this.role,
    required this.name,
    required this.avatar,
    required this.description,
    this.onSaved,
  });

  @override
  ConsumerState<GroupEditPage> createState() => _GroupEditPageState();
}

class _GroupEditPageState extends ConsumerState<GroupEditPage> {
  late TextEditingController _nameController;
  late TextEditingController _descController;

  // 你可以在这里初始化默认值（实际项目中通常从接口获取）
  late String initialName = widget.name;
  late String initialAvatar = widget.avatar;
  late String initialDesc = widget.description;

  late final GroupApi api;

  @override
  void initState() {
    super.initState();
    api = GroupApi();
    _nameController = TextEditingController(text: initialName);
    _descController = TextEditingController(text: initialDesc);

    // 监听文字变化（可选，用于实时更新字符计数）
    _descController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _save() async {
    // 这里可以做保存逻辑，例如调用 API
    // print("保存群组 ${widget.groupId}");
    // print("新名称: ${_nameController.text}");
    // print("新简介: ${_descController.text}");
    List<String> fields = [];
    fields.add("group_id");
    fields.add("name");
    fields.add("description");
    Map<String, dynamic> params = {
      "group_id": widget.groupId,
      "name": _nameController.text,
      "description": _descController.text,
      "field":  fields
    };
    try {
      final response = await api.updateGroupInfo(params);

      print("_updateGroupInfo");
      print(response);

      if(response['code'] == HttpStatus.success){
        // 更新群组名称
        final convId = generateTempConversationId(userIdA: 0, userIdB: widget.groupId, isGroup: true);
        await ref.read(messageRepositoryProvider).updateConvTitle(convId, _nameController.text);

        // 通知ws
        // 用 Riverpod 获取当前 UID
        final uidAsync = await ref.read(userProvider.future);
        final currentUid = uidAsync;
        // 1. 生成临时消息（乐观显示）
        final tempClientMsgId = const Uuid().v4();
        final tempTimestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000);


        final tempMessage = pb.Event()
          ..clientMsgId = tempClientMsgId
          ..fromUser = Int64(currentUid!)
          ..toUser = Int64(currentUid!)
          ..conversationId = convId
          ..groupId = Int64(widget.groupId)
          ..delivery = WSDelivery.group
          ..type = WSEventType.updateGroupTitle
          ..content = _nameController.text
          ..timestamp = Int64(tempTimestamp)
          ..senderNickname = _nameController.text
          ..status = WSMessageStatus.sent; // 可在 MessageBubble 中显示“发送中”
        ws.send(tempMessage);
        // 调用外部传入的回调
        widget.onSaved?.call();

        // 模拟保存成功
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['msg']),
            duration: Duration(seconds: 2),
          ),
        );

        // 返回上一页（带结果可选）
        Navigator.pop(context, true);
        return;
      }
      // 模拟保存失败
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response['msg']),
          duration: Duration(seconds: 2),
        ),
      );

    } catch (e, stackTrace) {
      print("_updateGroupInfo error: $e");
      print(stackTrace);

    }
  }

  @override
  Widget build(BuildContext context) {
    final descLength = _descController.text.length;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text("群资料"),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _save,
            child: Text(
              "保存",
              style: TextStyle(
                color: Colors.green[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(), // 推荐用这个更稳
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, // 左对齐，跟之前 ListView 效果一致
              children: [
                // 群头像区域
                Container(
                  height: 180,
                  margin: const EdgeInsets.only(bottom: 32),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF2C3E50), Color(0xFF4CA1AF)],
                    ),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildAvatar("https://bbt-bucket-public.oss-cn-hongkong.aliyuncs.com/avatar_s/1.png", 0),
                      ],
                    ),
                  ),
                ),

                // 群名称
                const Text(
                  "群名称",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    hintText: "请输入群名称",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  maxLength: 30,
                  cursorColor: Colors.green,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                ),
                const SizedBox(height: 32),

                // 群简介
                const Text(
                  "群简介",
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _descController,
                  maxLines: 5,
                  minLines: 4,
                  maxLength: 80,
                  cursorColor: Colors.green,
                  decoration: InputDecoration(
                    hintText: "请输入群简介",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: const BorderSide(color: Colors.green),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                    counterText: "$descLength/80",
                    counterStyle: TextStyle(
                      color: descLength > 70 ? Colors.orange : Colors.grey,
                    ),
                  ),
                ),

                // 可选：底部多留点空间，防止键盘弹出时最后一个输入框被完全挡住
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String url, int index) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[800],
              child: Icon(
                index == 0 ? Icons.favorite : Icons.pets,
                color: Colors.white,
                size: 40,
              ),
            );
          },
        ),
      ),
    );
  }
}