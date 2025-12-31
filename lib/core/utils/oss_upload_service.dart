import 'dart:typed_data';
import 'dart:io';

import 'package:dart_aliyun_oss/dart_aliyun_oss.dart';
import 'package:dio/dio.dart';
import 'package:education/core/cache/oss_sts.dart';

class OssUploader {
  OssUploader._privateConstructor();

  static final OssUploader _instance = OssUploader._privateConstructor();

  factory OssUploader() => _instance;

  OSSClient? _client;
  bool _isInitializing = false;  // 防止并发初始化

  final String endpoint = 'oss-accelerate.aliyuncs.com';
  final String bucketName = 'bbt-bucket2025';
  final String region = 'cn-hongkong';

  /// 确保客户端已初始化（只初始化一次）
  Future<void> _ensureInitialized() async {
    if (_client != null || _isInitializing) return;

    _isInitializing = true;
    try {
      final credentials = await OssStsCache.getValidStsCredentials();

      final config = OSSConfig.static(
        accessKeyId: credentials.accessKeyId,
        accessKeySecret: credentials.accessKeySecret,
        securityToken: credentials.securityToken,
        bucketName: bucketName,
        endpoint: endpoint,
        region: region,
      );

      _client = OSSClient.init(config);
      print('OSSClient 初始化成功');
    } catch (e) {
      print('OSSClient 初始化失败: $e');
      rethrow;
    } finally {
      _isInitializing = false;
    }
  }

  /// 通用上传方法（带自动重试）
  Future<void> _uploadWithRetry({
    required Future<void> Function() uploadAction,
    required String objectKey,
  }) async {
    int retryCount = 0;
    const maxRetries = 3;

    while (retryCount < maxRetries) {
      try {
        await _ensureInitialized();
        await uploadAction();
        return; // 成功则退出
      } catch (e, stackTrace) {
        print('上传失败 (第 ${retryCount + 1} 次) objectKey: $objectKey');
        print('错误类型: ${e.runtimeType}');
        print('错误信息: ${e.toString()}');

        // 判断是否是 late 初始化相关的错误（通过消息字符串）
        final errorMsg = e.toString().toLowerCase();
        if (errorMsg.contains('lateinitializationerror') ||
            errorMsg.contains('has already been initialized') ||
            errorMsg.contains('config')) {
          print('检测到 OSSClient 重复初始化错误，强制销毁旧客户端准备重试');
          _client = null; // 销毁旧客户端，下次会重新初始化
        }

        retryCount++;
        if (retryCount >= maxRetries) {
          rethrow; // 最终失败抛出
        }

        // 可选：延迟一点再重试，避免快速失败
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
  }

  Future<void> uploadFile({
    required File file,
    required String objectKey,
    void Function(int sent, int total)? onProgress,
  }) async {
    await _uploadWithRetry(
      uploadAction: () async {
        await _client!.putObject(
          file,
          objectKey,
          params: OSSRequestParams(
            onSendProgress: onProgress != null
                ? (count, total) => onProgress(count, total)
                : null,
          ),
        );
      },
      objectKey: objectKey,
    );
  }

  Future<void> multipartUpload({
    required File file,
    required String objectKey,
    void Function(int sent, int total)? onProgress,
  }) async {
    await _uploadWithRetry(
      uploadAction: () async {
        await _client!.multipartUpload(
          file,
          objectKey,
          params: OSSRequestParams(
            onSendProgress: onProgress != null
                ? (count, total) => onProgress(count, total)
                : null,
          ),
        );
      },
      objectKey: objectKey,
    );
  }

  Future<void> uploadBytes({
    required Uint8List bytes,
    required String objectKey,
    void Function(int sent, int total)? onProgress,
  }) async {
    await _uploadWithRetry(
      uploadAction: () async {
        await _client!.putObjectFromBytes(
          bytes,
          objectKey,
          params: OSSRequestParams(
            onSendProgress: onProgress != null
                ? (count, total) => onProgress(count, total)
                : null,
          ),
        );
      },
      objectKey: objectKey,
    );
  }

  Future<String> getSignedUrl({
    required String objectKey,
    String method = 'GET',
    Duration expires = const Duration(days: 7),
    bool isV1Signature = false,
  }) async {
    await _ensureInitialized();
    return await _client!.signedUrl(
      objectKey,
      method: method,
      expires: expires.inSeconds,
      isV1Signature: isV1Signature,
    );
  }
}