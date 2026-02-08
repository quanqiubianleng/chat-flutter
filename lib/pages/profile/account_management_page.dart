import 'package:education/core/cache/user_cache.dart';
import 'package:education/services/user_service.dart';
import 'package:education/pages/profile/account_detail_page.dart';
import 'package:education/widgets/account/import_account_sheet.dart';
import 'package:flutter/material.dart';

/// 账号管理页：显示当前设备下的账号列表
class AccountManagementPage extends StatefulWidget {
  const AccountManagementPage({super.key});

  @override
  State<AccountManagementPage> createState() => _AccountManagementPageState();
}

class _AccountManagementPageState extends State<AccountManagementPage> {
  final UserApi _api = UserApi();
  List<Map<String, dynamic>> _accountList = [];
  String _currentWallet = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final userInfo = await _api.getUserInfo();
      final info = userInfo;
      final wallet = userInfo['wallet_address']?.toString() ?? '';
      final deviceNo = userInfo['deviceNo']?.toString() ?? await UserCache.getDevice() ?? '';

      final resp = await _api.getAccountDevice({'deviceNo': deviceNo});
      final List<dynamic> rawList = resp['data'] ?? [];

      final list = rawList.map<Map<String, dynamic>>((item) {
        final map = item as Map<String, dynamic>;
        final w = map['wallet_address']?.toString() ?? '';
        return {
          'username': map['username'] ?? '匿名用户',
          'wallet_address': w,
          'avatar_url': map['avatar_url'] ?? '',
          'did_id': map['did_id'] ?? '',
          'userId': map['userId'],
          'hasNotification': map['hasNotification'] == true,
          'isCurrent': w == wallet,
        };
      }).toList();

      if (list.isEmpty && wallet.isNotEmpty) {
        list.add({
          'username': userInfo['username'] ?? '匿名用户',
          'wallet_address': wallet,
          'avatar_url': userInfo['avatar_url'] ?? '',
          'did_id': userInfo['did_id'] ?? '',
          'userId': userInfo['userId'],
          'hasNotification': false,
          'isCurrent': true,
        });
      }

      if (mounted) {
        setState(() {
          _accountList = list;
          _currentWallet = wallet;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _shortName(String? name, String? wallet) {
    if (name != null && name.isNotEmpty && name != 'null') return name;
    if (wallet != null && wallet.length > 10) {
      return 'User#${wallet.substring(2, 8).toUpperCase()}';
    }
    return '匿名用户';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('账号管理', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _accountList.length,
              itemBuilder: (_, i) {
                final acc = _accountList[i];
                final isCurrent = acc['isCurrent'] == true;
                final hasNotification = acc['hasNotification'] == true;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => AccountDetailPage(
                              account: acc,
                              onRemoved: () => _loadAccounts(),
                            ),
                          ),
                        );
                        _loadAccounts();
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    width: 46,
                                    height: 46,
                                    color: Colors.grey[200],
                                    child: (acc['avatar_url'] as String?)?.isNotEmpty == true
                                        ? Image.network(
                                            acc['avatar_url'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 32, color: Colors.grey),
                                          )
                                        : const Icon(Icons.person, size: 32, color: Colors.grey),
                                  ),
                                ),
                                Positioned(
                                  right: -4,
                                  bottom: -4,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF00D1A7),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Icon(Icons.camera_alt, color: Colors.white, size: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _shortName(acc['username'], acc['wallet_address']),
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.black87),
                                      ),
                                      if (isCurrent) ...[
                                        const SizedBox(width: 6),
                                        Icon(Icons.check_circle, size: 16, color: Colors.green[600]),
                                      ],
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      Icon(Icons.grid_view_rounded, size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Icon(Icons.circle_outlined, size: 14, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Icon(Icons.view_agenda_outlined, size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Icon(Icons.diamond_outlined, size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Icon(Icons.all_inclusive, size: 16, color: Colors.grey[500]),
                                      const SizedBox(width: 4),
                                      Text('OP', style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.keyboard_arrow_right, size: 24, color: Colors.grey[600]),
                                  onPressed: () => _loadAccounts(),
                                ),
                                if (hasNotification)
                                  Positioned(
                                    top: 4,
                                    right: 4,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
      /*bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 52,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                ImportAccountSheet.show(context, onImportSuccess: () => _loadAccounts());
              },
              icon: const Icon(Icons.add, size: 22),
              label: const Text('添加账号', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D1A7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ),
      ),*/
    );
  }
}
