// ======================== 邀请链接气泡 ========================
import 'package:education/pb/protos/chat.pb.dart';
import 'package:flutter/material.dart';

class InviteLinkBubble extends StatelessWidget {
  final Event message;

  const InviteLinkBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.7;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2330),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF00C853), width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(Icons.card_giftcard, color: Color(0xFF00C853)),
                  SizedBox(width: 8),
                  Text(
                    "邀请链接领取：",
                    style: TextStyle(color: Color(0xFF00C853), fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SelectableText(
                message.content,
                style: const TextStyle(color: Colors.cyanAccent, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                "速来领取：https://m.debox.pro/airdrop?...",
                style: TextStyle(color: Color(0xFF888888), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

