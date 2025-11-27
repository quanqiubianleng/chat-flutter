// 文件：widgets/debox_floating_menu.dart
import 'dart:ui';
import 'package:flutter/material.dart';

class DeBoxFloatingMenu extends StatefulWidget {
  const DeBoxFloatingMenu({super.key});

  @override
  State<DeBoxFloatingMenu> createState() => _DeBoxFloatingMenuState();
}

class _DeBoxFloatingMenuState extends State<DeBoxFloatingMenu>
    with SingleTickerProviderStateMixin {
  bool _isOpen = false;
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
  }

  void _toggle() {
    setState(() {
      _isOpen = !_isOpen;
      _isOpen ? _controller.forward() : _controller.reverse();
    });
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final double topInset = mediaQuery.padding.top;
    final double bottomInset = mediaQuery.padding.bottom;

    return Stack(
      children: [
        // 毛玻璃背景（已完美铺满内容区）
        if (_isOpen)
          SafeArea(
            child: Positioned(
              top: topInset,
              left: 0,
              right: 0,
              bottom: bottomInset,
              child: AnimatedOpacity(
                opacity: 1.0,
                duration: const Duration(milliseconds: 300),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                  child: Container(color: Colors.white.withOpacity(0.12)),
                ),
              ),
            ),
          ),
          

        // 点击空白关闭
        if (_isOpen)
          Positioned(
            top: topInset,
            left: 0,
            right: 0,
            bottom: bottomInset,
            child: GestureDetector(onTap: _toggle, child: Container(color: Colors.transparent)),
          ),

        // 菜单本体（右下角）
        Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(
              right: 16,
              bottom: 28 + bottomInset,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: AnimatedOpacity(
                    opacity: _isOpen ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: _isOpen
                        ? Column(
                            children: [
                              _menuItem("抽奖", Icons.card_giftcard, const Color(0xFFFF3B30)),
                              _menuItem("空投", Icons.flight_land, const Color(0xFF5C6BC0)),
                              _menuItem("Meetup", Icons.record_voice_over, const Color(0xFF8E24AA)),
                              _menuItem("Live", Icons.videocam, const Color(0xFF00C853)),
                              _menuItem("发布到动态", Icons.edit_note, const Color(0xFF00C853)),
                              const SizedBox(height: 28),
                            ],
                          )
                        : const SizedBox(),
                  ),
                ),

                // 主按钮
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8)),
                      ],
                    ),
                    child: AnimatedRotation(
                      turns: _isOpen ? 0.125 : 0,
                      duration: const Duration(milliseconds: 320),
                      child: const Icon(Icons.add, size: 38, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 终极修复：图标完全贴右边！
  Widget _menuItem(String title, IconData icon, Color iconColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      // 关键：用 Align 强制右对齐整个 Row
      child: Align(
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 文字
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 15),
              child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(width: 10),
            // 图标（现在 100% 贴右边）
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}