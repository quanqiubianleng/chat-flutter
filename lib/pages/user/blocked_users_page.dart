import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 我屏蔽的用户列表，支持移除屏蔽
class BlockedUsersPage extends StatefulWidget {
  const BlockedUsersPage({super.key});

  @override
  State<BlockedUsersPage> createState() => _BlockedUsersPageState();
}

class _BlockedUsersPageState extends State<BlockedUsersPage> {
  final UserApi _api = UserApi();
  List<Map<String, dynamic>> _list = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getBlockedUsers();
      if (mounted) {
        final raw = data['data'];
        setState(() {
          _list = raw is List
              ? (raw as List)
                  .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
                  .toList()
              : [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _unblock(int userId) async {
    try {
      await _api.unblockUser(userId);
      if (mounted) {
        setState(() => _list.removeWhere((e) => (e['userId'] as num?)?.toInt() == userId));
        Fluttertoast.showToast(msg: '已移除屏蔽');
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '操作失败');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '我屏蔽的用户',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _list.isEmpty
              ? Center(
                  child: Text(
                    '暂无屏蔽用户',
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                  ),
                )
              : ListView.separated(
                  itemCount: _list.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final u = _list[i];
                    final userId = (u['userId'] as num?)?.toInt();
                    final name = u['username']?.toString() ?? '未知';
                    final avatar = u['avatar_url']?.toString();
                    return Container(
                      color: Colors.white,
                      child: ListTile(
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: Colors.grey.shade400,
                          backgroundImage: avatar != null && avatar.isNotEmpty
                              ? NetworkImage(avatar)
                              : null,
                          child: avatar == null || avatar.isEmpty
                              ? Text(
                                  name.isNotEmpty ? name[0] : '?',
                                  style: const TextStyle(color: Colors.white, fontSize: 18),
                                )
                              : null,
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontSize: 16, color: Color(0xFF252525)),
                        ),
                        trailing: TextButton(
                          onPressed: userId != null
                              ? () async {
                                  await _unblock(userId);
                                }
                              : null,
                          child: const Text('移除', style: TextStyle(color: Color(0xFF00D1A7))),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      ),
                    );
                  },
                ),
    );
  }
}
