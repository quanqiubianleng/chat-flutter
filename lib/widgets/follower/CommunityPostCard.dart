// 文件：widgets/community_post_card.dart
import 'package:flutter/material.dart';

class CommunityPostCard extends StatelessWidget {
  final String username;
  final String timeAgo;
  final String content;
  final String? imageUrl;        // 可选图片
  final int likeCount;
  final int commentCount;
  final String link;

  const CommunityPostCard({
    super.key,
    required this.username,
    required this.timeAgo,
    required this.content,
    this.imageUrl,
    this.likeCount = 0,
    this.commentCount = 0,
    required this.link,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(2, 0, 0, 8),
      padding: EdgeInsets.only(bottom: 12, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE5E5E5), // 底部边线颜色
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 用户头 + 时间
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(timeAgo, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.more_horiz),
            ],
          ),
          const SizedBox(height: 10),

          // 正文内容
          Text(content, style: const TextStyle(fontSize: 15, height: 1.5)),

          // 图片（如果有）
          if (imageUrl != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 60),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // 互动栏
          Row(
            children: [
              
              const Icon(Icons.favorite_border, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text("$likeCount k", style: const TextStyle(color: Colors.grey)),
              const Spacer(),
              
              const Icon(Icons.favorite_border, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text("$likeCount k", style: const TextStyle(color: Colors.grey)),
              const Spacer(),

              const Icon(Icons.favorite_border, size: 18, color: Colors.grey),
              const SizedBox(width: 4),
              Text("$likeCount k", style: const TextStyle(color: Colors.grey)),
              const Spacer(),

              const Icon(Icons.comment_outlined, size: 18, color: Colors.grey),
            ],
          ),

          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => print("打开链接：$link"),
            child: Text(link, style: const TextStyle(color: Colors.blue, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}