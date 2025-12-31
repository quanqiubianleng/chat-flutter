import 'package:flutter/material.dart';

class GradientBanner extends StatelessWidget {
  final String text;
  final String buttonText;
  final VoidCallback? onTap;

  const GradientBanner({
    super.key,
    required this.text,
    this.buttonText = "去开通",
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF69F0AE), Color(0xFF00C853)]),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.celebration, color: Colors.white, size: 26),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600))),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.3), borderRadius: BorderRadius.circular(20)),
              child: Text(buttonText, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
            ),
          ),
        ],
      ),
    );
  }
}