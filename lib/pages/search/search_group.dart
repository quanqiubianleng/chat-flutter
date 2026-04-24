import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:education/core/utils/conversation.dart';
import 'package:education/pages/chat/group/group_chat.dart';
import 'package:education/pages/chat/group/group_profile_page.dart';
import 'package:education/services/api_service.dart';
import 'package:education/services/group_service.dart';
import 'package:education/services/user_service.dart';

class SearchGroupPage extends StatefulWidget {
  const SearchGroupPage({super.key});

  @override
  State<SearchGroupPage> createState() => _SearchGroupPageState();
}

class _SearchGroupPageState extends State<SearchGroupPage> {
  final GroupApi _api = GroupApi();
  final UserApi _userApi = UserApi();
  final TextEditingController _searchController = TextEditingController();

  List<Map<String, dynamic>> _results = [];
  bool _isLoading = false;
  String _currentKeyword = '';

  @override
  void initState() {
    super.initState();
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
        _results = [];
        _currentKeyword = '';
      });
      return;
    }
    if (keyword == _currentKeyword) return;
    _currentKeyword = keyword;
    _searchGroup(keyword);
  }

  Future<void> _searchGroup(String keyword) async {
    if (keyword.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final resp = await _api.searchGroup({'keyword': keyword, 'page': 1, 'page_size': 30});
      final List<dynamic> list = resp['data'] ?? <dynamic>[];
      setState(() {
        _results = list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('搜索群组失败，请稍后重试')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  int _asInt(dynamic v, [int d = 0]) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? d;
  }

  String _asString(dynamic v, [String d = '']) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? d : s;
  }

  Future<String?> _loadWalletAddress() async {
    try {
      final data = await _userApi.getUserInfo();
      final w = (data['wallet_address'] ?? data['walletAddress'] ?? '').toString().trim();
      if (w.startsWith('0x') && w.length == 42) return w;
    } catch (_) {}
    return null;
  }

  String _joinModeText(int mode) {
    switch (mode) {
      case 0:
        return '可直接加入';
      case 1:
        return '需管理员审核';
      case 2:
        return '持仓门控';
      case 3:
        return '仅邀请';
      default:
        return '未知模式';
    }
  }

  Future<void> _handleJoin(Map<String, dynamic> item) async {
    final int groupId = _asInt(item['group_id']);
    final int joinMode = _asInt(item['join_mode']);
    if (groupId <= 0) return;

    try {
      if (joinMode == 1) {
        final controller = TextEditingController();
        final reason = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('申请加入群组'),
            content: TextField(
              controller: controller,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: '请输入申请理由（可选）',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                child: const Text('提交申请'),
              ),
            ],
          ),
        );
        if (reason == null) return;
        final resp = await _api.applyJoinGroup({
          'group_id': groupId,
          'reason': reason,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_asString(resp['msg'], '申请已提交'))),
        );
        setState(() {
          item['pending_apply'] = 1;
        });
        return;
      }

      if (joinMode == 2) {
        final wallet = await _loadWalletAddress();
        if (wallet == null) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('持仓校验需要钱包地址，请先在个人资料绑定钱包')),
          );
          return;
        }
        final resp = await _api.joinGroup({
          'group_id': groupId,
          'wallet_address': wallet,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_asString(resp['msg'], '已加入群组'))),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupChatPage(
              chatId: generateTempConversationId(userIdA: 0, userIdB: groupId, isGroup: true),
            ),
          ),
        );
        return;
      }

      if (joinMode == 3) {
        final codeCtrl = TextEditingController();
        final code = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('邀请制入群'),
            content: TextField(
              controller: codeCtrl,
              decoration: const InputDecoration(
                hintText: '请输入邀请码',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
                child: const Text('加入'),
              ),
            ],
          ),
        );
        if (code == null || code.isEmpty) return;
        final wallet = await _loadWalletAddress();
        final resp = await _api.joinGroup({
          'group_id': groupId,
          'invite_code': code,
          if (wallet != null) 'wallet_address': wallet,
        });
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_asString(resp['msg'], '已加入群组'))),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => GroupChatPage(
              chatId: generateTempConversationId(userIdA: 0, userIdB: groupId, isGroup: true),
            ),
          ),
        );
        return;
      }

      final resp = await _api.joinGroup({'group_id': groupId});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_asString(resp['msg'], '已加入群组'))),
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatPage(
            chatId: generateTempConversationId(userIdA: 0, userIdB: groupId, isGroup: true),
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool hasKeyword = _searchController.text.trim().isNotEmpty;
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF2F3F5),
        elevation: 0,
        title: CupertinoSearchTextField(
          controller: _searchController,
          placeholder: '搜索群组名称、简介、群ID',
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Color(0xFF07C160))),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : !hasKeyword
              ? const Center(
                  child: Text(
                    '输入关键词搜索群组',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              : _results.isEmpty
                  ? const Center(child: Text('未找到相关群组'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: _results.length,
                      itemBuilder: (_, index) {
                        final item = _results[index];
                        final groupId = _asInt(item['group_id']);
                        final avatar = _asString(item['avatar']);
                        final name = _asString(item['name'], '未命名群组');
                        final desc = _asString(item['description'], '群主很懒，还没有简介');
                        final memberCount = _asInt(item['member_count']);
                        final joinMode = _asInt(item['join_mode']);
                        final joined = _asInt(item['is_joined']) == 1;
                        final pending = _asInt(item['pending_apply']) == 1;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => GroupProfilePage(
                                          groupId: groupId,
                                          preview: Map<String, dynamic>.from(item),
                                        ),
                                      ),
                                    );
                                  },
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: avatar.isNotEmpty
                                            ? Image.network(
                                                avatar,
                                                width: 52,
                                                height: 52,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => _avatarFallback(),
                                              )
                                            : _avatarFallback(),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              desc,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              '$memberCount 人 · ${_joinModeText(joinMode)}',
                                              style: const TextStyle(color: Colors.black45, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildActionButton(
                                joined: joined,
                                pending: pending,
                                joinMode: joinMode,
                                onTap: () => _handleJoin(item),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _avatarFallback() {
    return Container(
      width: 52,
      height: 52,
      color: const Color(0xFFEBEEF2),
      child: const Icon(Icons.groups_rounded, color: Colors.black38),
    );
  }

  Widget _buildActionButton({
    required bool joined,
    required bool pending,
    required int joinMode,
    required VoidCallback onTap,
  }) {
    if (joined) {
      return _tagButton('已加入', const Color(0xFFE7F6EC), const Color(0xFF1B9A4B));
    }
    if (pending) {
      return _tagButton('待审核', const Color(0xFFFFF6E5), const Color(0xFFB97A0D));
    }
    final String text;
    if (joinMode == 1) {
      text = '申请加入';
    } else if (joinMode == 3) {
      text = '邀请加入';
    } else {
      text = '加入';
    }
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF07C160),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _tagButton(String text, Color bg, Color fg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
