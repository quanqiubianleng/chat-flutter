// lib/widgets/common/grid_icon_item.dart
import 'package:flutter/material.dart';

class GridIconItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const GridIconItem({
    super.key,
    required this.icon,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 动态计算可用高度，永远不会溢出
        final double availableHeight = constraints.maxHeight;

        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: availableHeight * 0.6,   // 图标占 60%
              height: availableHeight * 0.6,
              constraints: const BoxConstraints(maxWidth: 48, maxHeight: 48),
              decoration: BoxDecoration(
                color: (color ?? Colors.grey).withOpacity(0.12),
                borderRadius: BorderRadius.circular(color != null ? 14 : 12),
              ),
              child: Icon(
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
  }
}