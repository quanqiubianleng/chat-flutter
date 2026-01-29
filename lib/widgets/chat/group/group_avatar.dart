import 'package:flutter/material.dart';
import 'package:nine_grid_view/nine_grid_view.dart';

class GroupAvatar extends StatelessWidget {
  final List<String> avatarUrls;      // 改成参数传入
  final double size;                  // 可选：控制整体大小（默认正方形）
  final double spacing;               // 可选：间距

  const GroupAvatar({
    super.key,
    required this.avatarUrls,
    this.size = 48.0,
    this.spacing = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    // 最多只显示前9个（微信风格通常最多9格）
    final displayUrls = avatarUrls.take(9).toList();

    return NineGridView(
      width: size,
      height: size,              // 正方形
      space: spacing,
      padding: const EdgeInsets.all(3),
      type: NineGridType.weChatGp,
      itemCount: displayUrls.length,
      decoration: BoxDecoration(
        color: Colors.grey[200],                    // 背景颜色
        borderRadius: BorderRadius.circular(8),    // 整体圆角
      ),
      itemBuilder: (context, index) {
        return Image.network(
          displayUrls[index],
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return const Center(
              child: CircularProgressIndicator(strokeWidth: 2),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            // 加载失败时的占位图（建议加上）
            return Image.asset('assets/images/default_avatar.png');
          },
        );
      },
    );
  }
}