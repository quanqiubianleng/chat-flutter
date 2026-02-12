import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:education/core/utils/oss_url_helper.dart';
import 'package:education/widgets/common/oss_refreshable_image.dart';

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
        child: OssUrlHelper.isOssSignedUrl(url)
            ? OssRefreshableImage(
                url: url,
                width: maxWidth,
                height: maxWidth * 0.75,
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    width: maxWidth,
                    height: maxWidth * 0.75,
                    color: Colors.grey[300],
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (_, __, ___) => Container(
                  width: maxWidth,
                  height: maxWidth * 0.75,
                  color: Colors.grey[400],
                  child: const Icon(Icons.broken_image, color: Colors.white),
                ),
              )
            : CachedNetworkImage(
                imageUrl: url,
                width: maxWidth,
                height: null,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  width: maxWidth,
                  height: maxWidth * 0.75,
                  color: Colors.grey[300],
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  width: maxWidth,
                  height: maxWidth * 0.75,
                  color: Colors.grey[400],
                  child: const Icon(Icons.broken_image, color: Colors.white),
                ),
                imageBuilder: (context, imageProvider) {
                  return Container(
                    constraints: const BoxConstraints(
                      maxWidth: maxWidth,
                      maxHeight: 400,
                    ),
                    child: Image(
                      image: imageProvider,
                      fit: BoxFit.contain,
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