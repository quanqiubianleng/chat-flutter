import 'dart:io';

import 'package:education/widgets/chat/simple_media_panel.dart';
import 'package:flutter/material.dart';
import '../../core/utils/chat_media_uploader.dart';
import '../../core/websocket/ws_extra.dart';
import './emoji_picker_widget.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String message, String type, String mediaUrl, {Map<String, dynamic>? extra}) onSendMessage;

  const ChatInputBar({
    Key? key,
    required this.onSendMessage,
  }) : super(key: key);

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  bool showVoice = false;
  bool showEmoji = false;
  bool showMediaPanel = false;

  // 新增：录音相关
  bool _isRecording = false;           // 是否正在录音
  bool _isCancelling = false;          // 是否上滑取消
  double _dragDistance = 0;            // 上滑距离（用于判断取消）
  OverlayEntry? _voiceRecordOverlay;   // 录音提示弹窗
  late final AudioRecorder _audioRecorder;

  OverlayEntry? _progressOverlayEntry;

  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChange);
    _audioRecorder = AudioRecorder();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _audioPlayer.dispose();
    _focusNode.dispose();
    _controller.dispose();
    // 语音相关
    _audioRecorder.dispose();
    _hideVoiceRecordOverlay();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      setState(() {
        showEmoji = false;
        showMediaPanel = false;
      });
    }
  }

  void _toggleMediaPanel() {
    setState(() {
      showMediaPanel = !showMediaPanel;
      if (showMediaPanel) {
        showEmoji = false;
        _focusNode.unfocus();
      }
    });
  }

  void _toggleEmoji() {
    setState(() {
      showEmoji = !showEmoji;
      if (showEmoji) {
        showMediaPanel = false;
        _focusNode.unfocus();
      }
    });
  }

  void _sendText() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) {
      widget.onSendMessage(text, 'text', "");
      _controller.clear();
    }
  }

  /// 统一发送媒体消息（图片、视频、语音等）
  void _sendMedia(String signedUrl, String type, {Map<String, dynamic>? extra,}) {
    // type 来自 ChatMediaUploader: images → image, videos → video, voices → voice
    String messageType;
    String prefix = '';

    switch (type) {
      case 'images':
        messageType = 'image';
        prefix = '[图片]';
        break;
      case 'videos':
        messageType = 'video';
        prefix = '[视频]';
        break;
      case 'voices':
        messageType = 'voice';
        prefix = '[语音]';
        break;
      default:
        messageType = 'file';
        prefix = '[文件]';
    }

    widget.onSendMessage('$prefix', messageType, signedUrl, extra: extra,);
  }

  // 展示媒体文件发送中弹窗
  void _showUploadProgressOverlay({required int total}) {
    // 避免重复显示
    _hideUploadProgressOverlay();

    _progressOverlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: Colors.white),
                const SizedBox(height: 12),
                Text(
                  '上传中... 0/$total',
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  '请勿退出聊天',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_progressOverlayEntry!);
  }

  // 更新媒体文件发送中进度
  void _updateUploadProgress(int current, int total) {
    if (_progressOverlayEntry != null) {
      _progressOverlayEntry!.markNeedsBuild(); // 触发重建
      // 我们用一个全局变量或闭包来保存当前进度
      // 下面用一个简单的方式：重建整个 overlay（轻量无压力）
      _hideUploadProgressOverlay();
      _showUploadProgressOverlayWithCount(current, total);
    }
  }

  void _showUploadProgressOverlayWithCount(int current, int total) {
    _hideUploadProgressOverlay(); // 先移除旧的
    _progressOverlayEntry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.transparent,
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (current < total)
                  const CircularProgressIndicator(color: Colors.white)
                else
                  const Icon(Icons.check_circle, color: Colors.greenAccent, size: 36),

                const SizedBox(height: 12),
                Text(
                  current < total ? '上传中... $current/$total' : '上传完成！',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                if (current < total)
                  const Text(
                    '请勿退出聊天',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_progressOverlayEntry!);

    // 如果全部完成，延时自动关闭
    if (current == total) {
      Future.delayed(const Duration(milliseconds: 800), () {
        _hideUploadProgressOverlay();
      });
    }
  }

  // 关闭媒体文件发送中弹窗
  void _hideUploadProgressOverlay() {
    print("关闭弹窗");
    _progressOverlayEntry?.remove();
    _progressOverlayEntry = null;
  }

  // 正在录音
  void _showVoiceRecordOverlay() {
    _hideVoiceRecordOverlay(); // 先确保没有旧的

    _voiceRecordOverlay = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.black87,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isCancelling ? Icons.delete_forever : Icons.mic,
                  color: _isCancelling ? Colors.red : Colors.white,
                  size: 60,
                ),
                const SizedBox(height: 16),
                Text(
                  _isCancelling ? '松开取消' : '松开发送',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
                if (!_isCancelling)
                  const Text(
                    '手指上滑可取消',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_voiceRecordOverlay!);
  }

  // 关闭正在录音
  void _hideVoiceRecordOverlay() {
    _voiceRecordOverlay?.remove();
    _voiceRecordOverlay = null;
  }

  @override
  Widget build(BuildContext context) {
    final bool hasText = _controller.text.trim().isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF0F1F1),
            border: Border(top: BorderSide(color: Color(0xFFD6D6D6))),
          ),
          child: SafeArea(
            top: false,
            child: Row(
              children: [
                // 语音按钮（暂未实现录音）
                IconButton(
                  icon: Icon(showVoice ? Icons.keyboard : Icons.mic, size: 28, color: Colors.grey[700]),
                  onPressed: () => setState(() {
                    setState(() {
                      showVoice = !showVoice;
                      if (showVoice) {
                        showEmoji = false;
                        showMediaPanel = false;
                        _focusNode.unfocus();
                      }
                    });
                  }),
                ),

                // 输入框
                Expanded(
                  child: showVoice
                      ? GestureDetector(
                          onLongPressStart: (_) async {
                            if (await _audioRecorder.hasPermission()) {
                              // 开始录音（保存到临时文件）
                              await _audioRecorder.start(
                                const RecordConfig(
                                  encoder: AudioEncoder.aacLc,
                                  sampleRate: 44100,
                                ),
                                path: '${Directory.systemTemp.path}/${DateTime.now().millisecondsSinceEpoch}.m4a',
                              );

                              setState(() {
                                _isRecording = true;
                                _isCancelling = false;
                              });
                              _showVoiceRecordOverlay();
                            }
                          },
                          onLongPressMoveUpdate: (details) {
                            // 上滑超过 100px 视为取消
                            setState(() {
                              _dragDistance = details.localPosition.dy;
                              _isCancelling = _dragDistance < -100;
                            });
                            _showVoiceRecordOverlay(); // 刷新提示文字
                          },
                          onLongPressEnd: (_) async {
                            if (!_isRecording) return;

                            final path = await _audioRecorder.stop();

                            _hideVoiceRecordOverlay();
                            setState(() {
                              _isRecording = false;
                            });

                            if (_isCancelling || path == null) {
                              // 取消发送
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('录音已取消')),
                              );
                              return;
                            }

                            // ========== 新增：读取语音时长 ==========
                            int durationSeconds = 0;
                            int? fileSize;

                            try {
                              final file = File(path);
                              fileSize = await file.length(); // 获取文件大小（字节）

                              // 使用 just_audio 读取时长
                              await _audioPlayer.setFilePath(path);
                              durationSeconds = _audioPlayer.duration?.inSeconds ?? 0;
                              await _audioPlayer.pause(); // 暂停，释放资源
                            } catch (e) {
                              print('读取语音时长失败: $e');
                              durationSeconds = 0; // 失败也继续发送，不阻塞
                            }

                            // 上传语音文件
                            // 假设 ChatMediaUploader 支持上传语音（路径为 path）
                            // 这里直接调用你现有的上传逻辑（你可以封装一个 uploadVoice）
                            final signedUrl = await ChatMediaUploader.uploadSingleVoice(
                              context: context,
                              localPath: path,
                            );

                            if (signedUrl != null) {
                              final voiceExtra = VoiceExtra(
                                url: signedUrl,
                                duration: durationSeconds,
                                size: fileSize,
                              ).toJson();
                              _sendMedia(signedUrl, 'voices', extra: voiceExtra,);
                            }
                          },
                          child: Container(
                            height: 44,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Center(
                              child: Text(
                                '按住说话',
                                style: TextStyle(color: Colors.grey, fontSize: 16),
                              ),
                            ),
                          ),
                        )
                      : ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 100),
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        hintText: "说点什么...",
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      style: const TextStyle(fontSize: 16),
                      onChanged: (_) => setState(() {}), // 实时更新发送按钮状态
                    ),
                  ),
                ),

                // 表情
                IconButton(
                  icon: Icon(
                    showEmoji ? Icons.keyboard : Icons.insert_emoticon,
                    size: 28,
                    color: showEmoji ? const Color(0xFF2483FF) : Colors.grey[700],
                  ),
                  onPressed: _toggleEmoji,
                ),

                // 更多（媒体面板）
                IconButton(
                  icon: const Icon(Icons.add_circle_outline, size: 28, color: Colors.grey),
                  onPressed: _toggleMediaPanel,
                ),

                // 发送按钮（有文字时高亮）
                IconButton(
                  icon: Icon(Icons.send,
                      size: 28,
                      color: hasText ? const Color(0xFF2483FF) : Colors.grey[400]),
                  onPressed: hasText ? _sendText : null,
                ),
              ],
            ),
          ),
        ),

        // 表情面板
        if (showEmoji)
          EmojiPickerWidget(
            isVisible: showEmoji,
            onEmojiSelected: (emoji) {
              _controller.text += emoji;
              _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length));
              setState(() {});
            },
          ),

        // 媒体选择面板
        if (showMediaPanel)
          SimpleMediaPanel(
            visible: showMediaPanel,
            onAlbumPicked: (paths) async {
              if (paths.isEmpty) {
                setState(() => showMediaPanel = false);
                return;
              }

              // 显示上传中提示（初始 0/总数量）
              _showUploadProgressOverlay(total: paths.length);

              int uploadedCount = 0;

              // 使用统一的 uploadMedias，支持多类型文件
              await ChatMediaUploader.uploadMedias(
                context: context,
                localPaths: paths,
                onProgress: (current, total) {
                  print('上传进度: $current/$total');
                },
                onSingleUploaded: (url, folderType) {
                  // 实时发送每一条消息（最佳体验！）
                  _sendMedia(url, folderType);

                  // 更新进度
                  uploadedCount++;
                  _updateUploadProgress(uploadedCount, paths.length);

                  // 显示当前进度
                  _showUploadProgressOverlayWithCount(uploadedCount, paths.length);
                },
              );

              // 可选：延时 800ms 让用户看到“完成”提示
              await Future.delayed(const Duration(milliseconds: 800));

              // 真正关闭弹窗
              _hideUploadProgressOverlay();

              // 全部上传完关闭面板
              setState(() => showMediaPanel = false);
            },
            onPhotoTaken: (path) async {
              if (path.isEmpty) return;

              // 显示上传中（1张）
              _showUploadProgressOverlay(total: 1);

              final url = await ChatMediaUploader.uploadSingleImage(
                context: context,
                localPath: path,
                onUploaded: (signedUrl) {
                  if (signedUrl != null) {
                    _sendMedia(signedUrl, 'images');
                    // 上传完成，更新为 1/1
                    _showUploadProgressOverlayWithCount(1, 1);
                  }
                },
              );
              // 拍照只有一张，await 完成后直接关闭
              await Future.delayed(const Duration(milliseconds: 600));
              _hideUploadProgressOverlay();

              setState(() => showMediaPanel = false);
            },
            onRedPacket: () {
              print("点击红包");
              // TODO: 打开红包界面
            },
          ),
      ],
    );
  }
}