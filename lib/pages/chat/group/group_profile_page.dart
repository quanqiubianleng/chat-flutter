import 'package:education/core/utils/conversation.dart';
import 'package:education/modules/chat/models/group.dart';
import 'package:education/pages/chat/group/group_chat.dart';
import 'package:education/pages/chat/group/group_join_helper.dart';
import 'package:education/pages/chat/group/group_setting.dart';
import 'package:education/services/api_service.dart';
import 'package:education/services/group_service.dart';
import 'package:flutter/material.dart';

/// 群组资料：基本信息 + 入群方式 + 持仓门控摘要（数据来自 [GroupApi.getGroupInfo]）
class GroupProfilePage extends StatefulWidget {
  final int groupId;
  /// 搜索等入口可先展示列表快照，再异步拉全量
  final Map<String, dynamic>? preview;

  const GroupProfilePage({
    super.key,
    required this.groupId,
    this.preview,
  });

  @override
  State<GroupProfilePage> createState() => _GroupProfilePageState();
}

class _GroupProfilePageState extends State<GroupProfilePage> {
  final GroupApi _api = GroupApi();
  bool _loading = true;
  String? _error;
  GroupInfo? _info;

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _n(dynamic v, [int d = 0]) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v?.toString() ?? '') ?? d;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final raw = await _api.getGroupInfo({'group_id': widget.groupId});
      if (!mounted) return;
      setState(() {
        _info = GroupInfo.fromJson(raw);
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$e';
      });
    }
  }

  String _joinModeLabel(int m) {
    switch (m) {
      case 0:
        return '公开：任何人可直接加入';
      case 1:
        return '需管理员审核后加入';
      case 2:
        return '持仓门控：需满足链上资产条件（见下方）';
      case 3:
        return '邀请制：需要有效邀请码';
      default:
        return '未知入群方式';
    }
  }

  String _groupTypeLabel(int t) => t == 1 ? 'Club 大群' : '普通群';

  String _ruleLine(Map<String, dynamic> r) {
    final chain = (r['chain'] ?? '').toString();
    final contract = (r['contract_address'] ?? r['contractAddress'] ?? '').toString();
    final tt = _n(r['token_type'] ?? r['tokenType']);
    final minAmt = (r['min_amount'] ?? r['minAmount'] ?? '').toString();
    final tid = _n(r['token_id'] ?? r['tokenId']);
    final dec = _n(r['decimals']);
    switch (tt) {
      case 3:
        return '链 $chain：需持有主链币 ≥ $minAmt（decimals=$dec）';
      case 1:
        return '链 $chain：ERC721 合约 $contract${tid > 0 ? '，TokenId=$tid' : '，任意一枚'}';
      case 2:
        return '链 $chain：ERC1155 合约 $contract，TokenId=$tid';
      default:
        return '链 $chain：ERC20 合约 $contract，最低持仓 ≥ $minAmt（decimals=$dec）';
    }
  }

  @override
  Widget build(BuildContext context) {
    final pv = widget.preview;
    final namePv = (pv?['name'] ?? '').toString();
    final avatarPv = (pv?['avatar'] ?? '').toString();

    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      body: _loading && _info == null
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 168,
                  backgroundColor: const Color(0xFF07C160),
                  foregroundColor: Colors.white,
                  flexibleSpace: FlexibleSpaceBar(
                    title: Text(
                      _info?.Name ?? (namePv.isNotEmpty ? namePv : '群组资料'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(color: const Color(0xFF06AD56)),
                        Center(
                          child: Hero(
                            tag: 'group_avatar_${widget.groupId}',
                            child: _buildAvatar(
                              (_info?.Avatar ?? avatarPv).isNotEmpty ? (_info?.Avatar ?? avatarPv) : avatarPv,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_error != null && _info == null)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _load, child: const Text('重试')),
                        ],
                      ),
                    ),
                  )
                else ...[
                  SliverToBoxAdapter(child: _sectionTitle('基本信息')),
                  SliverToBoxAdapter(
                    child: _card(
                      children: [
                        _kv('群ID', '${widget.groupId}'),
                        if (_info != null) ...[
                          _kv('简介', _info!.description.isEmpty ? '暂无' : _info!.description),
                          _kv('群类型', _groupTypeLabel(_info!.type)),
                          _kv('成员', '${_info!.memberCount} / ${_info!.maxMembers}'),
                          _kv('创建时间', _info!.createdAt),
                        ],
                      ],
                    ),
                  ),
                  SliverToBoxAdapter(child: _sectionTitle('入群方式')),
                  SliverToBoxAdapter(
                    child: _card(
                      children: [
                        Text(
                          _info != null ? _joinModeLabel(_info!.joinMode) : '加载中…',
                          style: const TextStyle(fontSize: 14, height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  if (_info!.gateRules.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _sectionTitle('持仓 / 资产条件（需同时满足）')),
                    SliverToBoxAdapter(
                      child: _card(
                        children: [
                          for (var i = 0; i < _info!.gateRules.length; i++) ...[
                            if (i > 0) const Divider(height: 20),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${i + 1}. ', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Expanded(
                                  child: Text(
                                    _ruleLine(_info!.gateRules[i]),
                                    style: const TextStyle(fontSize: 13, height: 1.4),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else if (_info!.joinMode == 2)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '本群为持仓门控，但暂未配置具体规则，请联系群主。',
                          style: TextStyle(color: Colors.black54, fontSize: 13),
                        ),
                      ),
                    ),
                  if (_info != null && _info!.notice.isNotEmpty) ...[
                    SliverToBoxAdapter(child: _sectionTitle('群公告')),
                    SliverToBoxAdapter(
                      child: _card(
                        children: [
                          Text(_info!.notice, style: const TextStyle(fontSize: 13, height: 1.45)),
                        ],
                      ),
                    ),
                  ],
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ],
            ),
      bottomNavigationBar: _info == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    if (_info!.role > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupSettingsPage(groupId: widget.groupId),
                              ),
                            ).then((_) => _load());
                          },
                          child: const Text('群管理'),
                        ),
                      ),
                    if (_info!.role > 0) const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: () async {
                          if (_info!.role > 0) {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => GroupChatPage(
                                  chatId: generateTempConversationId(
                                    userIdA: 0,
                                    userIdB: widget.groupId,
                                    isGroup: true,
                                  ),
                                ),
                              ),
                            );
                          } else {
                            await runGroupJoinFlow(
                              context,
                              groupId: widget.groupId,
                              joinMode: _info!.joinMode,
                            );
                            if (mounted) await _load();
                          }
                        },
                        child: Text(_info!.role > 0 ? '进入群聊' : '加入群组'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildAvatar(String url) {
    if (url.isEmpty) {
      return const CircleAvatar(radius: 40, child: Icon(Icons.groups_rounded, size: 40));
    }
    return CircleAvatar(
      radius: 40,
      backgroundImage: NetworkImage(url),
    );
  }

  Widget _sectionTitle(String t) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        t,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black54),
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(k, style: const TextStyle(color: Colors.black45, fontSize: 13)),
          ),
          Expanded(child: Text(v, style: const TextStyle(fontSize: 13, height: 1.35))),
        ],
      ),
    );
  }
}
