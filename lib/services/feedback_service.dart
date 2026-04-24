import 'package:education/services/api_service.dart';

/// 问题反馈、更新日志、用户协议等相关接口
/// 反馈图片由客户端通过 [ChatMediaUploader.uploadMedias] 直传 OSS，得到 URL 后随 submit 提交
class FeedbackService {
  final ApiClient _client = ApiClient();

  /// 提交问题反馈（邮箱、内容、可选图片 URL 列表，图片由客户端直传 OSS 后传入）
  Future<Map<String, dynamic>> submitFeedback({
    required String email,
    required String content,
    List<String>? imageUrls,
  }) async {
    final resp = await _client.post('/v1/feedback/submit', data: {
      'email': email,
      'content': content,
      if (imageUrls != null && imageUrls.isNotEmpty) 'image_urls': imageUrls,
    });
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取更新日志列表
  Future<List<Map<String, dynamic>>> getUpdateLogList() async {
    final resp = await _client.get('/v1/app/updateLogs');
    final data = ApiClient.getDataOrThrow(resp);
    final list = data['list'];
    if (list is List) {
      return list
          .map((e) => e is Map<String, dynamic> ? e : <String, dynamic>{})
          .toList();
    }
    return [];
  }

  /// 获取用户协议内容（若后端返回富文本或 Markdown）
  Future<Map<String, dynamic>> getUserAgreement() async {
    final resp = await _client.get('/v1/app/userAgreement');
    return ApiClient.getDataOrThrow(resp);
  }
}
