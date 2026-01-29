import 'package:education/pages/user/setting.dart';
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
    return InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SettingsPage(),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12), // 可选：圆角水波纹
        splashColor: Colors.blue.withOpacity(0.3), // 可选：自定义水波颜色
        highlightColor: Colors.blue.withOpacity(0.1), // 可选：高亮颜色
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
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
                      ],
                    ),
                    const SizedBox(height: 0),
                    Row(
                      children: [
                        Text(shortAddress, style: const TextStyle(color: Colors.grey, fontSize: 14)),
                        // 复制按钮
                        InkWell(
                          borderRadius: BorderRadius.circular(20), // 圆形涟漪
                          onTap: () async {
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
                          child: Container(
                            padding: const EdgeInsets.all(8), // 点击区域
                            child: const Icon(
                              Icons.copy,
                              size: 18,
                              color: Color(0xFF999999),
                            ),
                          ),
                        )
                      ],
                    )
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 38, color: Colors.grey),
            ],
          ),
        ),
    );
  }
}