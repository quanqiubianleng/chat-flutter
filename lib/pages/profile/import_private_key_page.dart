import 'package:education/config/app_config.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/wallet_repository.dart';
import 'package:education/pages/profile/qr_scan_page.dart';
import 'package:education/services/user_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

/// 导入私钥页：输入 EVM 链私钥、扫一扫、用户协议、导入按钮
class ImportPrivateKeyPage extends StatefulWidget {
  final String? initialPassword;
  final VoidCallback? onImportSuccess;

  const ImportPrivateKeyPage({
    super.key,
    this.initialPassword,
    this.onImportSuccess,
  });

  @override
  State<ImportPrivateKeyPage> createState() => _ImportPrivateKeyPageState();
}

class _ImportPrivateKeyPageState extends State<ImportPrivateKeyPage> {
  static const Color _green = Color(0xFF00D1A7);

  final TextEditingController _controller = TextEditingController();
  bool _hasAgreed = false;
  bool _loading = false;
  final UserApi _api = UserApi();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 规范化私钥输入：去掉所有空白（方便粘贴带换行/空格的字符串）
  static String _normalizePrivateKeyInput(String raw) {
    return raw.replaceAll(RegExp(r'\s+'), '').trim();
  }

  /// 校验 EVM 私钥：64 位十六进制，或 0x + 64 位（允许输入中含空格、换行）
  static bool _isValidEvmPrivateKey(String raw) {
    final s = _normalizePrivateKeyInput(raw);
    if (s.isEmpty) return false;
    String hex = s;
    if (hex.toLowerCase().startsWith('0x')) hex = hex.substring(2);
    if (hex.length != 64) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
  }

  Future<void> _openScan() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const QrScanPage()),
    );
    if (result != null && result.trim().isNotEmpty && mounted) {
      _controller.text = result.trim();
      setState(() {});
    }
  }

  Future<void> _openUrl(String url) async {
    if (url.isEmpty) {
      Fluttertoast.showToast(msg: '协议链接未配置');
      return;
    }
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      Fluttertoast.showToast(msg: '无法打开链接');
    }
  }

  Future<void> _doImport() async {
    final raw = _normalizePrivateKeyInput(_controller.text);
    if (!_isValidEvmPrivateKey(raw)) {
      Fluttertoast.showToast(msg: '请输入有效的 EVM 链私钥（64 位十六进制）');
      return;
    }
    if (!_hasAgreed) {
      Fluttertoast.showToast(msg: '请先阅读并同意用户协议');
      return;
    }

    final deviceNo = await UserCache.getDevice() ?? '';
    if (deviceNo.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('设备号未就绪，请先完成设置密码')),
        );
      }
      return;
    }

    final repo = WalletRepository(Global.db);
    String pwd = widget.initialPassword?.isNotEmpty == true ? widget.initialPassword! : '';
    if (pwd.isEmpty || pwd.length < 6) {
      pwd = await repo.getDevicePassword() ?? '';
    }
    if (pwd.length < 6) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先设置或输入 6 位密码')),
        );
      }
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await _api.importWalletByPrivateKey({
        'did_id': '',
        'password': pwd,
        'deviceNo': deviceNo,
        'private_key': raw,
      });

      final code = res['code'] as int? ?? 0;
      if (code != 200) {
        final msg = res['msg'] as String? ?? '导入失败';
        if (mounted) Fluttertoast.showToast(msg: msg);
        return;
      }

      final userId = (res['userId'] as num?)?.toInt() ?? 0;
      final didId = res['did_id']?.toString() ?? '';
      final walletAddress = res['wallet_address']?.toString() ?? '';

      await UserCache.saveToken(res['token']);
      await UserCache.saveUserId(userId);
      await UserCache.saveDid(didId);

      await repo.saveEncryptedPrivateKey(
        userId: userId,
        didId: didId,
        walletAddress: walletAddress,
        privateKey: raw,
        password: pwd,
        deviceNo: deviceNo,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onImportSuccess?.call();
      ws.switchAccount();
      Fluttertoast.showToast(msg: '已导入 ${res['username'] ?? "新账号"}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('导入失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          '导入私钥',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '输入私钥',
              style: TextStyle(
                fontSize: 14,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              constraints: const BoxConstraints(minHeight: 120, maxHeight: 200),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE8E8E8)),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomRight,
                children: [
                  Positioned.fill(
                    child: TextField(
                      controller: _controller,
                      minLines: 2,
                      maxLines: 6,
                      obscureText: false,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: '请输入EVM链私钥（64位十六进制，可带0x前缀）',
                        hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 15),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.fromLTRB(16, 20, 56, 20),
                        alignLabelWithHint: true,
                      ),
                      style: const TextStyle(fontSize: 15, fontFamily: 'monospace'),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  Positioned(
                    right: 12,
                    bottom: 12,
                    child: GestureDetector(
                      onTap: _openScan,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                        child: Icon(Icons.qr_code_scanner, color: Colors.grey.shade600, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () => setState(() => _hasAgreed = !_hasAgreed),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 20,
                    height: 20,
                    margin: const EdgeInsets.only(top: 2),
                    decoration: BoxDecoration(
                      color: _hasAgreed ? _green : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _hasAgreed ? _green : const Color(0xFFCCCCCC),
                        width: 2,
                      ),
                    ),
                    child: _hasAgreed
                        ? const Icon(Icons.check, color: Colors.white, size: 14)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF666666),
                        height: 1.4,
                      ),
                      children: [
                        const TextSpan(text: '我已仔细阅读并同意'),
                        TextSpan(
                          text: '《用户协议》',
                          style: const TextStyle(color: Colors.blue),
                          recognizer: TapGestureRecognizer()
                            ..onTap = () => _openUrl(AppConfig.agreeUrl),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: _controller,
              builder: (_, value, __) {
                final canSubmit = _isValidEvmPrivateKey(value.text) && _hasAgreed && !_loading;
                return SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: canSubmit ? _doImport : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      disabledBackgroundColor: const Color(0xFFE0F7F0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            '导入',
                            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                          ),
                  ),
                );
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }
}
