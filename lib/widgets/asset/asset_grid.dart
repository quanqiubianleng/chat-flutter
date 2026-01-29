import 'package:flutter/material.dart';
import '../common/grid_icon_item.dart';

class AssetGrid extends StatelessWidget {
  const AssetGrid({super.key});

  @override
  Widget build(BuildContext context) {
    final items = [
      {"i": Icons.token, "t": "Token", "c": const Color(0xFF00C853)},
      {"i": Icons.image, "t": "NFT", "c": const Color(0xFFFF8F00)},
      {"i": Icons.card_giftcard, "t": "BBT社区", "c": const Color(0xFF8E24AA)},
      {"i": Icons.vpn_key, "t": "Key", "c": const Color(0xFF5C6BC0)},
    ];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12),
      ]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(20, 20, 20, 12), child: Text("资产", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 1.2,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) => GridIconItem(
              icon: items[i]["i"] as IconData,
              label: items[i]["t"] as String,
              color: items[i]["c"] as Color,
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}