import 'package:flutter/material.dart';

/// 带数字角标的图标组件
class BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int badgeCount;
  final bool isActive;

  const BadgeIcon({
    super.key,
    required this.icon,
    this.badgeCount = 0,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(
          icon,
          size: 28,
          color: isActive ? const Color(0xFF00D29D) : const Color(0xFF999999),
        ),
        if (badgeCount > 0)
          Positioned(
            right: -8,
            top: -5,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFFFF4D4F),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 1),
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                '$badgeCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}