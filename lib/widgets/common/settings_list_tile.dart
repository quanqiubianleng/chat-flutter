import 'package:flutter/material.dart';

class SettingsListTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback? onTap;
  final Widget? trailing;

  const SettingsListTile({
    super.key,
    required this.icon,
    required this.title,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15),
      leading: Icon(icon, color: Colors.black87, size: 26),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: trailing ?? const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}