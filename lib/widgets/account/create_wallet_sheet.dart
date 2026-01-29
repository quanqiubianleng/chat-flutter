// lib/widgets/account/create_wallet_sheet.dart

import 'package:education/core/cache/user_cache.dart';
import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
// 你的 api
import 'package:education/widgets/account/backup_mnemonic_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/global.dart';
import '../../providers/user_provider.dart';

class CreateWalletSheet {
  static void show(
    BuildContext context, {
    required VoidCallback onSuccess, // 创建完刷新列表
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreateWalletContent(onSuccess: onSuccess),
    );
  }
}

class _CreateWalletContent extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;
  _CreateWalletContent({required this.onSuccess});

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
      final deviceNo = await UserCache.getDevice() ?? "gfdgfdhgfdh";
      final result = await api.createWallet({"did_id": "...", "password": "...", "type": 1, "deviceNo": deviceNo}); // 你后端接口
      
      print(result);
      if (result['code'] != 200) {
        throw result['msg'] ?? '创建失败';
      }

      final data = result;
      final String mnemonic = data['mnemonic'];
      final String address = data['wallet_address'];
      final String didId = data['did_id'] ?? '';

      // ============ 关键修复：创建成功 = 自动切换到新账号 ============
      // 1. 保存新凭证（后端通常会返回新 token）
      if (result['token'] != null) {
        await UserCache.saveToken(result['token']);
      }
      await UserCache.saveUserId(result['userId'] ?? data['userId']);
      await UserCache.saveDid(didId);

      // 2. 刷新全局用户状态
      // ignore: use_build_context_synchronously
      if (mounted) {
        // 或者如果你用的是 ref.refresh
        ref.refresh(userProvider);
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