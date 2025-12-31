// lib/features/chat/components/chat_input_bar.dart
import 'package:education/widgets/chat/simple_media_panel.dart';
import 'package:flutter/material.dart';
import '../../core/utils/chat_media_uploader.dart';
import '../../core/utils/oss_upload_service.dart';
import './emoji_picker_widget.dart';

class ChatInputBar extends StatefulWidget {
  final Function(String) onSendText;
  const ChatInputBar({Key? key, required this.onSendText}) : super(key: key);

  @override
  State<ChatInputBar> createState() => _ChatInputBarState();
}

class _ChatInputBarState extends State<ChatInputBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode(); // 添加焦点节点
  bool showVoice = false;
  bool showEmoji = false;
  bool showMediaPanel = false;

  @override
  void initState() {
    super.initState();
    // 监听输入框焦点变化
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // 当输入框获得焦点时，关闭其他面板
      if (showEmoji || showMediaPanel) {
        setState(() {
          showEmoji = false;
          showMediaPanel = false;
        });
      }
    }
  }

  void _closeAllPanels() {
    // 关闭所有面板并取消焦点
    if (showEmoji || showMediaPanel || _focusNode.hasFocus) {
      setState(() {
        showEmoji = false;
        showMediaPanel = false;
      });
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          decoration: const BoxDecoration(
            color: Color.fromARGB(255, 240, 241, 241),
            border: Border(top: BorderSide(color: Color.fromARGB(255, 214, 214, 214))),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: Icon(showVoice ? Icons.keyboard : Icons.keyboard_voice, size: 30,
                      color: Colors.grey),
                  onPressed: () => setState(() => showVoice = !showVoice),
                ),
                Expanded(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: 50, // 输入框最大高度，可调
                    ),
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: null, // 允许多行，但受 ConstrainedBox 限制
                      decoration: InputDecoration(
                        hintText: "说点什么...",
                        hintStyle: const TextStyle(color: Colors.grey), // 提示文字改成灰色
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 5, vertical: 0),
                      ),
                      style: const TextStyle(color: Color.fromARGB(255, 139, 139, 139)),
                      onSubmitted: (_) => _send(),
                      onTap: () {
                        // 确保在点击时关闭其他面板
                        if (showEmoji || showMediaPanel) {
                          setState(() {
                            showEmoji = false;
                            showMediaPanel = false;
                          });
                        }
                      },
                    ),
                  ),
                ),

                IconButton(
                  icon: Icon(
                    showEmoji ? Icons.keyboard : Icons.insert_emoticon,  size: 30,
                    color: showEmoji ? const Color(0xFF2483FF) : Colors.grey,
                  ),
                  onPressed: () {
                    setState(() => showEmoji = !showEmoji);
                    if (showEmoji) {
                      showMediaPanel = false;     // 关闭更多面板
                      FocusScope.of(context).unfocus();
                    }
                  },
                ),
                IconButton(
                  icon: Icon(
                    Icons.add_circle_outline,  size: 30,
                    color: Colors.grey,
                  ),
                  onPressed: () {
                    setState(() {
                      final mediaVisible = showMediaPanel ?? false;
                      if (!showMediaPanel) {
                        // 打开媒体面板
                        showMediaPanel = true;
                        showEmoji = false;        // 关闭表情
                        FocusScope.of(context).unfocus(); // 收起键盘
                      } else {
                        // 关闭媒体面板
                        showMediaPanel = false;
                      }
                    });
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Color(0xFF2483FF),  size: 30,),
                  onPressed: _send,
                ),
              ],
            ),
          ),
        ),
        if (showEmoji)
          EmojiPickerWidget(
            onEmojiSelected: (emoji) {
              _controller.text += emoji;
              _controller.selection = TextSelection.fromPosition(
                  TextPosition(offset: _controller.text.length));
            },
            isVisible: showEmoji,
          ),
        // 只放这一个组件
        if (showMediaPanel)
          SimpleMediaPanel(
            visible: showMediaPanel,
            onAlbumPicked: (paths) async {
              print("相册选中图片：$paths");
              // 发送图片逻辑
              await ChatMediaUploader.uploadMedias(
                context: context,
                localPaths: paths,
                onProgress: (current, total) {
                  print('整体进度: $current/$total');
                },
                onSingleUploaded: (url, type) {
                  // 每上传成功一张，立刻发送一条图片消息（推荐方式，用户看到实时上传）
                  // widget.onSendText(url, type);
                },
              );

              // 上传完毕关闭面板
              setState(() {
                showMediaPanel = false;
              });
            },
            onPhotoTaken: (path) async {
              print("拍照完成：$path");
              // 发送图片逻辑
              await ChatMediaUploader.uploadSingleImage(
                context: context,
                localPath: path,
                onUploaded: (signedUrl) {
                  if (signedUrl != null) {
                    widget.onSendText('[图片]');
                  }
                },
              );

              setState(() {
                showMediaPanel = false;
              });
            },
            onRedPacket: () {
              print("点击了红包");
              // 打开红包页面或弹窗
            },
          ),
      ],
    );
  }

  void _send() {
    if (_controller.text.trim().isNotEmpty) {
      widget.onSendText(_controller.text.trim());
      _controller.clear();
    }
  }
}