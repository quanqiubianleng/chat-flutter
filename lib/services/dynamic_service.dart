import 'package:education/services/api_service.dart';

/// 动态相关 API（与 gateway 后端一致）
class DynamicApi {
  final ApiClient _client = ApiClient();

  /// 发布动态
  /// type: social | onchain | forward | other（数据库 ENUM）
  /// visibility: public | community | private
  Future<Map<String, dynamic>> createPost({
    required String content,
    required List<Map<String, dynamic>> mediaList,
    String type = 'social',
    String visibility = 'public',
    int parentPostId = 0,
    String onChainData = '',
  }) async {
    final data = <String, dynamic>{
      'content': content,
      'type': type,
      'visibility': visibility,
      'parent_post_id': parentPostId,
      'on_chain_data': onChainData,
      'media_list': mediaList,
    };
    final resp = await _client.post('/v1/dynamic/createPost', data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取信息流（关注/广场）
  Future<Map<String, dynamic>> getFeed({
    String visibility = 'public',
    int cursor = 0,
    int limit = 20,
  }) async {
    final resp = await _client.post('/v1/dynamic/getFeed', data: {
      'visibility': visibility,
      'cursor': cursor,
      'limit': limit,
    });
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取动态详情
  Future<Map<String, dynamic>> getPostDetail({required int postId}) async {
    final resp = await _client.post('/v1/dynamic/getPostDetail', data: {'post_id': postId});
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取用户动态列表
  Future<Map<String, dynamic>> getUserPosts({
    required int userId,
    int cursor = 0,
    int limit = 20,
  }) async {
    final resp = await _client.post('/v1/dynamic/getUserPosts', data: {
      'user_id': userId,
      'cursor': cursor,
      'limit': limit,
    });
    return ApiClient.getDataOrThrow(resp);
  }

  /// 点赞
  Future<Map<String, dynamic>> likePost({required int postId, double rewardAmount = 0}) async {
    final resp = await _client.post('/v1/dynamic/likePost', data: {
      'post_id': postId,
      'reward_amount': rewardAmount,
    });
    return ApiClient.getDataOrThrow(resp);
  }

  /// 取消点赞
  Future<Map<String, dynamic>> unlikePost({required int postId}) async {
    final resp = await _client.post('/v1/dynamic/unlikePost', data: {'post_id': postId});
    return ApiClient.getDataOrThrow(resp);
  }

  /// 收藏
  Future<Map<String, dynamic>> starPost({required int postId}) async {
    final resp = await _client.post('/v1/dynamic/starPost', data: {'post_id': postId});
    return ApiClient.getDataOrThrow(resp);
  }

  /// 取消收藏
  Future<Map<String, dynamic>> unstarPost({required int postId}) async {
    final resp = await _client.post('/v1/dynamic/unstarPost', data: {'post_id': postId});
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取我的收藏列表
  Future<Map<String, dynamic>> getStarredPosts({
    int cursor = 0,
    int limit = 20,
  }) async {
    final resp = await _client.post('/v1/dynamic/getStarredPosts', data: {
      'cursor': cursor,
      'limit': limit,
    });
    return ApiClient.getDataOrThrow(resp);
  }

  /// 评论
  Future<Map<String, dynamic>> commentPost({
    required int postId,
    int parentCommentId = 0,
    required String content,
  }) async {
    final resp = await _client.post('/v1/dynamic/commentPost', data: {
      'post_id': postId,
      'parent_comment_id': parentCommentId,
      'content': content,
    });
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取评论列表
  Future<Map<String, dynamic>> getComments({
    required int postId,
    int cursor = 0,
    int limit = 20,
  }) async {
    final resp = await _client.post('/v1/dynamic/getComments', data: {
      'post_id': postId,
      'cursor': cursor,
      'limit': limit,
    });
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取用户评论列表（某用户发表的所有评论）
  Future<Map<String, dynamic>> getUserComments({
    required int userId,
    int cursor = 0,
    int limit = 20,
  }) async {
    final resp = await _client.post('/v1/dynamic/getUserComments', data: {
      'user_id': userId,
      'cursor': cursor,
      'limit': limit,
    });
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取用户点赞的动态列表
  Future<Map<String, dynamic>> getUserLikedPosts({
    required int userId,
    int cursor = 0,
    int limit = 20,
  }) async {
    final resp = await _client.post('/v1/dynamic/getUserLikedPosts', data: {
      'user_id': userId,
      'cursor': cursor,
      'limit': limit,
    });
    return ApiClient.getDataOrThrow(resp);
  }

  /// 转发动态（createPost with type=forward, parent_post_id）
  Future<Map<String, dynamic>> forwardPost({
    required int parentPostId,
    String content = '',
    List<Map<String, dynamic>> mediaList = const [],
  }) async {
    return createPost(
      content: content,
      mediaList: mediaList,
      type: 'forward',
      parentPostId: parentPostId,
    );
  }

  /// 更新动态（编辑、私密、置顶等）
  Future<Map<String, dynamic>> updatePost({
    required int postId,
    String content = '',
    String visibility = '',
    List<Map<String, dynamic>> mediaList = const [],
    bool? isPinned,
  }) async {
    final data = <String, dynamic>{
      'post_id': postId,
      if (content.isNotEmpty) 'content': content,
      if (visibility.isNotEmpty) 'visibility': visibility,
      if (mediaList.isNotEmpty) 'media_list': mediaList,
      if (isPinned != null) 'is_pinned': isPinned,
    };
    final resp = await _client.post('/v1/dynamic/updatePost', data: data);
    return ApiClient.getDataOrThrow(resp);
  }

  /// 删除动态
  Future<Map<String, dynamic>> deletePost({required int postId}) async {
    final resp = await _client.post('/v1/dynamic/deletePost', data: {'post_id': postId});
    return ApiClient.getDataOrThrow(resp);
  }

  /// 获取话题列表（若后端未实现可返回空）
  Future<Map<String, dynamic>> getTopicList({String? keyword}) async {
    try {
      final data = <String, dynamic>{};
      if (keyword != null && keyword.isNotEmpty) data['keyword'] = keyword;
      final resp = await _client.post('/v1/dynamic/getTopicList', data: data);
      return ApiClient.getDataOrThrow(resp);
    } catch (_) {
      return {'data': [], 'code': 200, 'msg': 'ok'};
    }
  }
}
