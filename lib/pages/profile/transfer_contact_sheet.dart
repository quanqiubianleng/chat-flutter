import 'package:flutter/material.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/common/empty_state_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// 单条联系人数据（与接口 getTransferContactList 返回一致）
class TransferContactItem {
  final int userId;
  final String username;
  final String? avatarUrl;
  final String? walletAddress;
  final String? remark;
  final String relation; // my_account, my_following, mutual_friend

  TransferContactItem({
    required this.userId,
    required this.username,
    this.avatarUrl,
    this.walletAddress,
    this.remark,
    required this.relation,
  });

  static TransferContactItem fromJson(Map<String, dynamic> json) {
    return TransferContactItem(
      userId: (json['userId'] as num?)?.toInt() ?? 0,
      username: (json['username'] as String?) ?? '',
      avatarUrl: json['avatar_url'] as String?,
      walletAddress: json['wallet_address'] as String?,
      remark: json['remark'] as String?,
      relation: (json['relation'] as String?) ?? 'my_following',
    );
  }

  String get displayName => (remark != null && remark!.isNotEmpty) ? remark! : username;
  String get relationLabel {
    switch (relation) {
      case 'my_account':
        return '我的账号';
      case 'mutual_friend':
        return '互关好友';
      case 'my_following':
      default:
        return '我的关注';
    }
  }
}

/// 选择好友转账弹窗：标题、搜索框、联系人列表（与图一一致）
class TransferContactSheet extends StatefulWidget {
  final void Function(String address, String? name) onSelect;

  const TransferContactSheet({super.key, required this.onSelect});

  @override
  State<TransferContactSheet> createState() => _TransferContactSheetState();
}

class _TransferContactSheetState extends State<TransferContactSheet> {
  final TextEditingController _searchController = TextEditingController();
  final UserApi _api = UserApi();
  List<TransferContactItem> _list = [];
  List<TransferContactItem> _filtered = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _load();
  }

  void _onSearchChanged() {
    setState(() => _filter());
  }

  void _filter() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      _filtered = List.from(_list);
      return;
    }
    _filtered = _list.where((e) {
      final name = e.displayName.toLowerCase();
      final addr = (e.walletAddress ?? '').toLowerCase();
      final remark = (e.remark ?? '').toLowerCase();
      return name.contains(q) || addr.contains(q) || remark.contains(q);
    }).toList();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final deviceNo = await UserCache.getDevice() ?? '';
      final resp = await _api.getTransferContactList({'deviceNo': deviceNo});
      final data = resp['data'] as List<dynamic>? ?? [];
      final list = data.map((e) => TransferContactItem.fromJson(e as Map<String, dynamic>)).toList();
      if (mounted) {
        setState(() {
          _list = list;
          _filtered = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
          _list = [];
          _filtered = [];
        });
      }
    }
  }

  String _shortAddress(String? addr) {
    if (addr == null || addr.length < 18) return addr ?? '';
    return '${addr.substring(0, 6)}...${addr.substring(addr.length - 6)}';
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏：选择好友转账 + 关闭 X
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '选择好友转账',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索用户备注、名称或地址',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 22),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  isDense: true,
                ),
              ),
            ),
            // 列表
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _error != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text('加载失败：$_error', style: TextStyle(color: Colors.grey[600])),
                          ),
                        )
                      : _filtered.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: EmptyStateView(),
                            )
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: _filtered.length,
                              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                              itemBuilder: (context, i) {
                                final item = _filtered[i];
                                return InkWell(
                                  onTap: () {
                                    final addr = item.walletAddress ?? '';
                                    if (addr.isNotEmpty) {
                                      widget.onSelect(addr, item.displayName);
                                      Navigator.pop(context);
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                                    child: Row(
                                      children: [
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: item.avatarUrl != null && item.avatarUrl!.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: item.avatarUrl!,
                                                  width: 48,
                                                  height: 48,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, __) => _avatarPlaceholder(),
                                                  errorWidget: (_, __, ___) => _avatarPlaceholder(),
                                                )
                                              : _avatarPlaceholder(),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.displayName,
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w500,
                                                  color: Colors.black87,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                _shortAddress(item.walletAddress),
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  color: Colors.grey[600],
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ),
                                        ),
                                        Text(
                                          item.relationLabel,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatarPlaceholder() {
    return Container(
      width: 48,
      height: 48,
      color: Colors.grey.shade200,
      child: const Icon(Icons.person, color: Colors.grey, size: 28),
    );
  }
}
