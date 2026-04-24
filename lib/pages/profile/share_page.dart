import 'dart:ui' as ui;

import 'package:education/core/cache/user_cache.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import 'package:education/services/user_service.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 分享页：与参考图一致，个人资料卡片 + 二维码 + 保存图片/复制链接
class SharePage extends StatefulWidget {
  const SharePage({super.key});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> {
  final GlobalKey _cardKey = GlobalKey();
  final UserApi _api = UserApi();

  String _username = '';
  String _avatarUrl = '';
  String _backgroundUrl = '';
  String _level = 'Lv.1';
  int _postCount = 0;
  int _iFollow = 0;
  int _followMe = 0;
  int _userId = 0;
  String _shareLink = '';
  bool _loading = true;
  bool _savingImage = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getShareProfile();
      if (!mounted) return;
      final code = data['code'];
      if (code != 200) {
        setState(() {
          _error = data['msg']?.toString() ?? '加载失败';
          _loading = false;
        });
        return;
      }
      final username = data['username']?.toString() ?? '未设置';
      final avatarUrl = data['avatar_url']?.toString() ?? '';
      final backgroundUrl = data['background_url']?.toString() ?? '';
      final level = data['level']?.toString() ?? 'Lv.1';
      final postCount = _parseInt(data['post_count']);
      final iFollow = _parseInt(data['i_follow']);
      final followMe = _parseInt(data['follow_me']);
      final shareLink = data['share_link']?.toString() ?? '';
      var userId = _parseInt(data['userId'] ?? data['user_id']);

      if (userId <= 0) {
        final cachedUid = await UserCache.getUserId();
        userId = cachedUid ?? 0;
      }

      if (userId <= 0) {
        try {
          final user = await _api.getUserInfo();
          userId = _parseInt(user['userId'] ?? user['user_id']);
        } catch (_) {}
      }

      if (!mounted) return;
      setState(() {
        _username = username;
        _avatarUrl = avatarUrl;
        _backgroundUrl = backgroundUrl;
        _level = level;
        _userId = userId;
        _postCount = postCount;
        _iFollow = iFollow;
        _followMe = followMe;
        _shareLink = shareLink;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  Future<void> _saveImage() async {
    if (_savingImage) return;
    setState(() => _savingImage = true);
    try {
      final boundary =
          _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        _showToast('无法截取当前画面');
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        _showToast('生成图片失败');
        return;
      }

      final granted = await Gal.requestAccess();
      if (!granted) {
        _showToast('没有相册权限，无法保存');
        return;
      }

      final name = 'share_card_${DateTime.now().millisecondsSinceEpoch}';
      await Gal.putImageBytes(byteData.buffer.asUint8List(), name: name);
      _showToast('已保存到相册');
    } catch (e) {
      _showToast('保存失败: $e');
    } finally {
      if (mounted) {
        setState(() => _savingImage = false);
      }
    }
  }

  Future<void> _copyLink() async {
    if (_shareLink.isEmpty) {
      _showToast('暂无分享链接');
      return;
    }
    await Clipboard.setData(ClipboardData(text: _shareLink));
    _showToast('已复制链接');
  }

  void _showToast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE8F5E9), // 浅绿
      body: SafeArea(
        child: Column(
          children: [
            AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.chevron_left, color: Colors.black87),
                onPressed: () => Navigator.pop(context),
              ),
              title: const Text(
                '分享',
                style: TextStyle(color: Colors.black87, fontSize: 18),
              ),
              centerTitle: true,
              actions: [
                IconButton(
                  icon: const Icon(Icons.ios_share, color: Colors.black87),
                  onPressed: () async {
                    await _copyLink();
                    try {
                      await Share.share(_shareLink, subject: '邀请你加入');
                    } catch (_) {}
                  },
                ),
              ],
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: _loading
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(48),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    : _error != null
                    ? Center(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                    : RepaintBoundary(key: _cardKey, child: _buildCard()),
              ),
            ),
            if (!_loading && _error == null) _buildBottomButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // 顶部横幅（深蓝紫渐变）
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: _backgroundUrl.isNotEmpty
                ? Image.network(
                    _backgroundUrl,
                    height: 100,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _gradientBanner(),
                  )
                : _gradientBanner(),
          ),
          // 头像（与白底重叠）
          Transform.translate(
            offset: const Offset(0, -36),
            child: Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: _avatarUrl.isNotEmpty
                      ? Image.network(
                          _avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _placeholderAvatar(),
                        )
                      : _placeholderAvatar(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          // 昵称 + 等级
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                _username.isNotEmpty && _username != 'null' ? _username : '未设置',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D1A7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      _level,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 动态 | 关注 | 粉丝
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _statItem('动态', _postCount),
              _divider(),
              _statItem('关注', _iFollow),
              _divider(),
              _statItem('粉丝', _followMe),
            ],
          ),
          const SizedBox(height: 20),
          // 二维码
          QrImageView(
            data: _buildQrPayload(),
            version: QrVersions.auto,
            size: 160,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF333333),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '扫描加入 BBT, 和我一起',
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  String _buildQrPayload() {
    if (_userId > 0) {
      final share = Uri.encodeComponent(_shareLink);
      if (_shareLink.isNotEmpty) {
        return 'bbt://user/$_userId?share=$share';
      }
      return 'bbt://user/$_userId';
    }
    if (_shareLink.isNotEmpty) return _shareLink;
    return 'https://app.example.com';
  }

  Widget _gradientBanner() {
    return Container(
      height: 100,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF37474F), Color(0xFF455A64)],
        ),
      ),
    );
  }

  Widget _placeholderAvatar() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(Icons.person, size: 40, color: Colors.grey),
    );
  }

  Widget _statItem(String label, int value) {
    return Text(
      '$label $value',
      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
    );
  }

  Widget _divider() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      width: 1,
      height: 14,
      color: Colors.grey[400],
    );
  }

  Widget _buildBottomButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _circleButton(
            icon: Icons.download_outlined,
            label: '保存图片',
            onTap: _saveImage,
          ),
          _circleButton(icon: Icons.link, label: '复制链接', onTap: _copyLink),
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(32),
          elevation: 2,
          shadowColor: Colors.black26,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(32),
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              child: Icon(icon, size: 28, color: Colors.grey[700]),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
      ],
    );
  }
}
