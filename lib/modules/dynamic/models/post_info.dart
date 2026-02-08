/// 动态帖子模型（与 gateway PostInfo 一致）
class PostInfo {
  /// 从 Map 中解析整型（兼容 int/double/String）
  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is double) return v.toInt();
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
  final int postId;
  final int userId;
  final String? userNickname; // 发布者昵称，服务端填充
  final String content;
  final String type;
  final String visibility;
  final int parentPostId;
  final String onChainData;
  final int likesCount;
  final int commentsCount;
  final double rewardsAmount;
  final int starsCount;
  final int createdAt;
  final int updatedAt;
  final List<MediaInfo> mediaList;
  final bool isLiked;
  final bool isStarred;

  PostInfo({
    required this.postId,
    required this.userId,
    this.userNickname,
    required this.content,
    this.type = 'post',
    this.visibility = 'public',
    this.parentPostId = 0,
    this.onChainData = '',
    this.likesCount = 0,
    this.commentsCount = 0,
    this.rewardsAmount = 0,
    this.starsCount = 0,
    this.createdAt = 0,
    this.updatedAt = 0,
    this.mediaList = const [],
    this.isLiked = false,
    this.isStarred = false,
  });

  factory PostInfo.fromMap(Map<String, dynamic> m) {
    final raw = m['media_list'] as List<dynamic>? ?? [];
    final list = raw.map((e) => MediaInfo.fromMap(e as Map<String, dynamic>)).toList();
    return PostInfo(
      postId: (m['post_id'] as num?)?.toInt() ?? 0,
      userId: (m['user_id'] as num?)?.toInt() ?? 0,
      userNickname: m['user_nickname'] as String?,
      content: m['content'] as String? ?? '',
      type: m['type'] as String? ?? 'post',
      visibility: m['visibility'] as String? ?? 'public',
      parentPostId: (m['parent_post_id'] as num?)?.toInt() ?? 0,
      onChainData: m['on_chain_data'] as String? ?? '',
      likesCount: _parseInt(m['likes_count'] ?? m['likesCount']),
      commentsCount: _parseInt(m['comments_count'] ?? m['commentsCount']),
      rewardsAmount: (m['rewards_amount'] as num?)?.toDouble() ?? 0,
      starsCount: (m['stars_count'] as num?)?.toInt() ?? 0,
      createdAt: (m['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (m['updated_at'] as num?)?.toInt() ?? 0,
      mediaList: list,
      isLiked: m['is_liked'] as bool? ?? false,
      isStarred: m['is_starred'] as bool? ?? false,
    );
  }
}

class MediaInfo {
  final int mediaId;
  final String mediaType;
  final String url;
  final String thumbnailUrl;

  MediaInfo({
    this.mediaId = 0,
    required this.mediaType,
    required this.url,
    this.thumbnailUrl = '',
  });

  factory MediaInfo.fromMap(Map<String, dynamic> m) {
    return MediaInfo(
      mediaId: (m['media_id'] as num?)?.toInt() ?? 0,
      mediaType: m['media_type'] as String? ?? 'image',
      url: m['url'] as String? ?? '',
      thumbnailUrl: m['thumbnail_url'] as String? ?? m['url'] as String? ?? '',
    );
  }
}
