import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ImageUploadButton extends StatefulWidget {
  final double size;                    // 每个图片/按钮的正方形大小
  final int maxImages;                  // 最多允许上传几张
  final BorderRadius? borderRadius;
  final Color backgroundColor;
  final Color iconColor;
  final ValueChanged<List<File>> onImagesChanged;  // 每次变化都回调当前所有图片列表

  const ImageUploadButton({
    super.key,
    this.size = 100,
    this.maxImages = 3,                 // 默认最多3张，可传入修改
    this.borderRadius,
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.iconColor = Colors.grey,
    required this.onImagesChanged,
  });

  @override
  State<ImageUploadButton> createState() => _ImageUploadButtonState();
}

class _ImageUploadButtonState extends State<ImageUploadButton> {
  final List<File> _selectedImages = [];
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    if (_selectedImages.length >= widget.maxImages) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('最多只能上传 ${widget.maxImages} 张图片')),
      );
      return;
    }

    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        // maxWidth: 1200,
        // imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImages.add(File(image.path));
        });
        widget.onImagesChanged(_selectedImages);
      }
    } catch (e) {
      debugPrint('图片选择错误: $e');
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
    });
    widget.onImagesChanged(_selectedImages);
  }

  @override
  Widget build(BuildContext context) {
    final br = widget.borderRadius ?? BorderRadius.circular(12);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        // 已选图片
        ...List.generate(_selectedImages.length, (index) {
          return Stack(
            children: [
              ClipRRect(
                borderRadius: br,
                child: Image.file(
                  _selectedImages[index],
                  width: widget.size,
                  height: widget.size,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: -6,
                right: -6,
                child: GestureDetector(
                  onTap: () => _removeImage(index),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ],
          );
        }),

        // “+ 添加”按钮（只有没达到上限时显示）
        if (_selectedImages.length < widget.maxImages)
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                color: widget.backgroundColor,
                borderRadius: br,
                border: Border.all(color: Colors.grey.shade300, width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_rounded,
                    size: widget.size * 0.4,
                    color: widget.iconColor, 
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '添加',
                    style: TextStyle(
                      color: widget.iconColor,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}