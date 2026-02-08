// lib/widgets/account/create_wallet_sheet.dart

import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/wallet_repository.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/account/backup_mnemonic_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';
import '../../providers/feed_refresh_provider.dart';
import '../../providers/user_provider.dart';

class CreateWalletSheet {
  static void show(
    BuildContext context, {
    String password = '',
    required VoidCallback onSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateWalletContent(password: password, onSuccess: onSuccess),
    );
  }
}

class _CreateWalletContent extends ConsumerStatefulWidget {
  final String password;
  final VoidCallback onSuccess;
  _CreateWalletContent({required this.password, required this.onSuccess});

  @override
  ConsumerState<_CreateWalletContent> createState() => _CreateWalletContentState();
}

class _CreateWalletContentState extends ConsumerState<_CreateWalletContent> {
  bool _loading = false;
  final api = UserApi();

  Future<void> _createWallet() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final deviceNo = await UserCache.getDevice() ?? '';
      if (deviceNo.isEmpty) {
        Fluttertoast.showToast(msg: '设备号未就绪，请先设置密码页完成');
        setState(() => _loading = false);
        return;
      }
      final repo = WalletRepository(Global.db);
      // 优先使用传入密码，否则从本地已保存的账号获取（当前设备统一密码）
      String pwd = widget.password.isNotEmpty ? widget.password : '';
      if (pwd.isEmpty || pwd.length < 6) {
        pwd = await repo.getDevicePassword() ?? '';
      }
      final pwdForApi = pwd.length >= 6 ? pwd : '...';
      final data = await api.createWallet({
        'did_id': '...',
        'password': pwdForApi,
        'type': 1,
        'deviceNo': deviceNo,
      });
      final String mnemonic = data['mnemonic'] as String? ?? '';
      final String address = data['wallet_address'] as String? ?? '';
      final String didId = data['did_id'] as String? ?? '';
      final int userId = (data['userId'] as num?)?.toInt() ?? 0;

      // 创建成功：保存新凭证并切换账号
      if (data['token'] != null) {
        await UserCache.saveToken(data['token'] as String);
      }
      await UserCache.saveUserId(userId);
      await UserCache.saveDid(didId);

      // 加密并存储助记词到本地（使用上面解析出的 pwd）
      if (mnemonic.isNotEmpty && pwd.length >= 6) {
        try {
          await repo.saveEncryptedMnemonic(
            userId: userId,
            didId: didId,
            walletAddress: address,
            mnemonic: mnemonic,
            password: pwd,
            deviceNo: deviceNo,
          );
        } catch (e) {
          // 存储失败不影响主流程，仅记录
          debugPrint('WalletRepository saveEncryptedMnemonic: $e');
        }
      }

      // 2. 刷新全局用户状态
      // ignore: use_build_context_synchronously
      if (mounted) {
        ref.refresh(userProvider);
        ref.read(feedRefreshTriggerProvider.notifier).state++; // 新账号登录后刷新动态列表
      }

      // 3. WebSocket 切换账号
      ws.switchAccount();

      // ============ 结束修复 ============

      // 成功 → 跳转到备份页面
      Navigator.pop(context); // 关闭当前弹窗
      BackupMnemonicSheet.show(
        context,
        mnemonic: mnemonic,
        address: address,
        didId: didId,
        onFinalSuccess: widget.onSuccess, // 最终完成才刷新
      );
    } catch (e) {
      Fluttertoast.showToast(msg: "创建失败：$e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 32),
              //Image.asset('assets/images/wallet_create.png', width: 120), // 可换成你自己的图
              const SizedBox(height: 32),
              const Text('创建新钱包', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('将为你生成一个全新钱包地址\n请务必在下一步备份助记词', 
                   textAlign: TextAlign.center, style: TextStyle(color: Colors.grey[600], height: 1.5)),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _loading ? null : _createWallet,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1A7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: _loading
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('立即创建', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}