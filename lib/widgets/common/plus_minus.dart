import 'package:flutter/material.dart';

// + 按钮组件
class PlusButton extends StatelessWidget {
  final double size;          // 大小统一由 size 控制
  final VoidCallback? onPressed;

  const PlusButton({
    super.key,
    this.size = 52.0,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade400,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.add,
            size: size * 0.55,
            color: onPressed != null ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }
}

// - 按钮组件
class MinusButton extends StatelessWidget {
  final double size;          // 同 PlusButton
  final VoidCallback? onPressed;

  const MinusButton({
    super.key,
    this.size = 52.0,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.grey.shade400,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          alignment: Alignment.center,
          child: Icon(
            Icons.remove,
            size: size * 0.55,
            color: onPressed != null ? Colors.black87 : Colors.grey,
          ),
        ),
      ),
    );
  }
}
