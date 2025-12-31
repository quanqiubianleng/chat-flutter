// lib/widgets/account/backup_mnemonic_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
// import '../services/user_service.dart';

class BackupMnemonicSheet {
  static void show(
    BuildContext context, {
    required String mnemonic,
    required String address,
    String? didId,
    required VoidCallback onFinalSuccess,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: false, // 重要！不能点外面关掉
      enableDrag: false,
      builder: (_) => _BackupMnemonicContent(
        mnemonic: mnemonic,
        address: address,
        didId: didId,
        onFinalSuccess: onFinalSuccess,
      ),
    );
  }
}

class _BackupMnemonicContent extends StatefulWidget {
  final String mnemonic;
  final String address;
  final String? didId;
  final VoidCallback onFinalSuccess;

  const _BackupMnemonicContent({required this.mnemonic, required this.address, this.didId, required this.onFinalSuccess});

  @override
  State<_BackupMnemonicContent> createState() => _BackupMnemonicContentState();
}

class _BackupMnemonicContentState extends State<_BackupMnemonicContent> with TickerProviderStateMixin {
  late AnimationController _controller;
  // final api = UserApi();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(milliseconds: 1200), vsync: this)..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<String> get words => widget.mnemonic.split(' ');

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // 顶部
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Container(width: 36, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
                const Expanded(child: Center(child: Text('备份助记词', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 36), // 占位，不给关闭按钮！
              ],
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 15, left: 20, right: 20, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('请按顺序抄写助记词', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFFFFFBEB), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFFFFD54F))),
                    child: const Text('警告：丢失助记词将导致资产永久无法找回！\n请抄写到纸上并妥善保存，切勿截图或保存到网络设备。', style: TextStyle(color: Color(0xFFCD6F00), height: 1.6)),
                  ),
                  const SizedBox(height: 20),

                  // 12个词网格 + 飞入动画
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      childAspectRatio: 2.8,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                    ),
                    itemCount: 12,
                    itemBuilder: (_, i) {
                      return AnimatedBuilder(
                        animation: _controller,
                        builder: (_, child) {
                          final delay = i * 0.08;
                          final progress = (_controller.value - delay).clamp(0.0, 1.0);
                          return Transform.translate(
                            offset: Offset(0, 40 * (1 - progress)),
                            child: Opacity(
                              opacity: progress,
                              child: Container(
                                alignment: Alignment.center,
                                decoration: BoxDecoration(color: const Color(0xFFF2F2F7), borderRadius: BorderRadius.circular(12)),
                                child: Text('${i + 1}. ${words[i]}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // 复制按钮
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy, size: 20),
                      label: const Text('复制助记词', style: TextStyle(fontSize: 16)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFF00D1A7)), foregroundColor: const Color(0xFF00D1A7)),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: widget.mnemonic));
                        Fluttertoast.showToast(msg: "助记词已复制，请立即粘贴到纸上");
                      },
                    ),
                  ),
                  const SizedBox(height: 10),

                  // 完成按钮
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D1A7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                      onPressed: () async {
                        // 可选：调用后端“确认已备份”接口，防止用户跳过
                        // await api.confirmMnemonicBacked(widget.didId ?? '');

                        widget.onFinalSuccess(); // 刷新账号列表
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('钱包创建成功！'), backgroundColor: Color(0xFF00D1A7)),
                        );
                      },
                      child: const Text('我已备份完成', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}