import 'package:flutter/material.dart';
import 'package:education/widgets/user/user.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';

class ProfileHeaderCard extends StatelessWidget {
  final User user;

  const ProfileHeaderCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user.username.isNotEmpty && user.username != "null"
        ? user.username
        : (user.walletAddress.length > 10
            ? "User#${user.walletAddress.substring(2, 8).toUpperCase()}"
            : "匿名用户");

    final shortAddress = user.walletAddress.length > 10
        ? "${user.walletAddress.substring(0, 6)}...${user.walletAddress.substring(user.walletAddress.length - 4)}"
        : user.walletAddress;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: user.avatarUrl.isNotEmpty
                ? Image.network(user.avatarUrl, width: 60, height: 60, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: Colors.grey[300], child: const Icon(Icons.person, size: 36, color: Colors.white)))
                : Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(16)),
                    child: const Icon(Icons.person, size: 36, color: Colors.purple),
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min, // 避免 Expanded 或默认填满
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,  // 新增这一行！关键
              children: [
                Row(
                  children: [
                    Text(displayName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Chip(
                      backgroundColor: const Color(0xFFE8F5E8),
                      padding: const EdgeInsets.symmetric(horizontal: 6), // 更紧凑
                      labelPadding: const EdgeInsets.symmetric(horizontal: 4), // 减小文字边距
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap, // 关键：减少点击区域和高度
                      visualDensity: VisualDensity.compact, // Flutter 推荐的紧凑模式
                      label: Text(user.level, style: const TextStyle(color: Color(0xFF00C853), fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                const SizedBox(height: 0),
                Row(
                  children: [
                    Text(shortAddress, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                    // 复制按钮
                    IconButton(
                      icon: const Icon(Icons.copy, size: 18, color: Color(0xFF999999)),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ), // 正确写法
                      splashRadius: 20,
                      tooltip: "复制",
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: user.walletAddress));
                        Fluttertoast.showToast(
                          msg: "已复制钱包地址",
                          toastLength: Toast.LENGTH_SHORT,
                          gravity: ToastGravity.BOTTOM,
                          backgroundColor: Colors.black87,
                          textColor: Colors.white,
                          fontSize: 15,
                        );
                      },
                    ),
                  ],
                )
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 38, color: Colors.grey),
        ],
      ),
    );
  }
}