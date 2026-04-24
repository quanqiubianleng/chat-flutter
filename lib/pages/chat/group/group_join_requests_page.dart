import 'package:flutter/material.dart';
import 'package:education/services/group_service.dart';

class GroupJoinRequestsPage extends StatefulWidget {
  final int groupId;

  const GroupJoinRequestsPage({super.key, required this.groupId});

  @override
  State<GroupJoinRequestsPage> createState() => _GroupJoinRequestsPageState();
}

class _GroupJoinRequestsPageState extends State<GroupJoinRequestsPage> {
  final GroupApi _api = GroupApi();
  bool _loading = true;
  List<Map<String, dynamic>> _list = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _asInt(dynamic v, [int d = 0]) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? d;
  }

  String _asString(dynamic v, [String d = '']) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? d : s;
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await _api.getJoinApplications({
        'group_id': widget.groupId,
        'page': 1,
        'page_size': 100,
      });
      final List<dynamic> data = resp['data'] ?? <dynamic>[];
      setState(() {
        _list = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('加载申请失败：$e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handle(int index, String action) async {
    final item = _list[index];
    final int applicationId = _asInt(item['application_id']);
    final int userId = _asInt(item['user_id']);
    if (applicationId <= 0 && userId <= 0) return;
    try {
      final resp = await _api.handleJoinApplication({
        'group_id': widget.groupId,
        'application_id': applicationId,
        'user_id': userId,
        'action': action,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_asString(resp['msg'], action == 'approve' ? '已通过' : '已拒绝'))),
      );
      setState(() {
        _list[index]['status'] = action == 'approve' ? 1 : 2;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('处理失败：$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        title: const Text('入群申请'),
        backgroundColor: const Color(0xFFF2F3F5),
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? const Center(child: Text('暂无待处理申请'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _list.length,
                    itemBuilder: (context, index) {
                      final item = _list[index];
                      final avatar = _asString(item['avatar_url']);
                      final name = _asString(item['username'], '未知用户');
                      final reason = _asString(item['reason'], '未填写申请理由');
                      final status = _asInt(item['status']);
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: avatar.isNotEmpty
                                  ? Image.network(
                                      avatar,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => _fallbackAvatar(),
                                    )
                                  : _fallbackAvatar(),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    name,
                                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    reason,
                                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                                  ),
                                  const SizedBox(height: 10),
                                  if (status == 0)
                                    Row(
                                      children: [
                                        _actionButton(
                                          text: '拒绝',
                                          bg: const Color(0xFFF3F4F6),
                                          fg: const Color(0xFF475467),
                                          onTap: () => _handle(index, 'reject'),
                                        ),
                                        const SizedBox(width: 8),
                                        _actionButton(
                                          text: '通过',
                                          bg: const Color(0xFF07C160),
                                          fg: Colors.white,
                                          onTap: () => _handle(index, 'approve'),
                                        ),
                                      ],
                                    )
                                  else
                                    Text(
                                      status == 1 ? '已通过' : '已拒绝',
                                      style: TextStyle(
                                        color: status == 1 ? const Color(0xFF1B9A4B) : const Color(0xFFB42318),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _fallbackAvatar() {
    return Container(
      width: 44,
      height: 44,
      color: const Color(0xFFEBEEF2),
      child: const Icon(Icons.person, color: Colors.black38),
    );
  }

  Widget _actionButton({
    required String text,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
      ),
    );
  }
}
