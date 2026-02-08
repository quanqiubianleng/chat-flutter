// 文件：widgets/follower/debox_floating_menu.dart
import 'dart:ui';
import 'package:education/pages/market/publish_dynamic_page.dart';
import 'package:education/providers/feed_refresh_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class DeBoxFloatingMenu extends ConsumerStatefulWidget {
  const DeBoxFloatingMenu({super.key});

  @override
  ConsumerState<DeBoxFloatingMenu> createState() => _DeBoxFloatingMenuState();
}

class _DeBoxFloatingMenuState extends ConsumerState<DeBoxFloatingMenu>
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
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            bottom: 0,
            child: SafeArea(
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
              right: 12,
              bottom: 20 + bottomInset,
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
                    child:                     _isOpen
                        ? Column(
                            children: [
                              _menuItem("抽奖", Icons.card_giftcard, const Color(0xFFFF3B30), onTap: () {}),
                              _menuItem("空投", Icons.flight_land, const Color(0xFF5C6BC0), onTap: () {}),
                              _menuItem("Meetup", Icons.record_voice_over, const Color(0xFF8E24AA), onTap: () {}),
                              _menuItem("Live", Icons.videocam, const Color(0xFF00C853), onTap: () {}),
                              _menuItem("发布到动态", Icons.edit_note, const Color(0xFF00C853), onTap: () {
                                _toggle();
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const PublishDynamicPage()))
                                    .then((_) => ref.read(feedRefreshTriggerProvider.notifier).state++);
                              }),
                              const SizedBox(height: 16),
                            ],
                          )
                        : const SizedBox(),
                  ),
                ),

                // 主按钮（调小）
                GestureDetector(
                  onTap: _toggle,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00C853),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: AnimatedRotation(
                      turns: _isOpen ? 0.125 : 0,
                      duration: const Duration(milliseconds: 320),
                      child: const Icon(Icons.add, size: 26, color: Colors.white),
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
  Widget _menuItem(String title, IconData icon, Color iconColor, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        child: Align(
          alignment: Alignment.centerRight,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
            ],
          ),
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
