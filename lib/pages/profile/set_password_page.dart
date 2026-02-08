// 未登录时创建/导入钱包前先设置密码页
import 'package:education/config/app_config.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/utils/device.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

/// 未登录时：创建钱包或导入前先进入此页设置 6 位密码，确认后返回 [password]。
/// 仅第一次未登录创建/导入时在此页内获取并缓存设备号。
enum SetPasswordMode { create, import }

class SetPasswordPage extends StatefulWidget {
  final SetPasswordMode mode;
  final VoidCallback? onImportSuccess;

  const SetPasswordPage({
    super.key,
    required this.mode,
    this.onImportSuccess,
  });

  @override
  State<SetPasswordPage> createState() => _SetPasswordPageState();
}

class _SetPasswordPageState extends State<SetPasswordPage> {
  final TextEditingController _pwdController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  final FocusNode _pwdFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();
  bool _agreed = false;

  @override
  void dispose() {
    _pwdController.dispose();
    _confirmController.dispose();
    _pwdFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  Future<void> _ensureDeviceAndReturnPassword(String password) async {
    // 只有第一次未登录创建/导入时在此获取并缓存设备号
    final cached = await UserCache.getDevice();
    if (cached == null || cached.isEmpty) {
      final deviceNo = await DeviceUtils.getDeviceId('ddd');
      await UserCache.saveDevice(deviceNo);
    }
    if (!mounted) return;
    Navigator.pop(context, password);
  }

  void _onConfirm() {
    final pwd = _pwdController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pwd.length != 6) {
      Fluttertoast.showToast(msg: '请设置 6 位数字密码');
      return;
    }
    if (confirm != pwd) {
      Fluttertoast.showToast(msg: '两次密码不一致');
      return;
    }
    if (!_agreed) {
      Fluttertoast.showToast(msg: '请先同意用户协议');
      return;
    }

    _ensureDeviceAndReturnPassword(pwd);
  }

  Future<void> _openUserAgreement() async {
    final url = AppConfig.agreeUrl;
    if (url.isEmpty) {
      Fluttertoast.showToast(msg: '协议链接未配置');
      return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Fluttertoast.showToast(msg: '无法打开链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create wallet',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'After setting a password, please keep it secure. If lost, reset it under Settings - Payment and Security',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),

              // Set Password
              Row(
                children: [
                  const Text(
                    'Set Password',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                  ),
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    icon: Icon(Icons.help_outline, size: 20, color: Colors.grey[600]),
                    onPressed: () {
                      Fluttertoast.showToast(msg: '请设置 6 位数字密码，用于保护钱包');
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _PinInput(
                controller: _pwdController,
                focusNode: _pwdFocus,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 24),

              // Enter the password again
              const Text(
                'Enter the password again',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              _PinInput(
                controller: _confirmController,
                focusNode: _confirmFocus,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 32),

              // User agreement
              Center(
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'Confirmation implies agreement to the '),
                      TextSpan(
                        text: '「User agreement」',
                        style: const TextStyle(
                          color: Color(0xFF00D1A7),
                          fontWeight: FontWeight.w500,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () {
                            _openUserAgreement();
                          },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: GestureDetector(
                  onTap: () => setState(() => _agreed = !_agreed),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: _agreed ? const Color(0xFF00D1A7) : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: _agreed ? const Color(0xFF00D1A7) : (Colors.grey[400]!),
                            width: 2,
                          ),
                        ),
                        child: _agreed ? const Icon(Icons.check, color: Colors.white, size: 14) : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'I agree to the User agreement',
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 40),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _onConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1A7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
            ],
          ),
        ),
      ),
    );
  }
}

/// 6 位数字密码输入，展示为 6 个方框，数字键盘。
class _PinInput extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  const _PinInput({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });

  static const _len = 6;

  @override
  Widget build(BuildContext context) {
    final totalWidth = MediaQuery.sizeOf(context).width - 48;
    final boxWidth = (totalWidth - (_len - 1) * 8) / _len;
    return GestureDetector(
      onTap: () => focusNode.requestFocus(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_len, (i) {
              final text = controller.text;
              final char = i < text.length ? '•' : '';
              return Container(
                width: boxWidth,
                height: 52,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                ),
                child: Text(
                  char,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              );
            }),
          ),
          SizedBox(
            width: totalWidth,
            height: 52,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              maxLength: _len,
              keyboardType: TextInputType.number,
              autofocus: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 1),
              cursorColor: Colors.transparent,
              decoration: const InputDecoration(
                border: InputBorder.none,
                counterText: '',
                contentPadding: EdgeInsets.zero,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (v) {
                onChanged(v);
                if (v.length == _len) {
                  FocusScope.of(context).nextFocus();
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
