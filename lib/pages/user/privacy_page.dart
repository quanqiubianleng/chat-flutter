import 'package:education/pages/user/blocked_users_page.dart';
import 'package:education/pages/user/follow_list_privacy_page.dart';
import 'package:education/pages/user/who_can_invite_group_page.dart';
import 'package:education/pages/user/who_can_pm_page.dart';
import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 隐私设置主页（与参考图一致：无左侧图标，仅文字 + 右箭头/开关）
class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key});

  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  final UserApi _api = UserApi();
  bool _showAssetsPublicly = true;
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
        setState(() {
          _showAssetsPublicly = data['show_assets_publicly'] == true;
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

  Future<void> _toggleShowAssets(bool value) async {
    setState(() => _showAssetsPublicly = value);
    try {
      await _api.updatePrivacySettings({'show_assets_publicly': value});
      if (mounted) Fluttertoast.showToast(msg: '已更新');
    } catch (e) {
      if (mounted) {
        setState(() => _showAssetsPublicly = !value);
        Fluttertoast.showToast(msg: '更新失败');
      }
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
          '隐私',
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
                const SizedBox(height: 24),
                _item(
                  title: '我屏蔽的用户',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                    size: 24,
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const BlockedUsersPage(),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
                _divider(),
                _item(
                  title: '谁可以私信我',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                    size: 24,
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const WhoCanPmPage()),
                    );
                    if (mounted) _load();
                  },
                ),
                _divider(),
                _item(
                  title: '谁可以邀请我入群',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                    size: 24,
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const WhoCanInviteGroupPage(),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
                _divider(),
                _item(
                  title: '关注与粉丝列表',
                  trailing: const Icon(
                    Icons.chevron_right_rounded,
                    color: Colors.grey,
                    size: 24,
                  ),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const FollowListPrivacyPage(),
                      ),
                    );
                    if (mounted) _load();
                  },
                ),
                _divider(),
                _item(
                  title: '公开展示我的资产',
                  trailing: Switch(
                    value: _showAssetsPublicly,
                    onChanged: _toggleShowAssets,
                    activeColor: const Color(0xFF00D1A7),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  Widget _item({
    required String title,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Container(
      color: Colors.white,
      child: ListTile(
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFF252525), fontSize: 16),
        ),
        trailing: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
      ),
    );
  }

  Widget _divider() =>
      Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16);
}
