import 'package:flutter/material.dart';
import 'package:education/core/utils/oss_url_helper.dart';

/// 支持 OSS 签名 URL 过期后自动刷新的网络图片
/// 当加载失败且 URL 为 OSS 签名格式时，会请求后端刷新 URL 并重试
class OssRefreshableImage extends StatefulWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget Function(BuildContext, Widget, ImageChunkEvent?)? loadingBuilder;
  final Widget Function(BuildContext, Object, StackTrace?)? errorBuilder;

  const OssRefreshableImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.loadingBuilder,
    this.errorBuilder,
  });

  @override
  State<OssRefreshableImage> createState() => _OssRefreshableImageState();
}

class _OssRefreshableImageState extends State<OssRefreshableImage> {
  String _currentUrl = '';
  bool _refreshed = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;
  }

  @override
  void didUpdateWidget(OssRefreshableImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _currentUrl = widget.url;
      _refreshed = false;
    }
  }

  Future<void> _tryRefreshUrl() async {
    if (_isRefreshing || _refreshed) return;
    if (!OssUrlHelper.isOssSignedUrl(_currentUrl)) return;
    setState(() => _isRefreshing = true);
    try {
      final newUrl = await OssUrlHelper.refreshSignedUrl(_currentUrl);
      if (newUrl != null && newUrl.isNotEmpty && mounted) {
        setState(() {
          _currentUrl = newUrl;
          _refreshed = true;
        });
      } else if (mounted) {
        setState(() => _refreshed = true); // 避免重复请求
      }
    } catch (_) {
      if (mounted) setState(() => _refreshed = true); // 刷新失败也标记，避免重试
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _currentUrl,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      loadingBuilder: widget.loadingBuilder,
      errorBuilder: (context, error, stackTrace) {
        if (!_refreshed && !_isRefreshing && OssUrlHelper.isOssSignedUrl(_currentUrl)) {
          _tryRefreshUrl();
          return _defaultRefreshingWidget();
        }
        return widget.errorBuilder?.call(context, error, stackTrace) ??
            _defaultErrorWidget();
      },
    );
  }

  Widget _defaultRefreshingWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[100],
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }

  Widget _defaultErrorWidget() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: Colors.grey[200],
      child: Icon(Icons.image_not_supported_outlined, color: Colors.grey[400]),
    );
  }
}
