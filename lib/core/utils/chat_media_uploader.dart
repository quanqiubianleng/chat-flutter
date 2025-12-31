import 'dart:io';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart'; // 新增依赖：识别文件 MIME 类型
import 'package:path/path.dart' as path;
import 'package:education/core/utils/oss_upload_service.dart';

class ChatMediaUploader {
  ChatMediaUploader._();

  // 生成日期文件夹：2025/12/29
  static String _getDateFolder() {
    final now = DateTime.now();
    return '${now.year}/${_padZero(now.month)}/${_padZero(now.day)}';
  }

  static String _padZero(int num) => num.toString().padLeft(2, '0');

  // 根据文件路径自动判断类型并返回对应文件夹名
  static String _getFolderByFileType(String filePath) {
    final mimeType = lookupMimeType(filePath)?.toLowerCase() ?? '';

    if (mimeType.startsWith('image/')) {
      return 'images';
    } else if (mimeType.startsWith('video/')) {
      return 'videos';
    } else if (mimeType.startsWith('audio/') || mimeType == 'application/ogg') {
      // 微信语音通常是 .amr 或 .silk，iOS 是 .caf，Android 可能是 ogg
      return 'voices';
    } else if (mimeType == 'application/pdf') {
      return 'files/pdf';
    } else if (mimeType.startsWith('text/')) {
      return 'files/text';
    } else {
      // 其他所有文件都放 files/other
      return 'files/other';
    }
  }

  // 可选：更精确地根据扩展名判断语音（某些老设备 lookupMimeType 返回 null）
  static String _getFolderByExtension(String filePath) {
    final ext = path.extension(filePath).toLowerCase();
    if (['.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.bmp'].contains(ext)) {
      return 'images';
    } else if (['.mp4', '.mov', '.avi', '.mkv', '.webm', '.3gp'].contains(ext)) {
      return 'videos';
    } else if ([
      '.aac', '.mp3', '.wav', '.m4a', '.amr', '.silk', '.ogg', '.caf'
    ].contains(ext)) {
      return 'voices';
    } else if (ext == '.pdf') {
      return 'files/pdf';
    } else {
      return 'files/other';
    }
  }

  /// 上传多张/多个媒体文件（自动分类）
  static Future<List<String>> uploadMedias({
    required BuildContext context,
    required List<String> localPaths,
    void Function(int current, int total)? onProgress,
    void Function(String signedUrl, String fileType)? onSingleUploaded, // 新增 fileType 回调
  }) async {
    if (localPaths.isEmpty) return [];

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('正在上传文件，请稍等...')),
    );

    List<String> uploadedUrls = [];

    for (int i = 0; i < localPaths.length; i++) {
      final String localPath = localPaths[i];
      final file = File(localPath);

      if (!await file.exists()) {
        print("文件不存在: $localPath");
        continue;
      }

      // 1. 智能判断文件类型和目标文件夹
      String folder = _getFolderByFileType(localPath);
      if (folder == 'files/other') {
        folder = _getFolderByExtension(localPath); // 兜底方案
      }

      // 2. 生成 objectKey
      final String fileName = path.basename(localPath);
      final String dateFolder = _getDateFolder();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String objectKey = '$folder/$dateFolder/${timestamp}_$fileName';

      // 3. 进度回调
      onProgress?.call(i + 1, localPaths.length);

      try {
        // 上传文件
        await OssUploader().uploadFile(
          file: file,
          objectKey: objectKey,
          onProgress: (sent, total) {
            final progress = (sent / total * 100).toStringAsFixed(1);
            print('[$folder] 上传进度: $progress%');
          },
        );

        // 获取长效签名 URL（聊天记录建议 7~30 天）
        final String signedUrl = await OssUploader().getSignedUrl(
          objectKey: objectKey,
          expires: const Duration(days: 7),
        );

        uploadedUrls.add(signedUrl);
        print('上传成功 [$folder]: $signedUrl');

        // 实时回调（推荐！可以立刻发送消息）
        onSingleUploaded?.call(signedUrl, folder.split('/').first); // 如 "images", "videos", "voices"

      } catch (e) {
        print('上传失败 $localPath: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败：${path.basename(localPath)}')),
        );
      }
    }

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    return uploadedUrls;
  }

  /// 上传单张图片（简化调用）
  static Future<String?> uploadSingleImage({
    required BuildContext context,
    required String localPath,
    void Function(String signedUrl)? onUploaded,
  }) async {
    final urls = await uploadMedias(
      context: context,
      localPaths: [localPath],
      onSingleUploaded: (url, type) {
        if (type == 'images') onUploaded?.call(url);
      },
    );
    return urls.isEmpty ? null : urls.first;
  }

  /// 上传单条语音（常用于语音消息）
  static Future<String?> uploadSingleVoice({
    required BuildContext context,
    required String localPath,
    void Function(String signedUrl)? onUploaded,
  }) async {
    final urls = await uploadMedias(
      context: context,
      localPaths: [localPath],
      onSingleUploaded: (url, type) {
        if (type == 'voices') onUploaded?.call(url);
      },
    );
    return urls.isEmpty ? null : urls.first;
  }

  /// 上传单个视频
  static Future<String?> uploadSingleVideo({
    required BuildContext context,
    required String localPath,
    void Function(String signedUrl)? onUploaded,
  }) async {
    final urls = await uploadMedias(
      context: context,
      localPaths: [localPath],
      onSingleUploaded: (url, type) {
        if (type == 'videos') onUploaded?.call(url);
      },
    );
    return urls.isEmpty ? null : urls.first;
  }
}