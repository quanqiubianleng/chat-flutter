import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageBubble extends StatelessWidget {
  final String url;

  const ImageBubble({Key? key, required this.url}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 最大宽度（根据聊天泡泡的布局，通常留一些边距）
    const maxWidth = 240.0;

    return GestureDetector(
      onTap: () {
        // 点击放大查看
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => FullScreenImagePage(imageUrl: url),
            fullscreenDialog: true,
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: url,
          // 限制最大宽度，高度自适应
          width: maxWidth,
          // 高度不固定，让图片按比例缩放
          height: null,
          fit: BoxFit.cover,
          // 占位图
          placeholder: (context, url) => Container(
            width: maxWidth,
            height: maxWidth * 0.75, // 占位图比例，防止布局跳动
            color: Colors.grey[300],
            child: const Center(child: CircularProgressIndicator()),
          ),
          // 错误时显示
          errorWidget: (context, url, error) => Container(
            width: maxWidth,
            height: maxWidth * 0.75,
            color: Colors.grey[400],
            child: const Icon(Icons.broken_image, color: Colors.white),
          ),
          // 图片加载完成后，保持原始比例
          imageBuilder: (context, imageProvider) {
            return Container(
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                // 限制最大高度，防止图片过大撑破屏幕
                maxHeight: 400,
              ),
              child: Image(
                image: imageProvider,
                fit: BoxFit.contain, // 保持比例，不裁剪
              ),
            );
          },
        ),
      ),
    );
  }
}

// ======================== 全屏查看页面 ======================
class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImagePage({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            panEnabled: true,
            boundaryMargin: const EdgeInsets.all(100),
            minScale: 0.5,
            maxScale: 4.0,
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
              placeholder: (context, url) => const CircularProgressIndicator(),
              errorWidget: (context, url, error) => const Icon(
                Icons.broken_image,
                color: Colors.white,
                size: 100,
              ),
            ),
          ),
        ),
      ),
    );
  }
}