// lib/features/chat/components/message_items/transfer_bubble.dart
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/websocket/ws_extra.dart';
import '../../pb/protos/chat.pb.dart';

class TransferBubble extends StatefulWidget {
  final Event message;
  final String coin;          // USDT / ETH 等
  final bool isMe;            // 是否自己发出的转账

  const TransferBubble({
    Key? key,
    required this.message,
    this.coin = "USDT",
    required this.isMe,
  }) : super(key: key);

  @override
  State<TransferBubble> createState() => _TransferBubbleState();
}

class _TransferBubbleState extends State<TransferBubble> {

  late int amount;
  late int status;
  late int expiredAt;

  @override
  void initState() {
    super.initState();
    _parseExtra(); // 在 initState 中解析 extra
  }

  // 可选：如果需要本地动态状态（如领取中加载），可以在这里定义
  bool _isClaiming = false;

  // 根据状态决定背景色
  Color _getBackgroundColor() {
    if (widget.isMe) {
      return const Color(0xFF2483FF); // 自己发送：蓝色
    } else {
      return const Color(0xFF1E252F); // 对方发送：深灰
    }
  }

  void _parseExtra() {
    // 默认值
    amount = 0;
    status = 0;
    expiredAt = 0;

    if (widget.message.extra.isEmpty) {
      return;
    }

    try {
      final extraJsonString = utf8.decode(widget.message.extra);
      final extraMap = jsonDecode(extraJsonString) as Map<String, dynamic>;

      // 假设你有 RedPacketExtra 这个类（由 protobuf 生成或手动定义）
      final redPacketExtra = TransferExtra.fromJson(extraMap);

      setState(() {
        amount = redPacketExtra.amount;
        status = redPacketExtra.status;
        expiredAt = redPacketExtra.expiredAt;
      });

      print('解析转账 extra 成功：amount=$amount');
    } catch (e) {
      print('解析转账 extra 失败：$e');
    }
  }

  // 根据状态决定是否可点击
  void _onTap() {
    if (status == 0 && !widget.isMe) {
      // 只有对方发的、待领取的转账才可以点击领取
      // TODO: 调用领取接口
      setState(() {
        _isClaiming = true;
      });

      // 模拟领取成功
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _isClaiming = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("转账领取成功！🎉")),
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool canClaim = status == 0 && !widget.isMe;

    return GestureDetector(
      onTap: canClaim ? _onTap : null,
      child: Container(
        width: 240,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _getBackgroundColor(),
          borderRadius: BorderRadius.circular(12),
          // 可点击时加个轻微边框或阴影提示
          border: canClaim
              ? Border.all(color: Colors.amber.withOpacity(0.5), width: 1.5)
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.account_balance_wallet, color: Colors.amber, size: 28),
                SizedBox(width: 10),
                Text(
                  "转账",
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              "${amount} ${widget.coin}",
              style: const TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            // 状态标签
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _getStatusBackgroundColor(),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isClaiming)
                    const SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  if (_isClaiming) const SizedBox(width: 8),
                  Text(
                    _getStatusText(),
                    style: TextStyle(
                      color: _getStatusTextColor(),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _getHintText(),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusBackgroundColor() {
    switch (status) {
      case 3:
        return Colors.green.withOpacity(0.3);
      case 0:
        return Colors.amber.withOpacity(0.3);
      case 1:
        return Colors.grey.withOpacity(0.3);
      case 2:
        return Colors.red.withOpacity(0.3);
      default:
        return Colors.orange.withOpacity(0.3);
    }
  }

  Color _getStatusTextColor() {
    switch (status) {
      case 3:
        return Colors.green;
      case 0:
        return Colors.amber;
      case 1:
      case 2:
        return Colors.grey;
      default:
        return Colors.orange;
    }
  }

  String _getStatusText() {
    if (_isClaiming) return "领取中...";
    return "领取中";
  }

  String _getHintText() {
    if (widget.isMe && status == 1) {
      return "对方已领取";
    } else if (widget.isMe && status == 2) {
      return "24小时未领取，已退回";
    } else if (!widget.isMe && status == 1) {
      return "你已领取";
    }
    return "";
  }
}