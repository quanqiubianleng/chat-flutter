import 'package:flutter/material.dart';

/// 导出助记词 - 安全提示页，用户确认后进入下一步查看助记词
class ExportMnemonicWarningPage extends StatelessWidget {
  const ExportMnemonicWarningPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '导出助记词',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF00D1A7),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '助记词由用户个人保管，一旦丢失无法找回，请谨记以下安全点',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600], height: 1.5),
                ),
                const SizedBox(height: 32),
                _WarningItem(
                  icon: Icons.lock_outline,
                  text: '如果我丢失了助记词，我的资产将永远消失!',
                ),
                const SizedBox(height: 20),
                _WarningItem(
                  icon: Icons.visibility_off_outlined,
                  text: '如果我向任何人透露或分享我的助记词，我的资产可能会被盗!',
                ),
                const SizedBox(height: 20),
                _WarningItem(
                  icon: Icons.phone_android_outlined,
                  text: '助记词只存在我的手机里，保证好助记词的安全的责任在我!',
                ),
                const SizedBox(height: 20),
                _WarningItem(
                  icon: Icons.check_circle_outline,
                  text: '在下一步里，您将看到可以恢复钱包的助记词，请谨记以上安全点!',
                ),
              ],
            ),
          ),
          Positioned(
            right: 0,
            top: 100,
            child: CustomPaint(
              size: const Size(120, 120),
              painter: _GreenArcPainter(),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D1A7),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('我知道了', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningItem extends StatelessWidget {
  final IconData icon;
  final String text;

  const _WarningItem({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 22, color: Colors.grey[700]),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 15, color: Colors.grey[800], height: 1.5),
          ),
        ),
      ],
    );
  }
}

class _GreenArcPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF00D1A7).withOpacity(0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    canvas.drawArc(
      Rect.fromLTWH(0, 0, size.width * 2, size.height * 2),
      -0.5,
      1.2,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
