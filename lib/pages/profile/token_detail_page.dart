import 'package:flutter/material.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/pages/profile/token_transfer_page.dart';
import 'package:education/pages/profile/receive_token_page.dart';
import 'package:education/pages/profile/quick_buy_swap_page.dart';
import 'package:education/pages/profile/token_kline_page.dart';
import 'package:education/widgets/common/token_avatar.dart';
import 'package:education/widgets/common/empty_state_view.dart';

/// 代币详情页：从 Token 列表点击某代币进入，与参考图一致
/// 含：头部（返回 + 代币图标 + 符号 + 网络标签）、你的余额、四宫格操作、交易历史、当前价格
class TokenDetailPage extends StatefulWidget {
  final String walletAddress;
  final String chain;
  /// 展示用，如 "BNB Chain"
  final String networkName;
  final String symbol;
  /// 余额 wei 字符串（原生或 ERC20）
  final String balanceWeiStr;
  final int decimals;
  /// 原生代币为 null
  final String? contractAddress;
  final Color iconColor;
  final String? logoUrl;
  /// 原生币单价（USD），用于计算余额美元价值；不传则显示 $ 0.00
  final double? priceUsd;

  const TokenDetailPage({
    super.key,
    required this.walletAddress,
    required this.chain,
    required this.networkName,
    required this.symbol,
    required this.balanceWeiStr,
    this.decimals = 18,
    this.contractAddress,
    this.iconColor = Colors.grey,
    this.logoUrl,
    this.priceUsd,
  });

  @override
  State<TokenDetailPage> createState() => _TokenDetailPageState();
}

class _TokenDetailPageState extends State<TokenDetailPage> {
  static const Color _green = Color(0xFF00D1A7);
  static const Color _buttonBg = Color(0xFF1E1E1E);

  String get _formattedBalance =>
      KnownTokens.formatBalanceDisplay(widget.balanceWeiStr, widget.decimals, maxDecimals: 6);

  /// USD 价值：USDT/USDC 按数量；BNB/ETH 按 priceUsd；其他为 $ 0.00
  String get _usdValue {
    final wei = BigInt.tryParse(widget.balanceWeiStr) ?? BigInt.zero;
    final amount = wei.toDouble() / BigInt.from(10).pow(widget.decimals).toDouble();
    if (widget.symbol == 'USDT' || widget.symbol == 'USDC') {
      return '\$ ${amount.toStringAsFixed(2)}';
    }
    if ((widget.symbol == 'BNB' || widget.symbol == 'ETH') && widget.priceUsd != null) {
      return '\$ ${(amount * widget.priceUsd!).toStringAsFixed(2)}';
    }
    return '\$ 0.00';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black87, size: 22),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TokenAvatar(
              symbol: widget.symbol,
              iconUrl: widget.logoUrl,
              iconColor: widget.iconColor,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(
              widget.symbol,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                widget.networkName,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),
            // 你的余额
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '你的余额',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _usdValue,
                    style: const TextStyle(
                      color: Colors.black87,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$_formattedBalance ${widget.symbol}',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // 四个圆形按钮：转账、接收、闪兑、聊天
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _actionButton(Icons.arrow_upward, '转账', _onTransfer),
                  _actionButton(Icons.arrow_downward, '接收', _onReceive),
                  _actionButton(Icons.swap_horiz, '闪兑', _onSwap),
                  _actionButton(Icons.chat_bubble_outline, '聊天', _onChat),
                ],
              ),
            ),
            const SizedBox(height: 32),
            // 交易历史
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '交易历史',
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        height: 3,
                        width: 40,
                        decoration: BoxDecoration(
                          color: _green,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 空状态插画 + 文案（与 EmptyStateView 一致）
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: EmptyStateView(),
            ),
            const SizedBox(height: 40),
            // 当前价格（可点击进入 K 线）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '当前价格',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  GestureDetector(
                    onTap: _onCurrentPriceTap,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _usdValue,
                          style: const TextStyle(
                            color: _green,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.chevron_right, color: _green, size: 22),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 24),
          ],
        ),
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: _buttonBg,
          shape: const CircleBorder(),
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Icon(icon, color: Colors.white, size: 26),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: Colors.black87,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  void _onTransfer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TokenTransferPage(walletAddress: widget.walletAddress),
      ),
    ).then((_) {
      // 可选：从转账页返回后刷新余额，由调用方传入 refresh 回调更合适
    });
  }

  void _onReceive() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReceiveTokenPage(
          walletAddress: widget.walletAddress,
          initialChain: widget.chain,
        ),
      ),
    );
  }

  void _onSwap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuickBuySwapPage(
          walletAddress: widget.walletAddress,
          chain: widget.chain,
        ),
      ),
    );
  }

  void _onChat() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('聊天功能开发中')),
    );
  }

  void _onCurrentPriceTap() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TokenKlinePage(
          symbol: widget.symbol,
          contractAddress: widget.contractAddress ?? '',
          chain: widget.chain,
        ),
      ),
    );
  }
}
