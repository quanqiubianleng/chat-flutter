import 'package:education/modules/dynamic/models/comment_info.dart';
import 'package:education/pages/market/dynamic_detail_page.dart';
import 'package:education/services/dynamic_service.dart';
import 'package:flutter/material.dart';

/// 用户评论列表 Tab（某用户发表的所有评论）
class UserCommentsTab extends StatefulWidget {
  final int userId;
  final Map<String, dynamic>? userInfo;

  const UserCommentsTab({super.key, required this.userId, this.userInfo});

  @override
  State<UserCommentsTab> createState() => _UserCommentsTabState();
}

class _UserCommentsTabState extends State<UserCommentsTab> {
  final DynamicApi _api = DynamicApi();
  List<CommentInfo> _comments = [];
  int _cursor = 0;
  bool _hasMore = true;
  bool _loading = true;
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
      _comments = [];
      _cursor = 0;
      _hasMore = true;
    });
    try {
      final resp = await _api.getUserComments(userId: widget.userId, cursor: 0, limit: 20);
      final raw = resp['list'] as List<dynamic>? ?? [];
      final list = raw.map((e) => CommentInfo.fromMap(e as Map<String, dynamic>)).toList();
      final next = (resp['next_cursor'] as num?)?.toInt() ?? 0;
      final hasMore = resp['has_more'] as bool? ?? false;
      if (mounted) {
        setState(() {
          _comments = list;
          _cursor = next;
          _hasMore = hasMore;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('加载失败: $_error', style: TextStyle(color: Colors.red[700])),
            const SizedBox(height: 16),
            TextButton(onPressed: _load, child: const Text('重试')),
          ],
        ),
      );
    }
    if (_comments.isEmpty) {
      return const Center(child: Text('暂无评论'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        itemCount: _comments.length,
        itemBuilder: (_, i) {
          final c = _comments[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DynamicDetailPage(postId: c.postId),
                ),
              ).then((_) => _load()),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.content,
                      style: const TextStyle(fontSize: 15, color: Colors.black87),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.insert_comment, size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 4),
                        Text(
                          '评论于动态 #${c.postId}',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                        const Spacer(),
                        Text(
                          _formatTime(c.createdAt),
                          style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  String _formatTime(int ts) {
    if (ts <= 0) return '';
    final d = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inDays > 0) return '${diff.inDays}天前';
    if (diff.inHours > 0) return '${diff.inHours}小时前';
    if (diff.inMinutes > 0) return '${diff.inMinutes}分钟前';
    return '刚刚';
  }
}
