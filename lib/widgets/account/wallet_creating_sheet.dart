// lib/widgets/account/wallet_creating_sheet.dart
//
// DeBox 风格：底部白底圆角面板 + 居中图标 + 主标题 + 两行动态说明文案。

import 'dart:async';

import 'package:flutter/material.dart';

/// 主标题 + 两行灰色说明（可随步骤轮换）
class _StatusCopy {
  const _StatusCopy(this.title, this.line1, this.line2);
  final String title;
  final String line1;
  final String line2;
}

/// 等距透视三个立方体线框图标（示意 DeBox / 钱包模块）
class _CubeStackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1A1A1A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;

    final w = size.width;
    final h = size.height;
    final ox = w * 0.5;
    final oy = h * 0.42;
    final dx = w * 0.14;
    final dy = w * 0.08;

    Path isoCube(double cx, double cy, double s) {
      final p = Path();
      p.moveTo(cx, cy - s * 0.5);
      p.lineTo(cx + s * 0.55, cy - s * 0.12);
      p.lineTo(cx, cy + s * 0.22);
      p.lineTo(cx - s * 0.55, cy - s * 0.12);
      p.close();
      p.moveTo(cx - s * 0.55, cy - s * 0.12);
      p.lineTo(cx - s * 0.55, cy + s * 0.38);
      p.lineTo(cx, cy + s * 0.72);
      p.lineTo(cx, cy + s * 0.22);
      p.close();
      p.moveTo(cx + s * 0.55, cy - s * 0.12);
      p.lineTo(cx + s * 0.55, cy + s * 0.38);
      p.lineTo(cx, cy + s * 0.72);
      p.lineTo(cx, cy + s * 0.22);
      p.close();
      return p;
    }

    canvas.drawPath(isoCube(ox - dx, oy + dy, w * 0.38), paint);
    canvas.drawPath(isoCube(ox + dx, oy + dy, w * 0.38), paint);
    canvas.drawPath(isoCube(ox, oy - dy * 1.8, w * 0.38), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WalletCreatingSheet {
  /// 在执行 [task] 期间展示底部进度面板；完成后关闭并返回 [task] 的结果。
  /// [task] 抛出异常时先关闭面板，再将异常向上抛出。
  static Future<T> run<T>(
    BuildContext context, {
    required Future<T> Function() task,
  }) async {
    final completer = Completer<T>();

    unawaited(
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        isDismissible: false,
        enableDrag: false,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        barrierColor: Colors.black.withValues(alpha: 0.45),
        builder: (ctx) => _WalletCreatingPanel(
          onRun: () async {
            try {
              final r = await task();
              if (!ctx.mounted) return;
              Navigator.of(ctx).pop();
              if (!completer.isCompleted) completer.complete(r);
            } catch (e, st) {
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (!completer.isCompleted) completer.completeError(e, st);
            }
          },
        ),
      ),
    );

    return completer.future;
  }
}

class _WalletCreatingPanel extends StatefulWidget {
  const _WalletCreatingPanel({required this.onRun});
  final Future<void> Function() onRun;

  @override
  State<_WalletCreatingPanel> createState() => _WalletCreatingPanelState();
}

class _WalletCreatingPanelState extends State<_WalletCreatingPanel> {
  static const List<_StatusCopy> _rotate = [
    _StatusCopy('钱包创建中…', '正在连接钱包服务', '校验设备与账号信息'),
    _StatusCopy('钱包创建中…', '正在向服务器请求创建', '生成链上钱包地址'),
    _StatusCopy('钱包创建中…', '正在获取链上数据', '准备同步账户状态'),
    _StatusCopy('钱包创建中…', '正在加密您的助记词', '密钥仅保存在本机安全存储'),
    _StatusCopy('钱包创建中…', '正在写入本地钱包', '即将完成'),
  ];

  int _index = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
      if (!mounted) return;
      setState(() => _index = (_index + 1) % _rotate.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.onRun());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final copy = _rotate[_index];
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: EdgeInsets.fromLTRB(28, 28, 28, 28 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 88,
                  height: 88,
                  child: CustomPaint(painter: _CubeStackPainter()),
                ),
                const SizedBox(height: 20),
                Text(
                  copy.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111111),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  copy.line1,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  copy.line2,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.45,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
