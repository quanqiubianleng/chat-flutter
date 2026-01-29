import 'package:flutter/material.dart';

import '../../../config/app_config.dart';
import '../../../services/group_service.dart';

/// 群公告编辑页面组件
class GroupAnnouncementEditor extends StatefulWidget {
  final int groupId;
  final String notice;
  final int role;
  final VoidCallback? onSaved;

  const GroupAnnouncementEditor({
    super.key,
    required this.groupId,
    required this.notice,
    required this.role,
    this.onSaved,
  });

  @override
  State<GroupAnnouncementEditor> createState() =>
      _GroupAnnouncementEditorState();
}

class _GroupAnnouncementEditorState extends State<GroupAnnouncementEditor> {
  late TextEditingController _controller;
  bool _isSaving = false;
  bool _enabled = false;

  late final GroupApi api;

  @override
  void initState() {
    super.initState();
    api = GroupApi();
    _controller = TextEditingController();
    // 如果你有现有的公告内容，可以在这里初始化
    _controller.text = widget.notice;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请输入群公告内容')),
      );
      return;
    }
    setState(() => _isSaving = true);

    List<String> fields = [];
    fields.add("group_id");
    fields.add("notice");
    Map<String, dynamic> params = {
      "group_id": widget.groupId,
      "notice": text,
      "field":  fields
    };
    try {
      final response = await api.updateGroupInfo(params);

      print("_updateGroupInfo");
      print(response);
      if(response['code'] == HttpStatus.success){

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

    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('发生错误：$e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('公告'),
        actions: [
          if(widget.role.toInt() > 0) TextButton(
            onPressed: _isSaving ? null : () {
              if (_enabled) {
                _handleSave();
              } else {
                setState(() => _enabled = true);
              }
            },
            child: _isSaving
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            )
                : Text(
              _enabled ? '保存' : '编辑',
              style: const TextStyle(
                fontSize: 16,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
        child: TextField(
          controller: _controller,
          maxLines: null,
          minLines: 5,
          autofocus: false,
          decoration: InputDecoration(
            enabled: _enabled,
            hintText: '请输入入群公告',
            border: InputBorder.none,
            hintStyle: const TextStyle(
              color: Colors.grey,
              fontSize: 16,
            ),
            contentPadding: EdgeInsets.zero,
          ),
          style: const TextStyle(
            fontSize: 16,
            height: 1.5,
          ),
        ),
      ),
    );
  }
}