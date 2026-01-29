// ======================== 红包气泡 ========================
import 'dart:convert';

import 'package:education/pb/protos/chat.pb.dart';
import 'package:flutter/material.dart';

import '../../core/utils/timer.dart';
import '../../core/websocket/ws_extra.dart';

class RedPacketBubble extends StatefulWidget {
  final Event message;

  const RedPacketBubble({Key? key, required this.message}) : super(key: key);

  @override
  State<RedPacketBubble> createState() => _RedPacketBubbleState();
}

class _RedPacketBubbleState extends State<RedPacketBubble> {
  late String wish;
  late int status;
  late int expiredAt;

  @override
  void initState() {
    super.initState();
    _parseExtra(); // 在 initState 中解析 extra
  }

  void _parseExtra() {
    // 默认值
    wish = "幸运红包";
    status = 0;
    expiredAt = 0;

    if (widget.message.extra.isEmpty) {
      return;
    }

    try {
      final extraJsonString = utf8.decode(widget.message.extra);
      final extraMap = jsonDecode(extraJsonString) as Map<String, dynamic>;

      // 假设你有 RedPacketExtra 这个类（由 protobuf 生成或手动定义）
      final redPacketExtra = RedPacketExtra.fromJson(extraMap);

      setState(() {
        wish = redPacketExtra.wish!;
        status = redPacketExtra.status;
        expiredAt = redPacketExtra.expiredAt;
      });

      print('解析红包 extra 成功：wish=$wish');
    } catch (e) {
      print('解析红包 extra 失败：$e');
    }
  }

  @override
  Widget build(BuildContext context) {

    return GestureDetector(
      onTap: () {
        // TODO: 真实领取红包逻辑
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("领取红包成功 +100U 🎉")),
        );
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5E5E), Color(0xFFFFA800)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8), // 圆角半径，建议 8~12，根据设计调整
                child: Image.network(
                  "https://bbt-bucket-public.oss-cn-hongkong.aliyuncs.com/avatar_s/1.png",
                  width: 50,
                  height: 50,
                  fit: BoxFit.cover, // 重要：确保图片填满容器并被裁剪
                  errorBuilder: (_, __, ___) => Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.card_giftcard, color: Colors.white, size: 30),
                  ),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      wish,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _getHintText(),
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  String _getHintText() {
    if (status == 1) {
      return "已领取";
    } else if (status == 2) {
      return "24小时未领取，已退回";
    }
    if(expiredAt < TimeUtils.currentTimestamp){
      return "24小时未领取，已退回";
    }
    return "待领取";
  }
}