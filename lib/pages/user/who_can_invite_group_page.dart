import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 谁可以邀请我入群：全部、我关注的人、互相关注的人、禁止任何人邀请我 + 入群验证开关
class WhoCanInviteGroupPage extends StatefulWidget {
  const WhoCanInviteGroupPage({super.key});

  @override
  State<WhoCanInviteGroupPage> createState() => _WhoCanInviteGroupPageState();
}

class _WhoCanInviteGroupPageState extends State<WhoCanInviteGroupPage> {
  final UserApi _api = UserApi();
  static const options = [
    ('all', '全部', '允许任何人邀请我加入群聊'),
    ('following', '我关注的人', '仅限我关注的用户邀请我入群'),
    ('mutual', '互相关注的人', '只有互相关注的用户可以邀请我入群'),
    ('none', '禁止任何人邀请我', '关闭邀请功能,不接受任何入群邀请'),
  ];
  String _canInvite = 'all';
  bool _groupJoinVerify = true;
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getPrivacySettings();
      if (mounted) {
        final v = data['can_invite_to_group']?.toString() ?? 'all';
        setState(() {
          _canInvite = options.any((e) => e.$1 == v) ? v : 'all';
          _groupJoinVerify = data['group_join_verify'] == true;
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _selectInvite(String value) async {
    if (_canInvite == value) return;
    final previous = _canInvite;
    setState(() => _canInvite = value);
    try {
      await _api.updatePrivacySettings({'can_invite_to_group': value});
      if (mounted) Fluttertoast.showToast(msg: '已更新');
    } catch (e) {
      if (mounted) {
        setState(() => _canInvite = previous);
        Fluttertoast.showToast(msg: '更新失败');
      }
    }
  }

  Future<void> _toggleVerify(bool value) async {
    setState(() => _groupJoinVerify = value);
    try {
      await _api.updatePrivacySettings({'group_join_verify': value});
      if (mounted) Fluttertoast.showToast(msg: '已更新');
    } catch (e) {
      if (mounted) {
        setState(() => _groupJoinVerify = !value);
        Fluttertoast.showToast(msg: '更新失败');
      }
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '谁可以邀请我入群',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('加载失败，请重试'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            )
          : ListView(
              children: [
                for (final opt in options)
                  InkWell(
                    onTap: () => _selectInvite(opt.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  opt.$2,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    color: Color(0xFF252525),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  opt.$3,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_canInvite == opt.$1)
                            const Icon(
                              Icons.check,
                              color: Color(0xFF00D1A7),
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '邀请我入群时需要验证',
                          style: TextStyle(
                            fontSize: 16,
                            color: Color(0xFF252525),
                          ),
                        ),
                      ),
                      Switch(
                        value: _groupJoinVerify,
                        onChanged: _toggleVerify,
                        activeColor: const Color(0xFF00D1A7),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}
