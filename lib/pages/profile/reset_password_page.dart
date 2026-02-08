import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/wallet_repository.dart';
import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 修改密码 / 重置 PIN 码页面
/// 进入前需验证当前密码（由调用方在点击「重置 PIN 码」时处理，未来可替换为人脸识别）
/// [oldPassword] 由验证通过后传入，用于更新本地助记词密码
class ResetPasswordPage extends StatefulWidget {
  final String? oldPassword;

  const ResetPasswordPage({super.key, this.oldPassword});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final TextEditingController _newController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final FocusNode _newFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();
  bool _loading = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _newController.dispose();
    _confirmController.dispose();
    _newFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPwd = _newController.text.trim();
    final confirmPwd = _confirmController.text.trim();

    if (newPwd.isEmpty) {
      Fluttertoast.showToast(msg: '请输入新密码');
      return;
    }
    if (newPwd.length != 6) {
      Fluttertoast.showToast(msg: '新密码为 6 位数字');
      return;
    }
    if (newPwd != confirmPwd) {
      Fluttertoast.showToast(msg: '两次输入的新密码不一致');
      return;
    }

    setState(() => _loading = true);
    try {
      final deviceNo = await UserCache.getDevice() ?? '';
      if (deviceNo.isEmpty) {
        Fluttertoast.showToast(msg: '设备号未获取，请重试');
        setState(() => _loading = false);
        return;
      }

      final api = UserApi();
      final resp = await api.resetPassword({
        'deviceNo': deviceNo,
        'password': newPwd,
      });

      final code = resp['code'];
      if (code != null && code != 200 && code != 0) {
        Fluttertoast.showToast(msg: resp['msg']?.toString() ?? '重置失败');
        setState(() => _loading = false);
        return;
      }

      // 若有传入旧密码，更新本地所有助记词密码
      final oldPwd = widget.oldPassword;
      if (oldPwd != null && oldPwd.length == 6) {
        final repo = WalletRepository(Global.db);
        final rows = await repo.getAllWalletRows();
        if (rows.isNotEmpty) {
          final ok = await repo.updateAllPasswords(oldPwd, newPwd);
          if (!ok) {
            Fluttertoast.showToast(msg: '更新本地备份失败');
            setState(() => _loading = false);
            return;
          }
        }
      }

      if (mounted) {
        Fluttertoast.showToast(msg: '密码已重置');
        Navigator.pop(context, true);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString().replaceFirst('ApiException: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// 6 个方框的 PIN 输入，与图片布局一致
  Widget _buildPinBoxInput({
    required String label,
    required TextEditingController controller,
    required FocusNode focusNode,
    required bool obscure,
    FocusNode? nextFocus,
    bool isLast = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF666666)),
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              // 6 个方框展示
              Row(
                children: List.generate(6, (i) {
                  final text = controller.text;
                  final hasDigit = i < text.length;
                  final char = hasDigit ? (obscure ? '•' : text[i]) : '';
                  return Expanded(
                    child: Container(
                      margin: EdgeInsets.only(right: i < 5 ? 8 : 0),
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(4),
                    ),
                      alignment: Alignment.center,
                      child: Text(
                        char,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.black87),
                      ),
                    ),
                  );
                }),
              ),
              // 透明 TextField 覆盖在上方接收输入
              Positioned.fill(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textInputAction: isLast ? TextInputAction.done : TextInputAction.next,
                  style: const TextStyle(color: Colors.transparent, fontSize: 1),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                  onChanged: (_) {
                    setState(() {});
                    if (controller.text.length == 6) {
                      if (isLast) {
                        _save();
                      } else if (nextFocus != null) {
                        FocusScope.of(context).requestFocus(nextFocus);
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
          '修改密码',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('保存', style: TextStyle(fontSize: 16, color: Color(0xFF00D1A7), fontWeight: FontWeight.w500)),
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              _buildPinBoxInput(
                label: '输入新密码',
                controller: _newController,
                focusNode: _newFocus,
                obscure: _obscureNew,
                nextFocus: _confirmFocus,
              ),
              _buildPinBoxInput(
                label: '请再次输入密码',
                controller: _confirmController,
                focusNode: _confirmFocus,
                obscure: _obscureConfirm,
                isLast: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
