// lib/widgets/asset/lab_grid.dart
import 'package:flutter/material.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/pages/profile/favorites_page.dart';
import 'package:education/pages/profile/quick_buy_swap_page.dart';
import 'package:education/widgets/common/grid_icon_item.dart';

class LabGrid extends StatelessWidget {
  /// 当前用户钱包地址（点击闪兑时跳转 QuickBuySwapPage 需要）
  final String? walletAddress;

  const LabGrid({super.key, this.walletAddress});

  @override
  Widget build(BuildContext context) {
    final items = [
      {"i": Icons.explore, "t": "发现", "onTap": null},
      // {"i": Icons.wallet, "t": "口令红包", "onTap": null},
      {"i": Icons.swap_horiz, "t": "闪兑", "onTap": () => _onTapFlashSwap(context)},
      {"i": Icons.groups, "t": "社区", "onTap": null},
      {"i": Icons.favorite_border, "t": "收藏", "onTap": () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoritesPage()));
      }},
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
              onTap: items[i]["onTap"] as VoidCallback?,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _onTapFlashSwap(BuildContext context) {
    final addr = walletAddress ?? '';
    if (addr.isEmpty || !addr.startsWith('0x')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先绑定钱包地址')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => QuickBuySwapPage(
          walletAddress: addr,
          chain: KnownTokens.bnbMainnet,
          initialTabIndex: 1,
        ),
      ),
    );
  }
}