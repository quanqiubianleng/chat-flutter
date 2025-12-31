// lib/widgets/asset/lab_grid.dart
import 'package:flutter/material.dart';
import 'package:education/widgets/common/grid_icon_item.dart';

class LabGrid extends StatelessWidget {
  const LabGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {"i": Icons.explore, "t": "发现"},
      {"i": Icons.wallet, "t": "口令红包"},
      {"i": Icons.smart_toy, "t": "AI Bot"},
      {"i": Icons.groups, "t": "社区"},
      {"i": Icons.favorite_border, "t": "收藏"},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Text("实验室", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.2,   // 必须 ≥ 1.2！1.15 还不够
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => GridIconItem(
              icon: items[i]["i"] as IconData,
              label: items[i]["t"] as String,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  
  }
}