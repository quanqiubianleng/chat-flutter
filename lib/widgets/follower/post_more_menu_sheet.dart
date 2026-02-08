import 'package:flutter/material.dart';

/// 动态三点菜单：黑色半透明弹窗（与聊天首页加号弹窗效果一致）
/// [isOwnPost] true=自己的动态：置顶、编辑、私密、删除、分享；false=他人：分享
void showPostMoreMenuSheet({
  required BuildContext context,
  required bool isOwnPost,
  required VoidCallback onShare,
  VoidCallback? onPin,
  VoidCallback? onEdit,
  VoidCallback? onPrivate,
  VoidCallback? onDelete,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => GestureDetector(
      onTap: () => Navigator.pop(ctx),
      behavior: HitTestBehavior.opaque,
      child: Container(
        color: Colors.black.withOpacity(0.3),
        child: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.fromLTRB(24, 48, 24, 0),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.75),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isOwnPost) ...[
                      _buildItem(ctx, '置顶', Icons.push_pin_outlined, () {
                        Navigator.pop(ctx);
                        onPin?.call();
                      }),
                      _buildItem(ctx, '编辑', Icons.edit_outlined, () {
                        Navigator.pop(ctx);
                        onEdit?.call();
                      }),
                      _buildItem(ctx, '私密', Icons.lock_outline, () {
                        Navigator.pop(ctx);
                        onPrivate?.call();
                      }),
                      _buildItem(ctx, '删除', Icons.delete_outline, () {
                        Navigator.pop(ctx);
                        onDelete?.call();
                      }),
                    ],
                    _buildItem(ctx, '分享', Icons.share_outlined, () {
                      Navigator.pop(ctx);
                      onShare();
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 使用 Overlay 方式显示（与聊天加号弹窗一致：小三角+黑色半透明）
void showPostMoreMenuOverlay({
  required BuildContext context,
  required LayerLink layerLink,
  required bool isOwnPost,
  required VoidCallback onShare,
  VoidCallback? onPin,
  VoidCallback? onEdit,
  VoidCallback? onPrivate,
  VoidCallback? onDelete,
}) {
  final overlay = Overlay.of(context);
  late OverlayEntry entry;
  void removeOverlay() {
    entry.remove();
  }
  entry = OverlayEntry(
    builder: (ctx) => GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: removeOverlay,
      child: Stack(
        children: [
          Positioned.fill(child: Container()),
          CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            offset: const Offset(-100, 60),
            child: Material(
              color: Colors.transparent,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    right: 18,
                    top: -10,
                    child: CustomPaint(
                      size: const Size(16, 10),
                      painter: _TrianglePainter(color: Colors.black.withOpacity(0.7)),
                    ),
                  ),
                  Container(
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isOwnPost) ...[
                          _buildOverlayItem('置顶', Icons.push_pin_outlined, () {
                            removeOverlay();
                            onPin?.call();
                          }),
                          _buildOverlayItem('编辑', Icons.edit_outlined, () {
                            removeOverlay();
                            onEdit?.call();
                          }),
                          _buildOverlayItem('私密', Icons.lock_outline, () {
                            removeOverlay();
                            onPrivate?.call();
                          }),
                          _buildOverlayItem('删除', Icons.delete_outline, () {
                            removeOverlay();
                            onDelete?.call();
                          }),
                        ],
                        _buildOverlayItem('分享', Icons.share_outlined, () {
                          removeOverlay();
                          onShare();
                        }),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
  overlay.insert(entry);
}

Widget _buildItem(BuildContext context, String title, IconData icon, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    ),
  );
}

Widget _buildOverlayItem(String title, IconData icon, VoidCallback onTap) {
  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.white70),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 15)),
        ],
      ),
    ),
  );
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  _TrianglePainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width / 2, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
