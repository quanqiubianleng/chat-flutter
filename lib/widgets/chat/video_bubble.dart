// ===================== 视频气泡 ======================
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class VideoBubble extends StatelessWidget {
  final String thumbnail;

  const VideoBubble({Key? key, required this.thumbnail}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: CachedNetworkImage(
            imageUrl: thumbnail,
            width: 220,
            height: 320,
            fit: BoxFit.cover,
          ),
        ),
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.play_circle_fill,
                color: Colors.white, size: 64),
          ),
        ),
      ],
    );
  }
}