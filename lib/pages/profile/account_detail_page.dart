import 'package:education/core/global.dart';
import 'package:education/core/sqlite/wallet_repository.dart';
import 'package:education/pages/profile/export_mnemonic_warning_page.dart';
import 'package:education/pages/profile/remove_account_page.dart';
import 'package:education/widgets/account/backup_mnemonic_sheet.dart';
import 'package:education/widgets/account/verify_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 账号详情页：头像、账号名称、地址、导出助记词、导出私钥、移除账号
class AccountDetailPage extends StatelessWidget {
  final Map<String, dynamic> account;
  final VoidCallback? onRemoved;

  const AccountDetailPage({
    super.key,
    required this.account,
    this.onRemoved,
  });

  String _shortName(String? name, String? wallet) {
    if (name != null && name.isNotEmpty && name != 'null') return name;
    if (wallet != null && wallet.length > 10) {
      return 'User#${wallet.substring(2, 8).toUpperCase()}';
    }
    return '匿名用户';
  }

  String _shortAddress(String? w) {
    if (w == null || w.length <= 14) return w ?? '';
    return '${w.substring(0, 6)}...${w.substring(w.length - 6)}';
  }

  @override
  Widget build(BuildContext context) {
    final username = _shortName(account['username'], account['wallet_address']);
    final address = account['wallet_address']?.toString() ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('账号详情', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // 头像（绿色圆形背景）
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFF00D1A7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00D1A7).withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: ClipOval(
                child: (account['avatar_url'] as String?)?.isNotEmpty == true
                    ? Image.network(
                        account['avatar_url'],
                        fit: BoxFit.cover,
                        width: 100,
                        height: 100,
                        errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: Colors.white70),
                      )
                    : const Icon(Icons.person, size: 50, color: Colors.white70),
              ),
            ),
            const SizedBox(height: 32),
            // 账号名称
            _DetailRow(
              label: '账号名称',
              value: username,
            ),
            _DetailRow(
              label: '账号地址',
              value: _shortAddress(address),
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
              onTap: () {
                if (address.isNotEmpty) {
                  Clipboard.setData(ClipboardData(text: address));
                  Fluttertoast.showToast(msg: '已复制地址');
                }
              },
            ),
            const SizedBox(height: 24),
            // 导出助记词
            _DetailRow(
              label: '导出助记词',
              value: '去备份',
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
              onTap: () async {
                final confirmed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ExportMnemonicWarningPage(),
                  ),
                );
                if (confirmed == true && context.mounted) {
                  _onExportMnemonic(context);
                }
              },
            ),
            _DetailRow(
              label: '导出私钥',
              value: '去备份',
              trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 22),
              onTap: () async {
                final didId = account['did_id']?.toString() ?? '';
                if (didId.isEmpty) {
                  Fluttertoast.showToast(msg: '账号信息不完整');
                  return;
                }
                final pk = await VerifyPasswordDialog.showForPrivateKey(context, didId: didId);
                if (pk != null && context.mounted) {
                  Clipboard.setData(ClipboardData(text: pk));
                  Fluttertoast.showToast(msg: '私钥已复制到剪贴板，请妥善保管');
                }
              },
            ),
            const SizedBox(height: 48),
            // 移除账号
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () => _goToRemoveAccount(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE57373),
                    side: const BorderSide(color: Color(0xFFE57373)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('移除账号', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }

  Future<void> _onExportMnemonic(BuildContext context) async {
    final didId = account['did_id']?.toString() ?? '';
    if (didId.isEmpty) {
      Fluttertoast.showToast(msg: '账号信息不完整');
      return;
    }
    final repo = WalletRepository(Global.db);
    final hasMnemonic = await repo.hasMnemonicForDid(didId);
    if (!hasMnemonic) {
      Fluttertoast.showToast(msg: '该账号未备份助记词');
      return;
    }
    final mnemonic = await VerifyPasswordDialog.showForMnemonic(context, didId: didId);
    if (mnemonic != null && context.mounted) {
      BackupMnemonicSheet.show(
        context,
        mnemonic: mnemonic,
        address: account['wallet_address']?.toString() ?? '',
        didId: didId,
        onFinalSuccess: () {},
      );
    }
  }

  Future<void> _goToRemoveAccount(BuildContext context) async {
    final removed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => RemoveAccountPage(
          account: account,
          onRemoved: onRemoved,
        ),
      ),
    );
    if (removed == true && context.mounted) {
      Navigator.pop(context);
    }
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Text(label, style: const TextStyle(fontSize: 15, color: Color(0xFF666666))),
            const Spacer(),
            if (value == '去备份')
              Text(value, style: const TextStyle(fontSize: 15, color: Color(0xFF00D1A7)))
            else
              Text(value, style: const TextStyle(fontSize: 15, color: Colors.black87)),
            if (trailing != null) ...[
              const SizedBox(width: 4),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}
