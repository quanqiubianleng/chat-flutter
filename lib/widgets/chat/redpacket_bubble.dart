// ======================== 红包气泡 ========================
import 'package:education/pb/protos/chat.pb.dart';
import 'package:flutter/material.dart';

class RedPacketBubble extends StatelessWidget {
  final Event message;

  const RedPacketBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("领取红包成功 +100U 🎉")));
      },
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 240),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF5E5E), Color(0xFFFFA800)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: const [
              BoxShadow(
                  color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.network(
                "https://i.postimg.cc/19nwP5Jj/271c104d68299e34c375ac3fe7d7fc2d524329900.webp?dl=1",
                width: 50,
                height: 50,
                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "DeSwap专属红包",
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      message.content.split('\n').first,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
