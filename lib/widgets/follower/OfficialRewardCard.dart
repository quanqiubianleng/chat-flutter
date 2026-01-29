// 文件：widgets/official_reward_card.dart
import 'package:flutter/material.dart';

class OfficialRewardCard extends StatelessWidget {
  final String timeAgo;
  final String amount;
  final String timestamp;
  final String url;

  const OfficialRewardCard({
    super.key,
    required this.timeAgo,
    required this.amount,
    required this.timestamp,
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(2, 0, 16, 10),
      decoration: const BoxDecoration(
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
          // 标题栏
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "BBT 官方 Support | 讨论总群",
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              Text(
                timeAgo,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 下面保持不变
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              image: const DecorationImage(
                image: NetworkImage(
                  "https://bbt-bucket-public.oss-cn-hongkong.aliyuncs.com/avatar_s/1.png",
                ),
                fit: BoxFit.cover,
              ),
            ),
            child: Column(
              children: [
                Image.network(
                  "https://bbt-bucket-public.oss-cn-hongkong.aliyuncs.com/avatar_s/1.png",
                  width: 120,
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.96),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: Color(0xFFFF5C8A), width: 2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.card_giftcard,
                        color: Color(0xFFFF5C8A),
                        size: 22,
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        "抽奖",
                        style: TextStyle(
                          color: Color(0xFFFF5C8A),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "抽奖 $amount",
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      timestamp,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () => print("打开：$url"),
            child: Text(
              url,
              style: const TextStyle(
                color: Colors.blue,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
