// lib/features/chat/components/message_items/transfer_bubble.dart
import 'package:flutter/material.dart';

class TransferBubble extends StatelessWidget {
  final String amount;        // 例如 "100.00"
  final String coin;          // USDT / ETH 等
  final String status;        // "已到账" / "待领取" / "已领取"
  final bool isMe;

  const TransferBubble({
    Key? key,
    required this.amount,
    this.coin = "USDT",
    this.status = "已到账",
    required this.isMe,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 240,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isMe ? const Color(0xFF2483FF) : const Color(0xFF1E252F),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.account_balance_wallet, color: Colors.amber, size: 28),
              SizedBox(width: 10),
              Text("转账", style: TextStyle(color: Colors.white, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            "$amount $coin",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: status == "已到账"
                  ? Colors.green.withOpacity(0.3)
                  : Colors.orange.withOpacity(0.3),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: status == "已到账" ? Colors.green : Colors.orange,
                fontSize: 12,
              ),
            ),
          ),
          if (status != "已到账")
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text("对方已领取", style: TextStyle(color: Colors.grey, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}