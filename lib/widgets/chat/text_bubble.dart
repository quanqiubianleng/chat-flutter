// ======================== 文字气泡 ========================
import 'package:education/pb/protos/chat.pb.dart';
import 'package:education/providers/user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TextBubble extends ConsumerWidget {
  final Event message;

  const TextBubble({Key? key, required this.message}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 用 Riverpod 获取当前用户 UID
    final uidAsync = ref.watch(userProvider);

    return uidAsync.when(
      loading: () => const SizedBox.shrink(), // UID 加载中几乎不会发生，可隐藏
      error: (_, __) => const SizedBox.shrink(),
      data: (currentUid) {
        if (currentUid == null) {
          return const Center(child: Text('用户未登录'));
        }

        final isMe = message.fromUser.toInt() == currentUid;
        final maxWidth = MediaQuery.of(context).size.width * 0.7;

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2483FF),
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(4),
                  bottomRight: isMe ? const Radius.circular(4) : const Radius.circular(16),
                ),
              ),
              child: Text(
                message.content,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFFE5E5E5),
                  fontSize: 15,
                ),
                softWrap: true,
              ),
            ),
          ),
        );
      },
    );
  }
}
