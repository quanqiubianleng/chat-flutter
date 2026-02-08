import 'package:education/core/global.dart';
import 'package:education/core/sqlite/wallet_repository.dart';
import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 删除账号确认页：需勾选三项安全提示后才能删除
class RemoveAccountPage extends StatefulWidget {
  final Map<String, dynamic> account;
  final VoidCallback? onRemoved;

  const RemoveAccountPage({
    super.key,
    required this.account,
    this.onRemoved,
  });

  @override
  State<RemoveAccountPage> createState() => _RemoveAccountPageState();
}

class _RemoveAccountPageState extends State<RemoveAccountPage> {
  bool _check1 = false;
  bool _check2 = false;
  bool _check3 = false;
  bool _loading = false;

  bool get _canDelete => _check1 && _check2 && _check3;

  Future<void> _doRemove() async {
    if (!_canDelete || _loading) return;

    setState(() => _loading = true);
    try {
      final didId = widget.account['did_id']?.toString() ?? '';
      if (didId.isEmpty) {
        Fluttertoast.showToast(msg: '账号信息不完整');
        setState(() => _loading = false);
        return;
      }

      // 1. 调用后端移除账号接口
      final api = UserApi();
      final resp = await api.removeAccount({'did': didId});

      final code = resp['code'];
      if (code != null && code != 200 && code != 0) {
        Fluttertoast.showToast(msg: resp['msg']?.toString() ?? '移除失败');
        setState(() => _loading = false);
        return;
      }

      // 2. 移除本地助记词数据
      final repo = WalletRepository(Global.db);
      await repo.removeByDid(didId);

      if (mounted) {
        widget.onRemoved?.call();
        Fluttertoast.showToast(msg: '已移除账号');
        Navigator.pop(context, true);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: e.toString().replaceFirst('ApiException: ', ''));
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '删除',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 32),
            // 警告图标
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEBEE),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, size: 44, color: Color(0xFFE57373)),
            ),
            const SizedBox(height: 24),
            const Text(
              '您即将从当前手机上删除钱包,请谨记以下安全点!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Color(0xFF333333), height: 1.5),
            ),
            const SizedBox(height: 32),
            _CheckItem(
              text: '我已经将私钥或者助记词备份!',
              value: _check1,
              onChanged: (v) => setState(() => _check1 = v),
            ),
            const SizedBox(height: 12),
            _CheckItem(
              text: '我丢弃了私钥,我的资产将永远消失!',
              value: _check2,
              onChanged: (v) => setState(() => _check2 = v),
            ),
            const SizedBox(height: 12),
            _CheckItem(
              text: '私钥从我的手机上移除,保护好私钥的安全的责任全在于我!',
              value: _check3,
              onChanged: (v) => setState(() => _check3 = v),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _canDelete && !_loading ? _doRemove : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D1A7),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300],
                  disabledForegroundColor: Colors.grey[600],
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('删除', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }
}

class _CheckItem extends StatelessWidget {
  final String text;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _CheckItem({
    required this.text,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, color: Color(0xFF333333), height: 1.4),
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: value,
                onChanged: (v) => onChanged(v ?? false),
                activeColor: const Color(0xFF00D1A7),
                shape: const CircleBorder(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
