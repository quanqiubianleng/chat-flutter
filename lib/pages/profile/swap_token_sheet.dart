import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/services/alchemy_service.dart';
import 'package:education/services/coingecko_service.dart';
import 'package:education/widgets/common/token_avatar.dart';

/// 闪兑/快速购买用：单链代币选择，返回 symbol, balanceWeiStr, decimals, contractAddress, formattedBalance
class SwapTokenOption {
  final String symbol;
  final String balanceWeiStr;
  final int decimals;
  final String? contractAddress;
  final String formattedBalance;
  final Color iconColor;

  const SwapTokenOption({
    required this.symbol,
    required this.balanceWeiStr,
    required this.decimals,
    this.contractAddress,
    required this.formattedBalance,
    this.iconColor = Colors.grey,
  });
}

/// 选择结果：含链与代币，便于主页面校验是否同链
class SwapTokenSelectionResult {
  final String chain;
  final SwapTokenOption token;

  const SwapTokenSelectionResult({required this.chain, required this.token});
}

/// 支持的链展示信息
const List<Map<String, String>> kChainsForSheet = [
  {'id': KnownTokens.bnbMainnet, 'name': 'BNB Chain'},
  {'id': KnownTokens.xLayer, 'name': 'X Layer'},
  {'id': KnownTokens.baseMainnet, 'name': 'Base'},
  {'id': KnownTokens.ethMainnet, 'name': 'Ethereum'},
];

class SwapTokenSheet extends StatefulWidget {
  final String walletAddress;
  final String chain;
  final String title;
  final String? excludeSymbol;
  /// 代币符号 -> USD 单价，用于列表展示价值（如 BNB/ETH/USDT）
  final Map<String, double>? tokenPrices;
  final void Function(SwapTokenOption) onSelect;

  const SwapTokenSheet({
    super.key,
    required this.walletAddress,
    required this.chain,
    this.title = '选择代币',
    this.excludeSymbol,
    this.tokenPrices,
    required this.onSelect,
  });

  @override
  State<SwapTokenSheet> createState() => _SwapTokenSheetState();
}

class _SwapTokenSheetState extends State<SwapTokenSheet> {
  final AlchemyService _alchemy = AlchemyService();
  List<SwapTokenOption> _tokens = [];
  bool _loading = true;
  String? _error;
  String _selectedChain = '';
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  /// 弹窗内拉取的 BNB/ETH/USDT 单价，用于有数量时代币价值展示（不依赖父组件传参）
  Map<String, double> _prices = {};

  static const Color _green = Color(0xFF00D1A7);
  static const Color _bnbYellow = Color(0xFFF3BA2F);

  static Color _iconColor(String symbol, String chain) {
    if (symbol == 'BNB') return const Color(0xFFF3BA2F);
    if (symbol == 'ETH') return const Color(0xFF627EEA);
    if (symbol == 'USDT') return const Color(0xFF26A17B);
    if (symbol == 'USDC') return const Color(0xFF3B7FED);
    if (symbol == 'DAI') return const Color(0xFFF4B731);
    if (symbol == 'BTCB' || symbol == 'WBTC') return const Color(0xFFF7931A);
    return Colors.grey;
  }

  @override
  void initState() {
    super.initState();
    _selectedChain = widget.chain == 'x-layer' ? KnownTokens.xLayer : widget.chain;
    _load();
    _fetchPrices();
    _searchController.addListener(() => setState(() {}));
  }

  Future<void> _fetchPrices() async {
    double parsePrice(dynamic data) {
      if (data is! Map) return 0;
      final v = data['price'];
      if (v == null) return 0;
      return v is num ? v.toDouble() : (double.tryParse(v.toString()) ?? 0);
    }
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 6), receiveTimeout: const Duration(seconds: 6)));
    double? ethP;
    double? bnbP;
    double? btcP;
    double? bbtPrice;
    try {
      final results = await Future.wait([
        dio.get('https://api.binance.com/api/v3/ticker/price', queryParameters: {'symbol': 'ETHUSDT'}),
        dio.get('https://api.binance.com/api/v3/ticker/price', queryParameters: {'symbol': 'BNBUSDT'}),
        dio.get('https://api.binance.com/api/v3/ticker/price', queryParameters: {'symbol': 'BTCUSDT'}),
        _fetchBbtPrice(),
      ]);
      ethP = parsePrice((results[0] as dynamic).data);
      bnbP = parsePrice((results[1] as dynamic).data);
      btcP = parsePrice((results[2] as dynamic).data);
      bbtPrice = results[3] as double?;
    } catch (_) {
      try {
        bbtPrice = await _fetchBbtPrice();
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() {
      _prices['USDT'] = 1.0;
      _prices['USDC'] = 1.0;
      _prices['DAI'] = 1.0;
      _prices['BUSD'] = 1.0;
      _prices['ETH'] = ethP ?? 0;
      _prices['BNB'] = bnbP ?? 0;
      _prices['BTCB'] = _prices['WBTC'] = btcP ?? 0;
      // BBT 优先用本次拉取，否则用父组件传入的 tokenPrices（闪兑页已从网关拉取）
      _prices['BBT'] = bbtPrice ?? widget.tokenPrices?['BBT'] ?? 0;
    });
  }

  Future<double?> _fetchBbtPrice() async {
    return CoinGeckoService.getBbtPriceFromBsc();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  String get _chainKey => _selectedChain == 'x-layer' ? KnownTokens.xLayer : _selectedChain;

  Future<void> _load() async {
    if (!AlchemyService.isAvailable || widget.walletAddress.isEmpty || !widget.walletAddress.startsWith('0x')) {
      setState(() {
        _tokens = _defaultTokens();
        _loading = false;
        _error = AlchemyService.isAvailable ? null : '未配置 Alchemy';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tracked = KnownTokens.getTrackedContractAddresses(_chainKey);
      final result = await _alchemy.getTokenBalances(widget.walletAddress, chain: _selectedChain, contractAddresses: tracked.isEmpty ? null : tracked);
      final nativeWei = await _alchemy.getNativeBalance(widget.walletAddress, chain: _selectedChain);
      if (!mounted) return;
      final nativeSym = _selectedChain == AlchemyService.bnbMainnet ? 'BNB' : 'ETH';
      final list = <SwapTokenOption>[
        SwapTokenOption(
          symbol: nativeSym,
          balanceWeiStr: nativeWei ?? '0',
          decimals: 18,
          contractAddress: null,
          formattedBalance: KnownTokens.formatBalanceDisplay(nativeWei ?? '0', 18, maxDecimals: 6),
          iconColor: _iconColor(nativeSym, _selectedChain),
        ),
      ];
      for (final t in result.tokenBalances) {
        final meta = KnownTokens.getMeta(_chainKey, t.contractAddress);
        if (meta == null) continue;
        list.add(SwapTokenOption(
          symbol: meta.symbol,
          balanceWeiStr: t.balanceWei.toString(),
          decimals: meta.decimals,
          contractAddress: meta.contractAddress,
          formattedBalance: KnownTokens.formatBalanceDisplay(t.balanceWei.toString(), meta.decimals, maxDecimals: 6),
          iconColor: _iconColor(meta.symbol, _selectedChain),
        ));
      }
      setState(() {
        _tokens = list;
        _loading = false;
        _error = result.error;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _tokens = _defaultTokens();
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  List<SwapTokenOption> _defaultTokens() {
    final nativeSym = _selectedChain == AlchemyService.bnbMainnet ? 'BNB' : 'ETH';
    return [
      SwapTokenOption(symbol: nativeSym, balanceWeiStr: '0', decimals: 18, contractAddress: null, formattedBalance: '0', iconColor: _iconColor(nativeSym, _selectedChain)),
      SwapTokenOption(symbol: 'USDT', balanceWeiStr: '0', decimals: _selectedChain == KnownTokens.bnbMainnet ? 18 : 6, contractAddress: _selectedChain == KnownTokens.bnbMainnet ? KnownTokens.usdtBsc : KnownTokens.usdtEth, formattedBalance: '0', iconColor: _iconColor('USDT', _selectedChain)),
      SwapTokenOption(symbol: 'BBT', balanceWeiStr: '0', decimals: 18, contractAddress: KnownTokens.bbtContract, formattedBalance: '0', iconColor: Colors.grey),
    ];
  }

  List<SwapTokenOption> get _filteredTokens {
    final q = _searchController.text.trim().toLowerCase();
    if (q.isEmpty) return _tokens;
    return _tokens.where((t) {
      if (t.symbol.toLowerCase().contains(q)) return true;
      final addr = t.contractAddress ?? '';
      if (addr.toLowerCase().contains(q)) return true;
      return false;
    }).toList();
  }

  String _shortAddress(SwapTokenOption t) {
    final a = t.contractAddress;
    if (a == null || a.isEmpty) return '0xeeeeee...eeeeeeee';
    if (a.length <= 16) return a;
    return '${a.substring(0, 8)}...${a.substring(a.length - 8)}';
  }

  String _usdValue(SwapTokenOption t) {
    // 优先使用弹窗内部实时拉取的价格（含 BBT），再回退到外部传入的参考价格
    final localPrice = _prices[t.symbol];
    final externalPrice = widget.tokenPrices?[t.symbol];
    final price = (localPrice != null && localPrice > 0)
        ? localPrice
        : externalPrice;
    if (price == null || price <= 0) return '\$0.00';
    final balance = double.tryParse(t.formattedBalance) ?? 0;
    if (balance <= 0) return '\$0.00';
    final value = balance * price;
    if (value >= 1) return '\$${value.toStringAsFixed(2)}';
    if (value >= 0.01) return '\$${value.toStringAsFixed(4)}';
    return '\$${value.toStringAsFixed(6)}';
  }

  @override
  Widget build(BuildContext context) {
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
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 12, 12),
              child: Row(
                children: [
                  Expanded(child: Text(widget.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black87))),
                  IconButton(icon: const Icon(Icons.close, size: 24), onPressed: () => Navigator.pop(context)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                controller: _searchController,
                focusNode: _searchFocus,
                decoration: InputDecoration(
                  hintText: '搜索代币名称、合约地址',
                  prefixIcon: Icon(Icons.search, color: Colors.grey.shade600, size: 22),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  isDense: true,
                ),
                style: const TextStyle(fontSize: 15),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: kChainsForSheet.map((c) {
                  final id = c['id']!;
                  final name = c['name']!;
                  final selected = _selectedChain == id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () async {
                        if (_selectedChain == id) return;
                        setState(() => _selectedChain = id);
                        await _load();
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? _bnbYellow.withOpacity(0.2) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: selected ? _bnbYellow : Colors.transparent, width: 1.5),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (id == KnownTokens.bnbMainnet) Icon(Icons.account_balance_wallet, size: 18, color: selected ? _bnbYellow : Colors.grey.shade600),
                            const SizedBox(width: 6),
                            Text(name, style: TextStyle(fontSize: 13, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: selected ? Colors.black87 : Colors.grey.shade700)),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
            else if (_error != null && _tokens.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(child: Text(_error!, style: TextStyle(color: Colors.grey[600], fontSize: 14), textAlign: TextAlign.center)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _filteredTokens.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
                  itemBuilder: (_, i) {
                    final t = _filteredTokens[i];
                    final disabled = widget.excludeSymbol != null && t.symbol == widget.excludeSymbol;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: disabled ? null : () {
                          widget.onSelect(t);
                          Navigator.pop(context, SwapTokenSelectionResult(chain: _selectedChain, token: t));
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Row(
                            children: [
                              TokenAvatar(symbol: t.symbol, iconUrl: KnownTokens.getLogoUrl(_selectedChain, t.contractAddress), iconColor: t.iconColor, size: 44),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.symbol, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: disabled ? Colors.grey : Colors.black87)),
                                    const SizedBox(height: 2),
                                    Text(_shortAddress(t), style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: 'monospace')),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(t.formattedBalance, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: disabled ? Colors.grey : Colors.black87)),
                                  const SizedBox(height: 2),
                                  Text(_usdValue(t), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
          ],
        ),
      ),
    );
  }
}
