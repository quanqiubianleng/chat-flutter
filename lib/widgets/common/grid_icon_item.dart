// lib/widgets/common/grid_icon_item.dart
import 'package:flutter/material.dart';

class GridIconItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback? onTap;
  /// 可选：本地图片路径（如 assets/images/BBT.png），有则优先显示图而非 icon
  final String? imageAsset;

  const GridIconItem({
    super.key,
    required this.icon,
    required this.label,
    this.color,
    this.onTap,
    this.imageAsset,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = LayoutBuilder(
      builder: (context, constraints) {
        // 动态计算可用高度，永远不会溢出
        final double availableHeight = constraints.maxHeight;
        final boxSize = (availableHeight * 0.6).clamp(32.0, 48.0);

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: boxSize,
              height: boxSize,
              constraints: const BoxConstraints(maxWidth: 48, maxHeight: 48),
              decoration: BoxDecoration(
                color: (color ?? Colors.grey).withOpacity(0.12),
                borderRadius: BorderRadius.circular(color != null ? 14 : 12),
              ),
              child: imageAsset != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(color != null ? 14 : 12),
                      child: Image.asset(
                        imageAsset!,
                        width: boxSize,
                        height: boxSize,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(icon, size: (availableHeight * 0.35).clamp(20.0, 28.0), color: color ?? Colors.black87),
                      ),
                    )
                  : Icon(
                      icon,
                      size: (availableHeight * 0.35).clamp(20.0, 28.0),
                      color: color ?? Colors.black87,
                    ),
            ),
            SizedBox(height: availableHeight * 0.08), // 动态间距
            // 文字强制压缩进剩余空间
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    height: 1.0,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                ),
              ),
            ),
          ],
        );
      },
    );
    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}