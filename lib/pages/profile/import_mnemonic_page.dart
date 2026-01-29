// 文件：lib/pages/import_mnemonic_page.dart
import 'package:education/core/cache/user_cache.dart';
import 'package:education/services/user_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart'; // 新增：打开网页
import 'package:education/config/app_config.dart';

import '../../core/global.dart';

class ImportMnemonicPage extends StatefulWidget {
  final String? initialMnemonic;
  final VoidCallback? onImportSuccess; // 新增回调

  const ImportMnemonicPage({
    super.key,
    this.initialMnemonic,
    this.onImportSuccess, // 必须加！
  });

  @override
  State<ImportMnemonicPage> createState() => _ImportMnemonicPageState();
}

class _ImportMnemonicPageState extends State<ImportMnemonicPage> {
  late TextEditingController _controller;
  bool _isButtonEnabled = false;
  bool _hasAgreed = false; // 新增：是否勾选协议

  // API
  final api = UserApi();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialMnemonic ?? '');
    _controller.addListener(_checkInput);
    // 确保初始状态正确
    _hasAgreed = false;
  }

  void _checkInput() {
    final text = _controller.text.trim();
    final words = text
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    setState(() {
      _isButtonEnabled = words.length >= 12 && _hasAgreed;
    });
  }

  void _toggleAgreement(bool? value) {
    setState(() {
      _hasAgreed = value ?? false;
      _isButtonEnabled =
          _controller.text
                  .trim()
                  .split(RegExp(r'\s+'))
                  .where((e) => e.isNotEmpty)
                  .length >=
              12 &&
          _hasAgreed;
    });
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isNotEmpty) {
      _controller.text = text;
      _controller.selection = TextSelection.fromPosition(
        TextPosition(offset: _controller.text.length),
      );
      Fluttertoast.showToast(msg: "已粘贴");
      _checkInput();
    }
  }

  // 打开协议（复用 AppConfig）
  Future<void> _openUrl(String url) async {
    if (url == null || url.isEmpty) {
      Fluttertoast.showToast(msg: "协议链接未配置1");
      return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Fluttertoast.showToast(msg: "无法打开链接");
    }
  }

  /// 导入助记词
  Future<void> _importAccount() async {
    try {
      final mnemonic = _controller.text.trim();
      final deviceNo = await UserCache.getDevice() ?? "gfdgfdhgfdh";

      final importUser = await api.importWallet({"did_id": "222", "mnemonic": mnemonic, "deviceNo": deviceNo, "password": "..."});
      print(importUser);
      await UserCache.saveToken(importUser['token']);
      await UserCache.saveUserId(importUser['userId']);
      await UserCache.saveDid(importUser['did_id']);

      

      Navigator.pop(context);
      widget.onImportSuccess?.call(); // 触发刷新
      // 3. WebSocket 切换账号
      ws.switchAccount();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已导入 ${importUser["username"] ?? "新账号"}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('导入失败')));
    }
  }

  void _onConfirm() async {
    if (!_hasAgreed) {
      Fluttertoast.showToast(msg: "请先阅读并同意用户协议");
      return;
    }

    // 额外安全校验（防止按钮状态没来得及更新）
    final words = _controller.text.trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
        

    if (words.length < 12) {
      Fluttertoast.showToast(msg: "助记词至少需要12个单词");
      return;
    }

    // 加个 loading 状态（防止重复点击）
    if (!mounted) return;
    setState(() {
      _isButtonEnabled = false; // 禁用按钮，防止重复点
    });

    // 真正执行导入
    await _importAccount();

    // 导入结束后恢复按钮（如果还在当前页面）
    if (mounted) {
      setState(() {
        _isButtonEnabled = true;
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_checkInput);
    _controller.dispose();
    super.dispose();
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
        title: const Text(
          "导入助记词",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "通过12或24个的秘密助记词创建",
              style: TextStyle(fontSize: 15, color: Color(0xFF888888)),
            ),
            const SizedBox(height: 24),

            // 输入框
            Container(
              constraints: const BoxConstraints(minHeight: 140),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF9F9F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: TextField(
                controller: _controller,
                maxLines: null,
                textInputAction: TextInputAction.newline,
                decoration: const InputDecoration(
                  hintText: "请在单词之间使用空格",
                  hintStyle: TextStyle(color: Color(0xFFCCCCCC), fontSize: 15),
                  border: InputBorder.none,
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 16, height: 1.8),
              ),
            ),

            const SizedBox(height: 16),

            // 粘贴按钮
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _pasteFromClipboard,
                icon: const Icon(
                  Icons.paste,
                  size: 18,
                  color: Color(0xFF00D1A7),
                ),
                label: const Text(
                  "粘贴",
                  style: TextStyle(color: Color(0xFF00D1A7)),
                ),
              ),
            ),

            const SizedBox(height: 80),

            // 替换原来的 Row + Checkbox + Text.rich
            Row(
              children: [
                GestureDetector(
                  onTap: () => _toggleAgreement(!_hasAgreed),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _hasAgreed
                          ? const Color(0xFF00D1A7)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: _hasAgreed
                            ? const Color(0xFF00D1A7)
                            : const Color(0xFFCCCCCC),
                        width: 2,
                      ),
                    ),
                    child: _hasAgreed
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: "我已阅读并同意"),
                        TextSpan(
                          text: "《用户协议》",
                          style: const TextStyle(color: Color(0xFF00D1A7)),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _openUrl(AppConfig.agreeUrl),
                        ),
                        const TextSpan(text: "和"),
                        TextSpan(
                          text: "《隐私政策》",
                          style: const TextStyle(color: Color(0xFF00D1A7)),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _openUrl(AppConfig.privacyUrl),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 关键：协议行下面留 24px 间距
            const SizedBox(height: 15),

            // 导入大按钮
            SizedBox(
              width: double.infinity,
              height: 45,
              child: ElevatedButton(
                onPressed: _isButtonEnabled ? _onConfirm : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D1A7),
                  disabledBackgroundColor: const Color(0xFFE0F7F0),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  "导入",
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
            ),

            const SizedBox(height: 20 + 34), // 预留底部安全区
          ],
        ),
      ),
    );
  }
}
