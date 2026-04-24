import 'package:flutter/material.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/services/bbt_service.dart';
import 'package:education/services/alchemy_service.dart';
import 'package:education/widgets/common/empty_state_view.dart';

/// 个人中心点击 BBT 进入的页面：总资产/可用 BBT（从服务器获取）、全部/收入/支出记录（经网关 Alchemy）
class BbtCenterPage extends StatefulWidget {
  final String walletAddress;

  const BbtCenterPage({super.key, required this.walletAddress});

  @override
  State<BbtCenterPage> createState() => _BbtCenterPageState();
}

class _BbtCenterPageState extends State<BbtCenterPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  static const Color _green = Color(0xFF00D1A7);

  String? _balanceWeiHex;
  String? _balanceError;
  List<BbtTransferItem> _transfers = [];
  String? _transfersError;
  bool _loadingBalance = true;
  bool _loadingTransfers = true;

  /// 与 Token 页一致：固定最多 6 位小数
  static const int _bbtDecimals = 18;
  static const int _maxDisplayDecimals = 6;

  String get _balanceDisplay {
    if (_balanceWeiHex == null || _balanceWeiHex!.isEmpty) return '0';
    try {
      final hex = _balanceWeiHex!.replaceFirst(RegExp(r'^0x'), '');
      if (hex.isEmpty) return '0';
      final wei = BigInt.parse(hex, radix: 16);
      return KnownTokens.formatBalanceDisplay(wei.toString(), _bbtDecimals, maxDecimals: _maxDisplayDecimals);
    } catch (_) {
      return '0';
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadBalance();
    _loadTransfers();
  }

  Future<void> _loadBalance() async {
    setState(() {
      _loadingBalance = true;
      _balanceError = null;
    });
    final result = await BbtService.getBalance(widget.walletAddress);
    if (!mounted) return;
    setState(() {
      _loadingBalance = false;
      _balanceWeiHex = result.balanceWei;
      _balanceError = result.error;
    });
  }

  Future<void> _loadTransfers() async {
    setState(() {
      _loadingTransfers = true;
      _transfersError = null;
    });
    final result = await BbtService.getTransfers(widget.walletAddress);
    if (!mounted) return;
    setState(() {
      _loadingTransfers = false;
      _transfers = result.transfers;
      _transfersError = result.error;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<BbtTransferItem> _transfersForTab(int index) {
    if (index == 0) return _transfers;
    if (index == 1) return _transfers.where((e) => e.isIn).toList();
    return _transfers.where((e) => !e.isIn).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: const BoxDecoration(
                            color: Color(0x4DFFFFFF),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const Text(
                    '总资产',
                    style: TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      if (_loadingBalance)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white54),
                        )
                      else if (_balanceError != null)
                        Text(
                          _balanceError!,
                          style: const TextStyle(color: Colors.orangeAccent, fontSize: 16),
                        )
                      else
                        Text(
                          _balanceDisplay,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      const SizedBox(width: 6),
                      const Text(
                        'BBT',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '可用资产 ${_loadingBalance ? "—" : _balanceDisplay}',
                    style: const TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: Colors.black87,
                      unselectedLabelColor: Colors.grey,
                      indicatorColor: _green,
                      indicatorWeight: 3,
                      tabs: const [
                        Tab(text: '全部'),
                        Tab(text: '收入'),
                        Tab(text: '支出'),
                      ],
                    ),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: List.generate(3, (index) {
                          if (_loadingTransfers) {
                            return const Center(child: CircularProgressIndicator(color: _green));
                          }
                          if (_transfersError != null) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _transfersError!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[700]),
                                ),
                              ),
                            );
                          }
                          final list = _transfersForTab(index);
                          if (list.isEmpty) {
                            return _EmptyRecordsView(chain: AlchemyService.bnbMainnet);
                          }
                          return ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: list.length,
                            itemBuilder: (_, i) {
                              final t = list[i];
                              return _BbtRecordTile(item: t, myAddress: widget.walletAddress);
                            },
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BbtRecordTile extends StatelessWidget {
  final BbtTransferItem item;
  final String myAddress;

  const _BbtRecordTile({required this.item, required this.myAddress});

  @override
  Widget build(BuildContext context) {
    final isIn = item.isIn;
    final other = isIn ? item.from : item.to;
    final shortOther = other.length >= 10
        ? '${other.substring(0, 6)}...${other.substring(other.length - 4)}'
        : other;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4),
      leading: CircleAvatar(
        backgroundColor: isIn ? Colors.green.shade50 : Colors.red.shade50,
        child: Icon(
          isIn ? Icons.arrow_downward : Icons.arrow_upward,
          color: isIn ? Colors.green : Colors.red,
          size: 20,
        ),
      ),
      title: Text(
        isIn ? '收入' : '支出',
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      subtitle: Text(
        shortOther,
        style: TextStyle(color: Colors.grey[600], fontSize: 12),
      ),
      trailing: Text(
        '${isIn ? "+" : "-"}${_formatAmount(item.value)} BBT',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: isIn ? Colors.green : Colors.red,
          fontSize: 14,
        ),
      ),
    );
  }

  /// 与 Token 页一致：金额固定最多 6 位小数
  static String _formatAmount(String valueStr) {
    const maxDecimals = 6;
    final v = double.tryParse(valueStr);
    if (v == null) return valueStr;
    if (v == 0) return '0';
    if (v.abs() >= 1) return v.toStringAsFixed(maxDecimals).replaceAll(RegExp(r'\.?0+$'), '');
    if (v.abs() >= 0.0001) return v.toStringAsFixed(6).replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    return v.toStringAsFixed(maxDecimals);
  }
}

/// 记录为空时的说明（含「当前链可能不支持转账记录」的提示）
class _EmptyRecordsView extends StatelessWidget {
  final String chain;

  const _EmptyRecordsView({required this.chain});

  @override
  Widget build(BuildContext context) {
    final isBnb = chain == AlchemyService.bnbMainnet;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const EmptyStateView(),
            if (isBnb) ...[
              const SizedBox(height: 16),
              Text(
                'BNB 链的转账记录依赖第三方接口，可能暂未开放或暂无流水',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
