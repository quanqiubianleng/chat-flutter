// ===================== 语音气泡 ======================
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../core/websocket/ws_extra.dart';
import '../../pb/protos/chat.pb.dart';

class VoiceBubble extends StatefulWidget {
  final Event message; // 消息体
  final bool isMe;

  const VoiceBubble({Key? key, required this.message, required this.isMe})
      : super(key: key);

  @override
  State<VoiceBubble> createState() => _VoiceBubbleState();
}

class _VoiceBubbleState extends State<VoiceBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final AudioPlayer _player = AudioPlayer();
  bool isPlaying = false;
  int duration = 1; // 默认值，防止太短
  int size = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _parseExtra();  // 关键：解析 extra
  }

  void _parseExtra() {
    if (widget.message.extra.isEmpty) {
      // 旧消息兼容：从 content 提取时长（如 "[语音]8"）
      final match = RegExp(r'\d+').firstMatch(widget.message.content);
      if (match != null) {
        duration = int.tryParse(match.group(0)!) ?? 10;
      }
      return;
    }

    try {
      final extraJsonString = utf8.decode(widget.message.extra);
      final extraMap = jsonDecode(extraJsonString) as Map<String, dynamic>;
      final voiceExtra = VoiceExtra.fromJson(extraMap);

      print('解析语音 extra duration：$duration');
      setState(() {
        duration = voiceExtra.duration;
        size = voiceExtra.size ?? 0;
      });
    } catch (e) {
      print('解析语音 extra 失败：$e');
      duration = 10; // 兜底
    }
  }

  void _togglePlay() async {
    if (isPlaying) {
      await _player.stop();
      _controller.reverse();
    } else {
      String url = widget.message.mediaUrl;
      if (widget.message.extra.isNotEmpty) {
        try {
          final extraMap = jsonDecode(utf8.decode(widget.message.extra)) as Map<String, dynamic>;
          final voiceExtra = VoiceExtra.fromJson(extraMap);
          if (voiceExtra.url.isNotEmpty) url = voiceExtra.url;
        } catch (_) {}
      }

      await _player.play(UrlSource(url));
      _controller.forward();

      _player.onPlayerComplete.listen((_) {
        if (mounted) {
          setState(() => isPlaying = false);
          _controller.reverse();
        }
      });
    }
    setState(() => isPlaying = !isPlaying);
  }

  @override
  void dispose() {
    _controller.dispose();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _togglePlay,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: widget.isMe ? const Color(0xFF2483FF) : const Color(0xFF1E252F),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedIcon(
              icon: AnimatedIcons.play_pause,
              progress: _controller,
              color: widget.isMe ? Colors.white : Colors.cyanAccent,
              size: 28,
            ),
            const SizedBox(width: 10),
            Text(
              '${duration}\"',
              style: TextStyle(
                color: widget.isMe ? Colors.white70 : Colors.grey,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}