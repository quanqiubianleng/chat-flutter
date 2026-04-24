import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 关注与粉丝列表：隐藏我的关注列表、隐藏我的粉丝列表
class FollowListPrivacyPage extends StatefulWidget {
  const FollowListPrivacyPage({super.key});

  @override
  State<FollowListPrivacyPage> createState() => _FollowListPrivacyPageState();
}

class _FollowListPrivacyPageState extends State<FollowListPrivacyPage> {
  final UserApi _api = UserApi();
  bool _hideFollowingList = false;
  bool _hideFollowersList = false;
  bool _loading = true;

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
          _hideFollowingList = data['hide_following_list'] == true;
          _hideFollowersList = data['hide_followers_list'] == true;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleFollowing(bool value) async {
    setState(() => _hideFollowingList = value);
    try {
      await _api.updatePrivacySettings({'hide_following_list': value});
      if (mounted) Fluttertoast.showToast(msg: '已更新');
    } catch (e) {
      if (mounted) {
        setState(() => _hideFollowingList = !value);
        Fluttertoast.showToast(msg: '更新失败');
      }
    }
  }

  Future<void> _toggleFollowers(bool value) async {
    setState(() => _hideFollowersList = value);
    try {
      await _api.updatePrivacySettings({'hide_followers_list': value});
      if (mounted) Fluttertoast.showToast(msg: '已更新');
    } catch (e) {
      if (mounted) {
        setState(() => _hideFollowersList = !value);
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
          '关注与粉丝列表',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                const SizedBox(height: 24),
                Container(
                  color: Colors.white,
                  child: ListTile(
                    title: const Text(
                      '隐藏我的关注列表',
                      style: TextStyle(fontSize: 16, color: Color(0xFF252525)),
                    ),
                    trailing: Switch(
                      value: _hideFollowingList,
                      onChanged: _toggleFollowing,
                      activeColor: const Color(0xFF00D1A7),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade200, indent: 16, endIndent: 16),
                Container(
                  color: Colors.white,
                  child: ListTile(
                    title: const Text(
                      '隐藏我的粉丝列表',
                      style: TextStyle(fontSize: 16, color: Color(0xFF252525)),
                    ),
                    trailing: Switch(
                      value: _hideFollowersList,
                      onChanged: _toggleFollowers,
                      activeColor: const Color(0xFF00D1A7),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  ),
                ),
              ],
            ),
    );
  }
}
