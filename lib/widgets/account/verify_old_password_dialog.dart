import 'package:education/core/global.dart';
import 'package:education/core/sqlite/wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 重置密码前验证当前密码，用于更新本地助记词
/// 返回验证通过的密码，失败返回 null
class VerifyOldPasswordDialog {
  static Future<String?> show(BuildContext context) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const _VerifyOldPasswordContent(),
    );
  }
}

class _VerifyOldPasswordContent extends StatefulWidget {
  const _VerifyOldPasswordContent();

  @override
  State<_VerifyOldPasswordContent> createState() => _VerifyOldPasswordContentState();
}

class _VerifyOldPasswordContentState extends State<_VerifyOldPasswordContent> {
  final TextEditingController _controller = TextEditingController();
  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final pwd = _controller.text.trim();
    if (pwd.isEmpty) {
      Fluttertoast.showToast(msg: '请输入当前密码');
      return;
    }
    if (pwd.length != 6) {
      Fluttertoast.showToast(msg: '请输入 6 位数字密码');
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = WalletRepository(Global.db);
      final rows = await repo.getAllWalletRows();
      if (rows.isEmpty) {
        // 无本地助记词，直接通过
        if (mounted) Navigator.pop(context, pwd);
        return;
      }
      final firstDid = rows.first['did_id'] as String;
      final mnemonic = await repo.exportMnemonic(firstDid, pwd);
      if (mnemonic != null && mnemonic.isNotEmpty) {
        // 返回实际用于解密的密码（可能是 plain_password），供 updateAllPasswords 使用
        final storedPwd = await repo.getStoredPasswordForDid(firstDid) ?? pwd;
        if (mounted) Navigator.pop(context, storedPwd);
      } else {
        Fluttertoast.showToast(msg: '密码错误');
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '验证失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('验证当前密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '请输入当前 6 位密码以更新本地助记词备份',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            obscureText: _obscure,
            keyboardType: TextInputType.number,
            maxLength: 6,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              hintText: '6 位数字密码',
              counterText: '',
              suffixIcon: IconButton(
                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _loading ? null : _verify,
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('确认'),
        ),
      ],
    );
  }
}
