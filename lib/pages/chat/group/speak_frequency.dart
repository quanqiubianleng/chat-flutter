import 'package:education/config/app_config.dart';
import 'package:flutter/material.dart';

import '../../../core/global.dart';
import '../../../core/utils/conversation.dart';
import '../../../core/websocket/ws_event.dart';
import '../../../services/group_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:fixnum/fixnum.dart';
import '../../../providers/user_provider.dart';
import '../../../pb/protos/chat.pb.dart' as pb;

class SpeakFrequencyPage extends ConsumerStatefulWidget {
  final int groupId;
  final int currentLimit; // 0 表示不限制
  final VoidCallback onConfirm;

  const SpeakFrequencyPage({
    super.key,
    required this.groupId,
    required this.currentLimit,
    required this.onConfirm,
  });

  @override
  ConsumerState<SpeakFrequencyPage> createState() => _SpeakFrequencyPageState();
}

class _SpeakFrequencyPageState extends ConsumerState<SpeakFrequencyPage> {
  late int _selectedSeconds;

  // 选项列表：秒数 → 显示文本
  final List<Map<String, dynamic>> _options = [
    {'seconds': 0, 'label': '不限制制'},
    {'seconds': 5, 'label': '5 s'},
    {'seconds': 10, 'label': '10 s'},
    {'seconds': 15, 'label': '15 s'},
    {'seconds': 30, 'label': '30 s'},
    {'seconds': 60, 'label': '1 Minute'},
    {'seconds': 180, 'label': '3 Minute'},
    {'seconds': 300, 'label': '5 Minute'},
  ];

  late final GroupApi api;

  @override
  void initState() {
    super.initState();
    api = GroupApi();
    _selectedSeconds = widget.currentLimit;
  }

  String _formatDisplay(int seconds) {
    if (seconds == 0) return '不限制';
    if (seconds < 60) return '$seconds s';
    final min = seconds ~/ 60;
    return '$min Minute${min > 1 ? '' : ''}';
  }

  void _save() async {
    // 这里可以做保存逻辑，例如调用 API
    // print("保存群组 ${widget.groupId}");
    // print("新名称: ${_nameController.text}");
    // print("新简介: ${_descController.text}");
    List<String> fields = [];
    fields.add("group_id");
    fields.add("speak_frequency_limit");
    Map<String, dynamic> params = {
      "group_id": widget.groupId,
      "speak_frequency_limit": _selectedSeconds,
      "field":  fields
    };
    try {
      final response = await api.updateGroupInfo(params);
      print("_updateGroupInfo");
      print(params);
      print(response);


      if(response['code'] == HttpStatus.success){
        // 更新群组名称
        final convId = generateTempConversationId(userIdA: 0, userIdB: widget.groupId, isGroup: true);

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
          ..type = WSEventType.updateGroupSpeakLimit
          ..content = '${_selectedSeconds} s'
          ..timestamp = Int64(tempTimestamp)
          ..status = WSMessageStatus.sent;
        ws.send(tempMessage);
        // 调用外部传入的回调
        widget.onConfirm.call();

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
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '发言频率',
          style: TextStyle(fontSize: 16),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // 调用外部回调保存
              _save();
            },
            child: const Text(
              '确定',
              style: TextStyle(color: Colors.green, fontSize: 14),
            ),
          ),
        ],
      ),
      body: ListView(
        children: [
          const SizedBox(height: 12),

          ..._options.map((option) {
            final seconds = option['seconds'] as int;
            final isSelected = _selectedSeconds == seconds;
            final label = _formatDisplay(seconds);

            return ListTile(
              tileColor: Colors.white,
              title: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                ),
              ),
              shape: const Border(
                bottom: BorderSide(
                  color: Colors.grey,       // 边框颜色
                  width: 0.5,               // 粗细，建议 0.5~1.0
                ),
              ),
              trailing: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.greenAccent,
                      size: 24,
                    )
                  : const SizedBox(width: 24),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              onTap: () {
                setState(() {
                  _selectedSeconds = seconds;
                });
              },
            );
          }),

          const Padding(
            padding: EdgeInsets.fromLTRB(10, 10, 20, 12),
            child: Text(
              '除 MOD 外，其他群成员发送消息的冷却时间将受到限制',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}