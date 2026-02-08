/// 评论模型（与 gateway CommentInfo 一致）
class CommentInfo {
  final int commentId;
  final int postId;
  final int userId;
  final int parentCommentId;
  final String content;
  final int createdAt;

  CommentInfo({
    required this.commentId,
    required this.postId,
    required this.userId,
    this.parentCommentId = 0,
    required this.content,
    this.createdAt = 0,
  });

  factory CommentInfo.fromMap(Map<String, dynamic> m) {
    return CommentInfo(
      commentId: (m['comment_id'] as num?)?.toInt() ?? 0,
      postId: (m['post_id'] as num?)?.toInt() ?? 0,
      userId: (m['user_id'] as num?)?.toInt() ?? 0,
      parentCommentId: (m['parent_comment_id'] as num?)?.toInt() ?? 0,
      content: m['content'] as String? ?? '',
      createdAt: (m['created_at'] as num?)?.toInt() ?? 0,
    );
  }
}
