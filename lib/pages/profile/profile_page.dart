import 'package:flutter/material.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 顶部导航区
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.grid_view, size: 16, color: Colors.grey),
                          SizedBox(width: 6),
                          Text('切换账号', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.grey),
                        ],
                      ),
                    ),
                    const Row(
                      children: [
                        Icon(Icons.qr_code_scanner, color: Colors.black87),
                        SizedBox(width: 16),
                        Icon(Icons.badge_outlined, color: Colors.black87),
                        SizedBox(width: 16),
                        Icon(Icons.settings_outlined, color: Colors.black87),
                      ],
                    )
                  ],
                ),
              ),
              
              // 用户信息卡片
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: Colors.purple[100],
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         Text('bd65096c', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                         SizedBox(height: 8),
                         Text('Lv.1', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ),
              
              // 资产部分
              _buildSectionTitle('资产'),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildGridItem(Icons.currency_bitcoin, 'Token', Colors.green),
                    _buildGridItem(Icons.image_outlined, 'NFT', Colors.black),
                    _buildGridItem(Icons.account_balance_wallet_outlined, 'vBOX', Colors.black),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(left: 20, bottom: 8, top: 16),
      child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildGridItem(IconData icon, String label, Color color) {
    return Column(
      children: [
        Icon(icon, size: 24, color: Colors.black87),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black87)),
      ],
    );
  }
}