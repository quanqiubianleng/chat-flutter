// lib/features/chat/components/emoji_picker_widget.dart
// 基于 emoji_picker_flutter 4.4.0 最新版本（2025 年 12 月）完全兼容写法
// 已修复所有报错：使用 Config 而非 EmojiPickerConfig，selectedIconColor → iconColorSelected

import 'package:flutter/material.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';

class EmojiPickerWidget extends StatelessWidget {
  final Function(String) onEmojiSelected;
  final bool isVisible;
  final VoidCallback? onBackspacePressed;

  const EmojiPickerWidget({
    Key? key,
    required this.onEmojiSelected,
    required this.isVisible,
    this.onBackspacePressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Offstage(
      offstage: !isVisible,
      child: AnimatedSlide(
        offset: isVisible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Container(
          height: 320,
          color: Colors.white,
          child: Column(
            children: [
              // 顶部删除键（使用 SizedBox 避免 padding 问题）
              // SizedBox(
              //   height: 44,
              //   child: Row(
              //     mainAxisAlignment: MainAxisAlignment.end,
              //     children: [
              //       IconButton(
              //         icon: const Icon(Icons.backspace_outlined, color: Colors.grey),
              //         onPressed: onBackspacePressed,
              //       ),
              //     ],
              //   ),
              // ),

              // 表情面板主体（使用 Config + 嵌套 Configs）
              Expanded(
                child: EmojiPicker(
                  onEmojiSelected: (category, emoji) => onEmojiSelected(emoji.emoji),
                  onBackspacePressed: onBackspacePressed, // 直接传给 EmojiPicker 处理
                  config: Config(
                    height: 256, // 内部高度
                    // 底部动作栏（tab 按钮：最近/表情等）
                    bottomActionBarConfig: const BottomActionBarConfig(
                      backgroundColor: Colors.white,
                      buttonColor: Colors.transparent,
                      buttonIconColor: Colors.grey,
                      //selectedIconColor: Color(0xFF2483FF), // 这里现在正确了！（BottomActionBarConfig 支持）
                    ),

                    // 分类视图（小图标：笑脸/动物等）
                    categoryViewConfig: const CategoryViewConfig(
                      backgroundColor: Colors.white,
                      iconColor: Colors.grey,
                      iconColorSelected: Color(0xFF2483FF), // 正确字段：iconColorSelected
                      backspaceColor: Color(0xFF2483FF),
                      dividerColor: Colors.transparent,
                    ),

                    // 皮肤语气
                    skinToneConfig: const SkinToneConfig(enabled: true),

                    // 搜索栏
                    searchViewConfig: const SearchViewConfig(
                      backgroundColor: Color(0xFF1E252F),
                      buttonIconColor: Colors.grey,
                    ),

                    // 表情视图（列数/大小）
                    emojiViewConfig: EmojiViewConfig(
                      columns: 8, // 列数
                      emojiSizeMax: 32,
                      backgroundColor: const Color.fromARGB(255, 243, 243, 243),
                    ),

                    // 视图顺序（可选，自定义布局）
                    viewOrderConfig: const ViewOrderConfig(
                      top: EmojiPickerItem.categoryBar,
                      middle: EmojiPickerItem.emojiView,
                      bottom: EmojiPickerItem.searchBar,
                    ),

                    // 空最近记录
                    // noRecents: const Text(
                    //   "No Recents",
                    //   style: TextStyle(fontSize: 16, color: Colors.grey),
                    //   textAlign: TextAlign.center,
                    // ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}