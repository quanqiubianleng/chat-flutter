import 'package:flutter/material.dart';
import 'settings_list_tile.dart';

class SettingsSection extends StatelessWidget {
  final List<({
    IconData icon,
    String title,
    VoidCallback? onTap,
  })> items;

  const SettingsSection({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Column(
            children: [
              SettingsListTile(
                icon: item.icon,
                title: item.title,
                onTap: item.onTap,
              ),
              if (index < items.length - 1)
                const Divider(height: 1, indent: 56, endIndent: 20),
            ],
          );
        }).toList(),
      ),
    );
  }
}