import 'package:flutter/material.dart';
import 'package:education/services/alchemy_service.dart';
import 'package:education/widgets/common/empty_state_view.dart';

/// 网络选项（与图二一致：BNB Chain 选中黄色，其余灰色）
class TransferNetworkOption {
  final String id;
  final String name;
  final Widget? icon;
  /// 对应 Alchemy 链 id，空表示暂不支持拉取
  final String? alchemyChain;

  const TransferNetworkOption({
    required this.id,
    required this.name,
    this.icon,
    this.alchemyChain,
  });
}

/// 代币选项
class TransferTokenOption {
  final String symbol;
  final String name;
  final String balance;
  final String usdValue;
  final Widget? logo;

  const TransferTokenOption({
    required this.symbol,
    required this.name,
    this.balance = '0',
    this.usdValue = '\$0',
    this.logo,
  });
}

/// 选择转账代币弹窗：标题、搜索、网络横向标签、代币列表（与图二一致）；切换网络时按链拉取代币
class TransferTokenSheet extends StatefulWidget {
  final String walletAddress;
  /// 再次打开弹窗时恢复选中的网络（如 'eth-mainnet'）
  final String initialNetworkId;
  final void Function(String networkId, String networkName, String tokenSymbol) onSelect;

  const TransferTokenSheet({
    super.key,
    this.walletAddress = '',
    this.initialNetworkId = 'bnb-mainnet',
    required this.onSelect,
  });

  @override
  State<TransferTokenSheet> createState() => _TransferTokenSheetState();
}

class _TransferTokenSheetState extends State<TransferTokenSheet> {
  final TextEditingController _searchController = TextEditingController();
  final AlchemyService _alchemy = AlchemyService();

  static const List<TransferNetworkOption> _networks = [
    TransferNetworkOption(id: 'bnb-mainnet', name: 'BNB Chain', alchemyChain: AlchemyService.bnbMainnet),
    TransferNetworkOption(id: 'xlayer', name: 'X Layer', alchemyChain: null),
    TransferNetworkOption(id: 'base-mainnet', name: 'Base', alchemyChain: 'base-mainnet'),
    TransferNetworkOption(id: 'eth-mainnet', name: 'Ethereum', alchemyChain: AlchemyService.ethMainnet),
  ];

  late int _selectedNetworkIndex;
  List<TransferTokenOption> _tokens = [];
  List<TransferTokenOption> _filteredTokens = [];
  bool _loading = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _selectedNetworkIndex = _networks.indexWhere((n) => n.id == widget.initialNetworkId);
    if (_selectedNetworkIndex < 0) _selectedNetworkIndex = 0;
    _searchController.addListener(_filterTokens);
    _loadTokensForCurrentNetwork();
  }

  String _nativeSymbolForChain(String? alchemyChain) {
    if (alchemyChain == AlchemyService.bnbMainnet) return 'BNB';
    if (alchemyChain == AlchemyService.ethMainnet || alchemyChain == 'base-mainnet') return 'ETH';
    return 'ETH';
  }

  Future<void> _loadTokensForCurrentNetwork() async {
    final net = _networks[_selectedNetworkIndex];
    final chain = net.alchemyChain;
    final addr = widget.walletAddress;

    if (chain == null || chain.isEmpty || !AlchemyService.isAvailable) {
      setState(() {
        _tokens = [];
        _filteredTokens = [];
        _loading = false;
        _loadError = chain == null ? null : '未配置 Alchemy';
      });
      _filterTokens();
      return;
    }

    if (addr.isEmpty || !addr.startsWith('0x')) {
      setState(() {
        _tokens = [
          TransferTokenOption(
            symbol: _nativeSymbolForChain(chain),
            name: _nativeSymbolForChain(chain),
            balance: '0',
            usdValue: '\$0',
          ),
        ];
        _filteredTokens = List.from(_tokens);
        _loading = false;
        _loadError = null;
      });
      _filterTokens();
      return;
    }

    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final balanceResult = await _alchemy.getTokenBalances(addr, chain: chain);
      final nativeBalance = await _alchemy.getNativeBalance(addr, chain: chain);
      if (!mounted) return;
      final list = <TransferTokenOption>[];
      final nativeSym = _nativeSymbolForChain(chain);
      list.add(TransferTokenOption(
        symbol: nativeSym,
        name: nativeSym,
        balance: nativeBalance ?? '0',
        usdValue: '\$0',
      ));
      for (final t in balanceResult.tokenBalances) {
        if (t.balanceWei > BigInt.zero) {
          list.add(TransferTokenOption(
            symbol: '${t.contractAddress.substring(0, 6)}...',
            name: '${t.contractAddress.substring(0, 6)}...',
            balance: t.balanceWei.toString(),
            usdValue: '\$0',
          ));
        }
      }
      setState(() {
        _tokens = list;
        _filteredTokens = List.from(list);
        _loading = false;
        _loadError = balanceResult.error;
      });
      _filterTokens();
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
          _tokens = [];
          _filteredTokens = [];
        });
        _filterTokens();
      }
    }
  }

  void _filterTokens() {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() => _filteredTokens = List.from(_tokens));
      return;
    }
    setState(() {
      _filteredTokens = _tokens
          .where((t) =>
              t.symbol.toLowerCase().contains(q) ||
              t.name.toLowerCase().contains(q))
          .toList();
    });
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterTokens);
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final network = _networks[_selectedNetworkIndex];
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '选择转账代币',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 24, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // 搜索框
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: '搜索代币名称、合约地址',
                  hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                  prefixIcon: Icon(Icons.search, color: Colors.grey[600], size: 22),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  isDense: true,
                ),
              ),
            ),
            // 网络横向滚动
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _networks.length,
                itemBuilder: (context, i) {
                  final n = _networks[i];
                  final selected = i == _selectedNetworkIndex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Material(
                      color: selected ? const Color(0xFFFFC107) : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(22),
                      child: InkWell(
                        onTap: () {
                          setState(() => _selectedNetworkIndex = i);
                          _loadTokensForCurrentNetwork();
                        },
                        borderRadius: BorderRadius.circular(22),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (n.id == 'bnb-mainnet')
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: Colors.amber.shade700,
                                    shape: BoxShape.circle,
                                  ),
                                )
                              else if (n.icon != null)
                                n.icon!
                              else
                                const SizedBox.shrink(),
                              if (n.id == 'bnb-mainnet' || n.icon != null) const SizedBox(width: 6),
                              Text(
                                n.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                  color: selected ? Colors.black87 : Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // 代币列表
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.35),
              child: _loading
                  ? const Padding(
                      padding: EdgeInsets.all(32),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _loadError != null
                      ? Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              _loadError!,
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _filteredTokens.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24),
                              child: EmptyStateView(),
                            )
                          : ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _filteredTokens.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (context, i) {
                  final t = _filteredTokens[i];
                  return InkWell(
                    onTap: () {
                      widget.onSelect(network.id, network.name, t.symbol);
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          t.logo ??
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade200,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.monetization_on_outlined, color: Colors.amber),
                              ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              t.symbol,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                t.balance,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                              Text(
                                t.usdValue,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
