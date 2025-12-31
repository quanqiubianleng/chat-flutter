// lib/widgets/chat/avatar.dart
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class Avatar extends StatelessWidget {
  final String? url;        // 头像 URL，可为空
  final double size;        // 头像尺寸，默认 40
  final bool showOnline;    // 是否显示在线小绿点

  const Avatar({
    Key? key,
    this.url,
    this.size = 40,
    this.showOnline = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipOval(
          child: url != null && url!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: url!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(color: Colors.grey[800]),
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
                color: Color(0xFF00C853),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 2),
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
      color: const Color(0xFF2483FF),
      alignment: Alignment.center,
      child: Icon(
        Icons.person,
        color: Colors.white,
        size: size * 0.6,
      ),
    );
  }
}