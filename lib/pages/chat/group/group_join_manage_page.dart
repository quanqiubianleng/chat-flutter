import 'package:flutter/material.dart';

import 'package:education/services/group_service.dart';
import 'package:education/pages/chat/group/group_join_requests_page.dart';
import 'package:education/pages/chat/group/group_gate_rules_page.dart';

class GroupJoinManagePage extends StatefulWidget {
  final int groupId;
  final int role;
  final int currentJoinMode;

  const GroupJoinManagePage({
    super.key,
    required this.groupId,
    required this.role,
    required this.currentJoinMode,
  });

  @override
  State<GroupJoinManagePage> createState() => _GroupJoinManagePageState();
}

class _GroupJoinManagePageState extends State<GroupJoinManagePage> {
  final GroupApi _api = GroupApi();
  late int _joinMode;
  bool _saving = false;

  bool get _canManage => widget.role > 0;

  @override
  void initState() {
    super.initState();
    _joinMode = widget.currentJoinMode;
  }

  Future<void> _saveJoinMode(int nextMode) async {
    if (!_canManage || _saving) return;
    final old = _joinMode;
    setState(() {
      _joinMode = nextMode;
      _saving = true;
    });
    try {
      final resp = await _api.updateGroupInfo({
        'group_id': widget.groupId,
        'join_mode': nextMode,
        'field': ['group_id', 'join_mode'],
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp['msg']?.toString() ?? '已更新进群设置')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _joinMode = old);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('更新失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        title: const Text('进群设置'),
        backgroundColor: const Color(0xFFF2F3F5),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                _modeItem(
                  title: '无条件加入',
                  subtitle: '用户可直接进群',
                  value: 0,
                ),
                const Divider(height: 1),
                _modeItem(
                  title: '申请后加入',
                  subtitle: '需要管理员审核通过',
                  value: 1,
                ),
                const Divider(height: 1),
                _modeItem(
                  title: '持仓门控(Token/NFT)',
                  subtitle: '需满足全部持仓规则（AND），请在下方配置规则',
                  value: 2,
                ),
                const Divider(height: 1),
                _modeItem(
                  title: '邀请制',
                  subtitle: '凭邀请码加入',
                  value: 3,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (_joinMode == 2 && _canManage)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => GroupGateRulesPage(
                        groupId: widget.groupId,
                        role: widget.role,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    children: [
                      Expanded(
                        child: Text(
                          '配置持仓规则',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                      ),
                      Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            ),
          if (_canManage)
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => GroupJoinRequestsPage(groupId: widget.groupId),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Row(
                  children: [
                    Expanded(
                      child: Text(
                        '入群申请管理',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Icon(Icons.chevron_right),
                  ],
                ),
              ),
            ),
          if (!_canManage)
            const Padding(
              padding: EdgeInsets.only(top: 4, left: 2),
              child: Text(
                '仅管理员或群主可修改进群方式和处理申请',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
        ],
      ),
    );
  }

  Widget _modeItem({
    required String title,
    required String subtitle,
    required int value,
  }) {
    return ListTile(
      onTap: _canManage ? () => _saveJoinMode(value) : null,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: _saving && _joinMode == value
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Radio<int>(
              value: value,
              groupValue: _joinMode,
              activeColor: const Color(0xFF07C160),
              onChanged: _canManage ? (_) => _saveJoinMode(value) : null,
            ),
    );
  }

}
