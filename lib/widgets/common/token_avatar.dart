import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

import 'package:education/config/known_tokens.dart';

/// 代币头像：优先用本地 BBT/BNB/USDT 图，否则 [iconUrl] 网络图，失败或无图时显示首字母。
class TokenAvatar extends StatelessWidget {
  /// 代币符号或名称，用于无图标时显示首字母；BBT/BNB/USDT 会优先用 assets/images/ 下的本地图
  final String symbol;
  /// 图标 URL，为空或加载失败时显示首字母；当 symbol 有本地图时会被忽略
  final String? iconUrl;
  /// 无图标时圆圈背景/文字颜色
  final Color iconColor;
  /// 头像尺寸（宽高一致）
  final double size;

  const TokenAvatar({
    super.key,
    required this.symbol,
    this.iconUrl,
    this.iconColor = Colors.grey,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final localAsset = KnownTokens.getLocalLogoAsset(symbol);
    if (localAsset != null) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.asset(
            localAsset,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildLetterFallback(),
          ),
        ),
      );
    }
    if (iconUrl != null && iconUrl!.isNotEmpty) {
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: _SafeTokenImage(
            url: iconUrl!,
            size: size,
            fallback: _buildLetterFallback(),
          ),
        ),
      );
    }
    return _buildLetterFallback();
  }

  Widget _buildLetterFallback() {
    final firstLetter = symbol.isEmpty ? '?' : symbol.trim()[0].toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: iconColor.withOpacity(0.25),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: TextStyle(
            color: iconColor,
            fontWeight: FontWeight.w600,
            fontSize: size * 0.45,
          ),
        ),
      ),
    );
  }
}

/// 安全加载网络图片：先请求字节再 Image.memory，失败则显示 fallback，不抛错到 image 管道。
class _SafeTokenImage extends StatefulWidget {
  final String url;
  final double size;
  final Widget fallback;

  const _SafeTokenImage({
    required this.url,
    required this.size,
    required this.fallback,
  });

  @override
  State<_SafeTokenImage> createState() => _SafeTokenImageState();
}

class _SafeTokenImageState extends State<_SafeTokenImage> {
  static final Map<String, Uint8List> _memoryCache = {};
  static const int _maxCacheEntries = 200;

  Uint8List? _bytes;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _bytes = _memoryCache[widget.url];
    if (_bytes == null && !_failed) _load();
  }

  @override
  void didUpdateWidget(covariant _SafeTokenImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _bytes = _memoryCache[widget.url];
      _failed = false;
      if (_bytes == null) _load();
    }
  }

  Future<void> _load() async {
    final url = widget.url;
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ));
    try {
      final resp = await dio.get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final data = resp.data;
      if (data == null || data.isEmpty) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      final bytes = Uint8List.fromList(data);
      while (_memoryCache.length >= _maxCacheEntries) {
        _memoryCache.remove(_memoryCache.keys.first);
      }
      _memoryCache[url] = bytes;
      if (mounted) setState(() { _bytes = bytes; });
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_bytes != null) {
      return Image.memory(
        _bytes!,
        fit: BoxFit.cover,
        width: widget.size,
        height: widget.size,
        errorBuilder: (_, __, ___) => widget.fallback,
      );
    }
    return widget.fallback;
  }
}
