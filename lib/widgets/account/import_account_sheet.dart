// lib/widgets/account/import_account_sheet.dart
import 'package:education/pages/profile/import_mnemonic_page.dart';
import 'package:education/widgets/account/create_wallet_sheet.dart';
import 'package:flutter/material.dart';

class ImportAccountSheet {
  static void show(
    BuildContext context, {
    VoidCallback? onImportSuccess, // ← 新增这行！
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImportAccountContent(
        onImportSuccess: onImportSuccess, // ← 传进去
      ),
    );
  }
}

class _ImportAccountContent extends StatelessWidget {
  final VoidCallback? onImportSuccess; // 新增

  const _ImportAccountContent({
    this.onImportSuccess,
    super.key, // 加上 key，推荐
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 顶部拖拽条 + 标题 + 关闭按钮
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const Expanded(
                  child: Center(
                    child: Text(
                      '本地钱包',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 26),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // 三个选项
          _buildOption(
            context,
            icon: Icons.add_circle_outline,
            color: const Color(0xFF007AFF),
            title: "创建钱包",
            subtitle: "没有钱包去创建",
            onTap: () {
              Navigator.pop(context);
              CreateWalletSheet.show(
                context,
                onSuccess: onImportSuccess ?? () {}, // 刷新列表
              );
              // TODO: 跳转创建钱包页面
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text("即将打开创建钱包流程")),
              // );
            },
          ),
          _buildOption(
            context,
            icon: Icons.vpn_key_outlined,
            color: const Color(0xFFFF9500),
            title: "导入助记词",
            subtitle: "已有钱包导入去创建",
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ImportMnemonicPage(
                    onImportSuccess: onImportSuccess, // 关键！传进去！
                  ),
                ),
              );
            },
          ),
          _buildOption(
            context,
            icon: Icons.code,
            color: const Color(0xFF34C759),
            title: "导入私钥",
            subtitle: "导入单链账户",
            onTap: () {
              Navigator.pop(context);
              // TODO: 跳转私钥导入
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("即将打开私钥导入")),
              );
            },
          ),

          // 底部安全距离
          SizedBox(height: MediaQuery.of(context).padding.bottom + 20),
        ],
      ),
    );
  }

  Widget _buildOption(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: color, size: 26),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 13, color: Colors.grey),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}