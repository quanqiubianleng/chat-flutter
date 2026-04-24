import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kNewbieGuideShownKey = 'newbie_guide_shown';

/// 新手引导浮层，首次进入主界面时显示，点击「知道了」后不再显示
class NewbieGuideOverlay extends StatefulWidget {
  final Widget child;

  const NewbieGuideOverlay({super.key, required this.child});

  @override
  State<NewbieGuideOverlay> createState() => _NewbieGuideOverlayState();

  /// 是否已展示过引导（供外部查询，如设置页「再次查看引导」）
  static Future<bool> hasShown() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kNewbieGuideShownKey) ?? false;
  }

  /// 重置为未展示（用于设置里「再次查看引导」）
  static Future<void> resetShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kNewbieGuideShownKey);
  }
}

class _NewbieGuideOverlayState extends State<NewbieGuideOverlay> {
  bool _showGuide = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final shown = prefs.getBool(_kNewbieGuideShownKey) ?? false;
    if (!mounted) return;
    setState(() {
      _checked = true;
      _showGuide = !shown;
    });
  }

  Future<void> _dismiss() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kNewbieGuideShownKey, true);
    if (!mounted) return;
    setState(() => _showGuide = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!_checked || !_showGuide) return widget.child;

    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Material(
            color: Colors.black54,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.tips_and_updates_outlined,
                        size: 64,
                        color: Color(0xFF00D29D),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        '欢迎使用 BBT',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '在这里你可以：收发消息、浏览动态、管理资产与闪兑等。底部可切换「消息 / 通讯录 / 广场 / 我的」。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.white.withOpacity(0.9),
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _dismiss,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00D29D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('知道了'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
