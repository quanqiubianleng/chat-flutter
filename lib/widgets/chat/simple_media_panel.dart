// file: simple_media_panel.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

/// 极简底部操作栏：仅包含 【相册】【拍摄】【红包】【语音】【收藏】【转账】
/// 支持通过 visible 参数控制显示/隐藏（带动画）
/// 已优化布局，避免小屏幕底部溢出
class SimpleMediaPanel extends StatelessWidget {
  /// 是否显示该面板
  final bool visible;

  /// 选择相册图片回调（支持多选）
  final ValueChanged<List<String>>? onAlbumPicked;

  /// 拍照后回调
  final ValueChanged<String>? onPhotoTaken;

  /// 点击红包回调
  final VoidCallback? onRedPacket;

  /// 点击转账
  final VoidCallback? onTransfer;

  const SimpleMediaPanel({
    Key? key,
    this.visible = false,
    this.onAlbumPicked,
    this.onPhotoTaken,
    this.onRedPacket,
    this.onTransfer,
  }) : super(key: key);

  // 相册多选
  Future<void> _pickFromAlbum(BuildContext context) async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (files.isNotEmpty && context.mounted) {
      onAlbumPicked?.call(files.map((e) => e.path).toList());
    }
  }

  // 拍照
  Future<void> _takePhoto(BuildContext context) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.camera);
    if (file != null && context.mounted) {
      onPhotoTaken?.call(file.path);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      child: Visibility(
        visible: visible,
        maintainState: true,
        child: Container(
          width: double.infinity,
          // 关键：限制最大高度，防止在小屏幕 + 键盘弹出时溢出
          constraints: const BoxConstraints(maxHeight: 220),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 16),
          color: const Color(0xFFF5F5F5),
          child: GridView.count(
            crossAxisCount: 4,                    // 固定每行 4 个
            crossAxisSpacing: 16,                 // 列间距（适中）
            mainAxisSpacing: 12,                  // 行间距（减小以节省高度）
            shrinkWrap: true,                     // 必须：收缩高度
            physics: const NeverScrollableScrollPhysics(), // 禁用内部滚动
            childAspectRatio: 0.95,               // 略微压扁，视觉更协调
            children: [
              _buildItem(
                icon: Icons.photo_library_outlined,
                label: "相册",
                onTap: () => _pickFromAlbum(context),
              ),
              _buildItem(
                icon: Icons.camera_alt_outlined,
                label: "拍摄",
                onTap: () => _takePhoto(context),
              ),
              _buildItem(
                icon: Icons.monetization_on_outlined,
                label: "红包",
                onTap: () => onRedPacket?.call(),
              ),
              _buildItem(
                icon: Icons.mic_none,
                label: "语音",
                onTap: () => onRedPacket?.call(),
              ),
              _buildItem(
                icon: Icons.star_border,
                label: "收藏",
                onTap: () => onRedPacket?.call(),
              ),
              _buildItem(
                icon: Icons.swap_horiz,
                label: "转账",
                onTap: () => onTransfer?.call(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(12),  // 略微减小内边距
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 24,  // 从 26 → 24，节省高度
              color: color ?? const Color(0xFF333333),
            ),
          ),
          const SizedBox(height: 6),  // 从 8 → 6
          Text(
            label,
            style: TextStyle(
              fontSize: 12,  // 从 13 → 12
              color: color ?? const Color(0xFF333333),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}