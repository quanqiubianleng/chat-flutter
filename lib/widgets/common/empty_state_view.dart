import 'package:flutter/material.dart';

/// 项目统一空数据展示：与 BbtCenterPage 一致的插画 +「什么都没有」
/// 除聊天页、会话页外，所有数据为空时使用此组件
class EmptyStateView extends StatelessWidget {
  const EmptyStateView({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 160,
            height: 120,
            margin: const EdgeInsets.only(bottom: 24),
            child: CustomPaint(
              painter: _EmptyStatePainter(),
            ),
          ),
          Text(
            '什么都没有',
            style: TextStyle(
              fontSize: 15,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

/// 简约空状态插画：卷轴、虚线、树木、云（与 BbtCenterPage 一致）
class _EmptyStatePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final fill = Paint()
      ..color = Colors.grey.shade100
      ..style = PaintingStyle.fill;

    final centerX = size.width / 2;
    final centerY = size.height / 2;

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, centerY), width: 100, height: 70),
      const Radius.circular(8),
    );
    canvas.drawRRect(rect, fill);
    canvas.drawRRect(rect, p);

    final dashPath = Path()
      ..moveTo(centerX - 35, centerY - 8)
      ..lineTo(centerX + 35, centerY - 8);
    canvas.drawPath(
      dashPath,
      Paint()
        ..color = Colors.grey.shade400
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke,
    );

    canvas.drawCircle(Offset(centerX - 38, centerY + 15), 6, fill);
    canvas.drawCircle(Offset(centerX - 38, centerY + 15), 6, p);
    canvas.drawLine(
      Offset(centerX - 38, centerY + 22),
      Offset(centerX - 38, centerY + 32),
      p..strokeWidth = 1.5,
    );

    canvas.drawCircle(Offset(centerX + 40, centerY + 8), 5, fill);
    canvas.drawCircle(Offset(centerX + 40, centerY + 8), 5, p);
    canvas.drawLine(
      Offset(centerX + 40, centerY + 14),
      Offset(centerX + 40, centerY + 24),
      p..strokeWidth = 1.2,
    );

    canvas.drawCircle(Offset(centerX - 30, centerY - 28), 12, fill);
    canvas.drawCircle(Offset(centerX - 30, centerY - 28), 12, p);
    canvas.drawCircle(Offset(centerX - 15, centerY - 30), 10, fill);
    canvas.drawCircle(Offset(centerX - 15, centerY - 30), 10, p);
    canvas.drawCircle(Offset(centerX + 5, centerY - 28), 14, fill);
    canvas.drawCircle(Offset(centerX + 5, centerY - 28), 14, p);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
