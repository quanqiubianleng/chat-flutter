import 'dart:io';

import 'package:education/core/utils/chat_media_uploader.dart';
import 'package:education/services/api_service.dart';
import 'package:education/services/feedback_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';

/// 问题反馈页面：邮箱(必填)、反馈内容(必填 0/2000)、图片上传、完成提交
class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  static const int _maxContentLength = 2000;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final FeedbackService _service = FeedbackService();
  final List<String> _imagePaths = [];
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (xFile == null || !mounted) return;
    setState(() => _imagePaths.add(xFile.path));
  }

  void _removeImage(int index) {
    setState(() => _imagePaths.removeAt(index));
  }

  bool _validate() {
    final email = _emailController.text.trim();
    final content = _contentController.text.trim();
    if (email.isEmpty) {
      Fluttertoast.showToast(msg: '请填写电子邮箱', toastLength: Toast.LENGTH_SHORT);
      return false;
    }
    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(email)) {
      Fluttertoast.showToast(msg: '请输入有效的电子邮箱', toastLength: Toast.LENGTH_SHORT);
      return false;
    }
    if (content.isEmpty) {
      Fluttertoast.showToast(msg: '请填写反馈内容', toastLength: Toast.LENGTH_SHORT);
      return false;
    }
    if (content.length > _maxContentLength) {
      Fluttertoast.showToast(
        msg: '反馈内容不能超过 $_maxContentLength 字',
        toastLength: Toast.LENGTH_SHORT,
      );
      return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_validate() || _submitting) return;

    setState(() => _submitting = true);

    try {
      List<String> imageUrls = [];
      if (_imagePaths.isNotEmpty && mounted) {
        try {
          imageUrls = await ChatMediaUploader.uploadMedias(
            context: context,
            localPaths: _imagePaths,
          );
        } catch (_) {
          // 上传失败仍可只提交文字反馈
        }
      }

      await _service.submitFeedback(
        email: _emailController.text.trim(),
        content: _contentController.text.trim(),
        imageUrls: imageUrls.isNotEmpty ? imageUrls : null,
      );

      if (!mounted) return;
      Fluttertoast.showToast(msg: '提交成功，感谢您的反馈', toastLength: Toast.LENGTH_SHORT);
      Navigator.pop(context);
    } on ApiException catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: e.message,
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    } catch (e) {
      if (mounted) {
        Fluttertoast.showToast(
          msg: '提交失败，请稍后重试',
          toastLength: Toast.LENGTH_SHORT,
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '问题反馈',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _submitting ? null : _submit,
            child: Text(
              '完成',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: _submitting ? Colors.grey : const Color(0xFF00D1A7),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: '电子邮箱 (必填)',
                hintStyle: TextStyle(color: Colors.grey),
                border: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00D1A7), width: 1.5),
                ),
              ),
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _contentController,
              maxLines: 8,
              maxLength: _maxContentLength,
              decoration: const InputDecoration(
                hintText: '反馈内容 (必填)',
                hintStyle: TextStyle(color: Colors.grey),
                alignLabelWithHint: true,
                border: InputBorder.none,
                enabledBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFFE0E0E0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF00D1A7), width: 1.5),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
              style: const TextStyle(fontSize: 16),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildImagePicker(),
                Text(
                  '${_contentController.text.length}/$_maxContentLength',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            if (_imagePaths.isNotEmpty) ...[
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_imagePaths.length, (i) {
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      SizedBox(
                        width: 72,
                        height: 72,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(_imagePaths[i]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      Positioned(
                        top: -6,
                        right: -6,
                        child: GestureDetector(
                          onTap: () => _removeImage(i),
                          child: const CircleAvatar(
                            radius: 10,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return InkWell(
      onTap: _pickImage,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE0E0E0)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.add_photo_alternate_outlined,
          size: 32,
          color: Colors.grey[500],
        ),
      ),
    );
  }
}
