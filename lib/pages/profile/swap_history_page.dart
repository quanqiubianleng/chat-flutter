import 'package:flutter/material.dart';

/// 闪兑/交易历史页（占位：列表可后续对接链上或后端）
class SwapHistoryPage extends StatelessWidget {
  final String walletAddress;
  final String chain;

  const SwapHistoryPage({
    super.key,
    required this.walletAddress,
    this.chain = 'bnb-mainnet',
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('交易历史', style: TextStyle(fontSize: 18, color: Colors.black87, fontWeight: FontWeight.w600)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.history, size: 64, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text('暂无交易记录', style: TextStyle(fontSize: 16, color: Colors.grey.shade600)),
              const SizedBox(height: 8),
              Text('闪兑记录将显示在这里', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
            ],
          ),
        ),
      ),
    );
  }
}
