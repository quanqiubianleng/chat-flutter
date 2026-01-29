import 'package:education/pages/user/user_info.dart';
import 'package:education/services/user_service.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SearchUser extends StatefulWidget {
  const SearchUser({super.key});

  @override
  State<SearchUser> createState() => _SearchUserState();
}

class _SearchUserState extends State<SearchUser> {
  final api = UserApi();
  final TextEditingController _searchController = TextEditingController();

  // 搜索结果用户列表
  List<Map<String, dynamic>> _searchResults = [];
  bool _isLoading = false;
  String _currentKeyword = '';

  @override
  void initState() {
    super.initState();
    // 监听输入框变化，防抖可自行加（如使用 debounce）
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) {
      setState(() {
        _searchResults = [];
        _currentKeyword = '';
      });
      return;
    }

    if (keyword == _currentKeyword) return; // 避免重复搜索

    _currentKeyword = keyword;
    _searchAccount(keyword);
  }

  /// 搜索账号
  Future<void> _searchAccount(String keyword) async {
    if (keyword.isEmpty) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final resp = await api.searchAccount({"keyword": keyword});
      final List<dynamic> userList = resp['data'] ?? [];

      setState(() {
        _searchResults = userList
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } catch (e) {
      print('搜索失败: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('搜索失败，请重试')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasKeyword = _searchController.text.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F0F0),
        elevation: 0,
        title: CupertinoSearchTextField(
          controller: _searchController,
          placeholder: '搜索用户名、备注、地址',
          autofocus: true,
          style: const TextStyle(fontSize: 14),
          placeholderStyle: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF07C160))),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // 搜索结果区域
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : hasKeyword
                ? _searchResults.isEmpty
                      ? const Center(child: Text('未找到相关用户'))
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            final user = _searchResults[index];
                            return _buildUserItem(
                              avatarUrl:
                                  user['avatar_url'] ?? 'https://bbt-bucket-public.oss-cn-hongkong.aliyuncs.com/avatar_s/1.png',
                              name: user['username'] ?? user['name'] ?? '未知用户',
                              address: _formatAddress(user['wallet_address']),
                              userMap: user, // 传入完整数据，点击时使用
                            );
                          },
                        )
                : _buildDefaultContent(), // 无输入时显示默认推荐
          ),
        ],
      ),
    );
  }

  // 默认推荐内容（社交达人等）
  Widget _buildDefaultContent() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          '社交达人',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        _buildSocialCard(
          logo: 'De',
          title: 'DeSwap 空投小助手',
          subtitle: 'Easy, fast and save more',
          bgColor: Colors.green,
        ),
        const SizedBox(height: 12),
        _buildSocialCard(
          logo: Icons.volume_up,
          title: 'BlockBeats',
          subtitle: 'News from BlockBeats',
          bgColor: Colors.blue,
        ),
        const SizedBox(height: 30),
        const Text(
          '用户',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 12),
        // 这里可以放一些默认推荐用户
      ],
    );
  }

  Widget _buildSocialCard({
    required dynamic logo,
    required String title,
    required String subtitle,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: bgColor,
            child: logo is String
                ? Text(
                    logo,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  )
                : Icon(logo, color: Colors.white),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              shape: const StadiumBorder(),
            ),
            child: const Text('关注', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildUserItem({
    required String avatarUrl,
    required String name,
    required String address,
    required Map<String, dynamic> userMap,
  }) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UserInfo(
              userId: userMap['userId'] ?? 0,
              // 你可以根据需要传更多字段
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 46,
              height: 46,
              child: (avatarUrl as String?)?.isNotEmpty == true
                  ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.person,
                  size: 30,
                  color: Colors.orange,
                ),
              )
                  : const Icon(
                Icons.person,
                size: 30,
                color: Colors.orange,
              ),
            ),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Text(
            address,
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
          trailing: const Icon(
            Icons.arrow_forward_ios,
            size: 16,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  String _formatAddress(String? address) {
    if (address == null || address.length < 10) return '未知地址';
    return '${address.substring(0, 6)}...${address.substring(address.length - 4)}';
  }
}
