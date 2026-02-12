import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 快速购买 / 闪兑 页（从 Token 页点击「闪兑」进入）
/// 顶部 Tab：快速购买（默认）、闪兑；布局与参考图一致
class QuickBuySwapPage extends StatefulWidget {
  final String walletAddress;
  final String chain;

  const QuickBuySwapPage({
    super.key,
    required this.walletAddress,
    this.chain = 'bnb-mainnet',
  });

  @override
  State<QuickBuySwapPage> createState() => _QuickBuySwapPageState();
}

class _QuickBuySwapPageState extends State<QuickBuySwapPage> {
  static const Color _green = Color(0xFF00D1A7);
  static const Color _darkBg = Color(0xFF1A1A1A);

  /// 0=快速购买, 1=闪兑
  int _tabIndex = 0;
  /// 快速购买：0=买入, 1=卖出
  bool _isBuy = true;
  /// 快速购买：输入金额
  final TextEditingController _amountController = TextEditingController(text: '');
  /// 闪兑：源金额、目标金额
  final TextEditingController _fromAmountController = TextEditingController(text: '0.00');
  final TextEditingController _toAmountController = TextEditingController(text: '0.00');

  /// 快速购买 - USDT 合约地址（示例）
  static const String _usdtContract = '0xdAC17F958D2e5235939F3AaB6c7697203E9D9472';

  @override
  void dispose() {
    _amountController.dispose();
    _fromAmountController.dispose();
    _toAmountController.dispose();
    super.dispose();
  }

  void _copyAddress() {
    Clipboard.setData(const ClipboardData(text: _usdtContract));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已复制合约地址')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _appBarTab('快速购买', 0),
            const SizedBox(width: 24),
            _appBarTab('闪兑', 1),
          ],
        ),
        centerTitle: true,
        actions: [
          _appBarIcon(Icons.person_outline, color: Colors.purple.shade300),
          const SizedBox(width: 16),
          _appBarIcon(Icons.show_chart, color: Colors.blue.shade700),
          const SizedBox(width: 16),
          _appBarIcon(Icons.description_outlined, color: Colors.grey.shade700),
          const SizedBox(width: 16),
          _appBarIcon(Icons.share_outlined, color: Colors.grey.shade700),
          const SizedBox(width: 12),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: _tabIndex == 0 ? _buildQuickBuy() : _buildFlashSwap(),
      ),
    );
  }

  Widget _appBarTab(String label, int index) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: 48,
            decoration: BoxDecoration(
              color: selected ? _green : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _appBarIcon(IconData icon, {Color? color}) {
    return Icon(icon, size: 22, color: color ?? Colors.grey.shade700);
  }

  /// ---------- 快速购买 ----------
  Widget _buildQuickBuy() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 买入 / 卖出 分段
        Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Expanded(
                child: _segmentChip('买入', _isBuy, () => setState(() => _isBuy = true), left: true),
              ),
              Expanded(
                child: _segmentChip('卖出', !_isBuy, () => setState(() => _isBuy = false), left: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // USDT 信息卡片
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text('T', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('USDT', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                            Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600, size: 20),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '价格: \$1 | 市值: \$99630.88M',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '0xdAC17F958D2e...4597C13D831ec7',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace'),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: _copyAddress,
                              icon: Icon(Icons.copy, size: 16, color: Colors.grey.shade700),
                              label: Text('复制', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                backgroundColor: Colors.grey.shade200,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        // 余额 + MAX
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('余额: 0 ETH', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            GestureDetector(
              onTap: () {},
              child: const Text('MAX', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _green)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 输入行
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    hintText: '0.00',
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              Text('ETH', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
              const SizedBox(width: 4),
              Icon(Icons.diamond, size: 18, color: Colors.blue.shade700),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // 快捷金额
        Row(
          children: [
            _quickAmount('0.05'),
            const SizedBox(width: 10),
            _quickAmount('0.1'),
            const SizedBox(width: 10),
            _quickAmount('0.5'),
            const SizedBox(width: 10),
            _quickAmount('1'),
            const SizedBox(width: 10),
            _quickAmount('2'),
          ],
        ),
        const SizedBox(height: 32),
        // 快速买入 USDT
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: _darkBg,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('快速买入 USDT', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  Widget _segmentChip(String label, bool selected, VoidCallback onTap, {required bool left}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(
          left: const Radius.circular(8),
          right: left ? Radius.zero : const Radius.circular(8),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _darkBg : Colors.transparent,
            borderRadius: BorderRadius.horizontal(
              left: const Radius.circular(8),
              right: left ? Radius.zero : const Radius.circular(8),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : Colors.grey.shade800,
            ),
          ),
        ),
      ),
    );
  }

  Widget _quickAmount(String value) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => _amountController.text = value,
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.black87,
          side: BorderSide(color: Colors.grey.shade300),
          padding: const EdgeInsets.symmetric(vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(value, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  /// ---------- 闪兑 ----------
  Widget _buildFlashSwap() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 从 BNB Chain
        _swapCard(
          title: '从 BNB Chain',
          balanceText: '余额:0',
          rightAction: '全部',
          tokenLabel: 'BNB',
          tokenIconColor: Colors.amber.shade700,
          controller: _fromAmountController,
        ),
        const SizedBox(height: 8),
        // 交换图标
        Center(
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Icon(Icons.swap_vert, color: Colors.grey.shade700, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        // 至 BNB Chain
        _swapCard(
          title: '至 BNB Chain',
          balanceText: '余额:0',
          tokenLabel: 'BTCB',
          tokenIconColor: Colors.orange.shade700,
          controller: _toAmountController,
        ),
        const SizedBox(height: 24),
        // 闪兑 按钮
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: () {},
            style: FilledButton.styleFrom(
              backgroundColor: Colors.grey.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('闪兑', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 24),
        // 参考汇率、滑点、最优通道
        _detailRow('参考汇率', hasInfo: true, value: '--'),
        const SizedBox(height: 12),
        _detailRow('滑点', hasInfo: true, value: '--', trailing: Icon(Icons.settings, size: 18, color: Colors.grey.shade600)),
        const SizedBox(height: 12),
        _detailRow('最优通道', hasInfo: true, value: '--'),
        const SizedBox(height: 28),
        // 最近一条交易
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(width: 8),
            const Text('最近一条交易', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: () {},
              child: Text('查看更多 >', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Center(
            child: Text('暂无记录', style: TextStyle(fontSize: 14, color: Colors.grey.shade500)),
          ),
        ),
      ],
    );
  }

  Widget _swapCard({
    required String title,
    required String balanceText,
    required String tokenLabel,
    required Color tokenIconColor,
    required TextEditingController controller,
    String? rightAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Row(
                children: [
                  Text(balanceText, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  if (rightAction != null) ...[
                    const SizedBox(width: 4),
                    Text(rightAction, style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w500)),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: tokenIconColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    tokenLabel.substring(0, 1),
                    style: TextStyle(fontWeight: FontWeight.bold, color: tokenIconColor, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(tokenLabel, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600, size: 22),
              const Spacer(),
              SizedBox(
                width: 100,
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.right,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                    hintText: '0.00',
                  ),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, {required bool hasInfo, required String value, Widget? trailing}) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
        if (hasInfo) ...[
          const SizedBox(width: 4),
          Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500),
        ],
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing,
        ],
      ],
    );
  }
}
