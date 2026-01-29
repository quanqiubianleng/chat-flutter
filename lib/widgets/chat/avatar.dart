// lib/widgets/chat/avatar.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Avatar extends StatelessWidget {
  final String? url;        // 头像 URL，可为空
  final double size;        // 头像尺寸，默认 40
  final bool showOnline;    // 是否显示在线小绿点
  final double borderRadius; // 新增：可自定义圆角大小，默认 8

  const Avatar({
    Key? key,
    this.url,
    this.size = 40,
    this.showOnline = false,
    this.borderRadius = 8.0,  // 默认 8dp 圆角，你可以根据需要调整（如 6、10、12）
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: url != null && url!.trim().isNotEmpty
              ? CachedNetworkImage(
            imageUrl: url!.trim(),
            width: size,
            height: size,
            fit: BoxFit.cover,
            placeholder: (_, __) => Container(color: Colors.grey[300]),
            errorWidget: (_, __, ___) => _buildDefaultAvatar(),
          )
              : _buildDefaultAvatar(),
        ),
        if (showOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: size * 0.3,
              height: size * 0.3,
              decoration: BoxDecoration(
                color: const Color(0xFF00C853),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2), // 改成白色边框更清晰
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF2483FF),
        borderRadius: BorderRadius.circular(borderRadius), // 默认头像也带相同圆角
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}