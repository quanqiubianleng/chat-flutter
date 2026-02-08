import 'package:education/core/global.dart';
import 'package:education/core/sqlite/wallet_repository.dart';
import 'package:education/pages/profile/reset_password_page.dart';
import 'package:education/widgets/account/verify_old_password_dialog.dart';
import 'package:flutter/material.dart';

/// 支付与安全页面
class PaymentSecurityPage extends StatefulWidget {
  const PaymentSecurityPage({super.key});

  @override
  State<PaymentSecurityPage> createState() => _PaymentSecurityPageState();
}

class _PaymentSecurityPageState extends State<PaymentSecurityPage> {
  bool _requireUnlock = false;
  bool _biometricPay = true;
  bool _passwordFreePay = false;

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
          '支付与安全',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 24),
          _SettingsItem(
            icon: Icons.lock_reset_rounded,
            title: '重置 PIN 码',
            trailing: const Icon(Icons.chevron_right_rounded, color: Colors.grey, size: 24),
            onTap: () async {
              // 若有本地助记词，先验证当前密码以更新本地备份（未来可替换为人脸识别）
              String? oldPassword;
              final repo = WalletRepository(Global.db);
              final rows = await repo.getAllWalletRows();
              if (rows.isNotEmpty) {
                oldPassword = await VerifyOldPasswordDialog.show(context);
                if (oldPassword == null || !context.mounted) return;
              }
              final ok = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => ResetPasswordPage(oldPassword: oldPassword),
                ),
              );
              if (ok == true && context.mounted) {
                // 可选：显示成功提示
              }
            },
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          _SettingsItem(
            icon: Icons.screen_lock_portrait_rounded,
            title: '需解锁打开 App',
            trailing: Switch(
              value: _requireUnlock,
              onChanged: (v) => setState(() => _requireUnlock = v),
              activeColor: const Color(0xFF00D1A7),
            ),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          _SettingsItem(
            icon: Icons.fingerprint_rounded,
            title: '面容/指纹支付',
            trailing: Switch(
              value: _biometricPay,
              onChanged: (v) => setState(() => _biometricPay = v),
              activeColor: const Color(0xFF00D1A7),
            ),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          _SettingsItem(
            icon: Icons.payment_rounded,
            title: '免密支付',
            subtitle: '小于 100 BBT 无需密码',
            trailing: Switch(
              value: _passwordFreePay,
              onChanged: (v) => setState(() => _passwordFreePay = v),
              activeColor: const Color(0xFF00D1A7),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    this.subtitle,
    required this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: const Color.fromARGB(179, 29, 28, 28), size: 26),
        title: Text(
          title,
          style: const TextStyle(color: Color(0xFF252525), fontSize: 16),
        ),
        subtitle: subtitle != null
            ? Text(
                subtitle!,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              )
            : null,
        trailing: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
      ),
    );
  }
}
