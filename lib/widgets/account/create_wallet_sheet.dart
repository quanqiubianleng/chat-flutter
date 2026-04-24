// lib/widgets/account/create_wallet_sheet.dart

import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/wallet_repository.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/account/backup_mnemonic_sheet.dart';
import 'package:education/widgets/account/wallet_creating_sheet.dart';
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
  const _CreateWalletContent({required this.password, required this.onSuccess});

  @override
  ConsumerState<_CreateWalletContent> createState() => _CreateWalletContentState();
}

class _CreateWalletContentState extends ConsumerState<_CreateWalletContent> {
  bool _loading = false;
  final api = UserApi();

  Future<({String mnemonic, String address, String didId})> _performCreateWallet() async {
    final deviceNo = await UserCache.getDevice() ?? '';
    if (deviceNo.isEmpty) {
      throw StateError('设备号未就绪，请先设置密码页完成');
    }
    final repo = WalletRepository(Global.db);
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

    if (data['token'] != null) {
      await UserCache.saveToken(data['token'] as String);
    }
    if (data['refresh_token'] != null && (data['refresh_token'] as String).isNotEmpty) {
      await UserCache.saveRefreshToken(data['refresh_token'] as String);
    }
    await UserCache.saveUserId(userId);
    await UserCache.saveDid(didId);

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
        debugPrint('WalletRepository saveEncryptedMnemonic: $e');
      }
    }

    if (mounted) {
      final _ = ref.refresh(userProvider);
      ref.read(feedRefreshTriggerProvider.notifier).state++;
    }

    await ws.switchAccount();

    return (mnemonic: mnemonic, address: address, didId: didId);
  }

  Future<void> _createWallet() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      final r = await WalletCreatingSheet.run<({String mnemonic, String address, String didId})>(
        context,
        task: _performCreateWallet,
      );
      if (!mounted) return;
      Navigator.pop(context);
      BackupMnemonicSheet.show(
        context,
        mnemonic: r.mnemonic,
        address: r.address,
        didId: r.didId,
        onFinalSuccess: widget.onSuccess,
      );
    } catch (e) {
      final msg = e is StateError ? e.message : '$e';
      Fluttertoast.showToast(msg: e is StateError ? msg : '创建失败：$e');
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