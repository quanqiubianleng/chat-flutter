import 'package:education/core/sqlite/wallet_repository.dart';
import 'package:education/core/global.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 导出助记词/私钥时验证密码的对话框
class VerifyPasswordDialog {
  /// 验证密码并导出助记词，成功返回 mnemonic，失败返回 null
  static Future<String?> showForMnemonic(
    BuildContext context, {
    required String didId,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VerifyPasswordContent(
        didId: didId,
        mode: _VerifyMode.mnemonic,
      ),
    );
  }

  /// 验证密码并导出私钥，成功返回 privateKey，失败返回 null
  static Future<String?> showForPrivateKey(
    BuildContext context, {
    required String didId,
  }) async {
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _VerifyPasswordContent(
        didId: didId,
        mode: _VerifyMode.privateKey,
      ),
    );
  }
}

enum _VerifyMode { mnemonic, privateKey }

class _VerifyPasswordContent extends StatefulWidget {
  final String didId;
  final _VerifyMode mode;

  const _VerifyPasswordContent({
    required this.didId,
    required this.mode,
  });

  @override
  State<_VerifyPasswordContent> createState() => _VerifyPasswordContentState();
}

class _VerifyPasswordContentState extends State<_VerifyPasswordContent> {
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
      Fluttertoast.showToast(msg: '请输入密码');
      return;
    }
    if (pwd.length != 6) {
      Fluttertoast.showToast(msg: '请输入 6 位数字密码');
      return;
    }

    setState(() => _loading = true);
    try {
      final repo = WalletRepository(Global.db);
      String? result;
      if (widget.mode == _VerifyMode.mnemonic) {
        result = await repo.exportMnemonic(widget.didId, pwd);
      } else {
        result = await repo.exportPrivateKey(widget.didId, pwd);
      }
      if (!mounted) return;
      if (result != null && result.isNotEmpty) {
        Navigator.pop(context, result);
      } else {
        final msg = widget.mode == _VerifyMode.mnemonic
            ? '密码错误或该账号未备份助记词'
            : '密码错误或该账号未备份助记词（私钥由助记词派生）';
        Fluttertoast.showToast(msg: msg);
      }
    } catch (e) {
      if (mounted) Fluttertoast.showToast(msg: '验证失败');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMnemonic = widget.mode == _VerifyMode.mnemonic;
    return AlertDialog(
      title: Text(isMnemonic ? '验证密码' : '验证密码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isMnemonic
                ? '请输入创建/导入时的 6 位密码以导出助记词'
                : '请输入创建/导入时的 6 位密码以导出私钥',
            style: const TextStyle(fontSize: 14, color: Colors.grey),
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
