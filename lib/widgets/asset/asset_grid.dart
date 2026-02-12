import 'package:flutter/material.dart';
import 'package:education/pages/profile/token_list_page.dart';
import 'package:education/pages/profile/bbt_center_page.dart';
import 'package:education/services/alchemy_service.dart';
import '../common/grid_icon_item.dart';

class AssetGrid extends StatelessWidget {
  /// 当前用户钱包地址（用于 Token/NFT 拉取 Alchemy 数据）
  final String? walletAddress;

  const AssetGrid({super.key, this.walletAddress});

  @override
  Widget build(BuildContext context) {
    final items = [
      {"i": Icons.token, "t": "Token", "c": const Color(0xFF00C853), "id": "token"},
      {"i": Icons.image, "t": "NFT", "c": const Color(0xFFFF8F00), "id": "nft"},
      {"i": Icons.eco, "t": "BBT", "c": const Color(0xFF00D1A7), "id": "bbt"},
      {"i": Icons.vpn_key, "t": "Key", "c": const Color(0xFF5C6BC0), "id": "key"},
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
            itemBuilder: (_, i) {
              final id = items[i]["id"] as String;
              final onTap = _onTapFor(context, id);
              return GridIconItem(
                icon: items[i]["i"] as IconData,
                label: items[i]["t"] as String,
                color: items[i]["c"] as Color,
                onTap: onTap,
              );
            },
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  VoidCallback? _onTapFor(BuildContext context, String id) {
    return () {
      switch (id) {
        case 'token':
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
              builder: (_) => TokenListPage(
                walletAddress: addr,
                chain: AlchemyService.bnbMainnet,
              ),
            ),
          );
          break;
        case 'nft':
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
              builder: (_) => TokenListPage(
                walletAddress: addr,
                chain: AlchemyService.bnbMainnet,
                initialTabNft: true,
              ),
            ),
          );
          break;
        case 'bbt':
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const BbtCenterPage()),
          );
          break;
        case 'key':
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Key 功能开发中')),
          );
          break;
      }
    };
  }
}