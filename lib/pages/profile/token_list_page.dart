import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/services/alchemy_service.dart';
import 'package:education/pages/profile/token_transfer_page.dart';
import 'package:education/pages/profile/receive_token_page.dart';
import 'package:education/pages/profile/quick_buy_swap_page.dart';
import 'package:education/widgets/common/empty_state_view.dart';

/// 网络选项（与 Alchemy 链标识对应）
class _NetworkOption {
  final String id;
  final String name;
  final Color iconColor;
  final IconData icon;

  const _NetworkOption({
    required this.id,
    required this.name,
    required this.iconColor,
    this.icon = Icons.circle,
  });
}

/// 个人中心 - 代币页（按参考图布局：顶部网络选择、余额、四个操作、代币/NFT 标签、代币列表）
class TokenListPage extends StatefulWidget {
  final String walletAddress;
  final String chain;
  /// 为 true 时进入页面直接选中 NFT 标签（个人中心点 NFT 入口用）
  final bool initialTabNft;

  const TokenListPage({
    super.key,
    required this.walletAddress,
    this.chain = AlchemyService.bnbMainnet,
    this.initialTabNft = false,
  });

  @override
  State<TokenListPage> createState() => _TokenListPageState();
}

class _TokenListPageState extends State<TokenListPage> {
  final AlchemyService _alchemy = AlchemyService();

  /// 仅显示支持以太坊（EVM）的网络及 Solana；当前地址为 EVM 格式，仅在这些链上可查余额/NFT
  static const List<_NetworkOption> _networks = [
    _NetworkOption(id: AlchemyService.ethMainnet, name: 'Ethereum', iconColor: Color(0xFF627EEA), icon: Icons.diamond_outlined),
    _NetworkOption(id: AlchemyService.bnbMainnet, name: 'BNB Chain', iconColor: Color(0xFFF3BA2F), icon: Icons.currency_bitcoin),
    _NetworkOption(id: 'base-mainnet', name: 'Base', iconColor: Color(0xFF0052FF), icon: Icons.circle),
    _NetworkOption(id: 'x-layer', name: 'X Layer', iconColor: Color(0xFF000000), icon: Icons.layers),
    _NetworkOption(id: 'solana', name: 'Solana', iconColor: Color(0xFF9945FF), icon: Icons.link),
  ];

  late String _currentChain;
  bool _loading = true;
  String? _error;
  List<TokenBalanceItem> _tokens = [];
  String? _nativeBalance;
  double? _totalUsd;
  double? _ethPrice;
  double? _bnbPrice;
  late bool _tabTokens;
  List<AlchemyNftItem> _nfts = [];
  bool _nftLoading = false;
  String? _nftError;

  @override
  void initState() {
    super.initState();
    _tabTokens = !widget.initialTabNft;
    _currentChain = widget.chain;
    _load();
    if (widget.initialTabNft) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _nfts.isEmpty && !_nftLoading) _loadNfts();
      });
    }
  }

  Future<void> _loadNfts() async {
    if (!AlchemyService.isAvailable) return;
    setState(() {
      _nftLoading = true;
      _nftError = null;
    });
    try {
      final result = await _alchemy.getNfts(
        widget.walletAddress,
        chain: _currentChain,
      );
      if (!mounted) return;
      setState(() {
        _nftLoading = false;
        _nftError = result.error;
        _nfts = result.nfts;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _nftLoading = false;
          _nftError = e.toString();
          _nfts = [];
        });
      }
    }
  }

  Future<void> _load() async {
    if (!AlchemyService.isAvailable) {
      setState(() {
        _loading = false;
        _error = '未配置 Alchemy API Key';
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final balanceResult = await _alchemy.getTokenBalances(
        widget.walletAddress,
        chain: _currentChain,
      );
      final trackedAddrs = KnownTokens.getTrackedContractAddresses(_currentChain);
      AlchemyTokenBalancesResult? trackedResult;
      if (trackedAddrs.isNotEmpty) { 
        trackedResult = await _alchemy.getTokenBalances(
          widget.walletAddress,
          chain: _currentChain,
          contractAddresses: trackedAddrs,
        );
      }
      final native = await _alchemy.getNativeBalance(
        widget.walletAddress,
        chain: _currentChain,
      );
      if (!mounted) return;
      final Map<String, TokenBalanceItem> byAddr = {};
      for (final t in balanceResult.tokenBalances) {
        byAddr[t.contractAddress.toLowerCase()] = t;
      }
      if (trackedResult != null && trackedResult.error == null) {
        for (final t in trackedResult.tokenBalances) {
          byAddr[t.contractAddress.toLowerCase()] = t;
        }
      }
      final List<TokenBalanceItem> merged = [];
      for (final meta in KnownTokens.byChain[_currentChain] ?? []) {
        merged.add(byAddr[meta.addressLower] ?? TokenBalanceItem(contractAddress: meta.contractAddress, tokenBalance: '0x0'));
      }
      ({double total, double ethPrice, double bnbPrice})? priceResult;
      try {
        priceResult = await _fetchPricesAndTotal(native, merged, _currentChain);
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = balanceResult.error;
        _tokens = merged;
        _nativeBalance = native;
        _totalUsd = priceResult?.total;
        _ethPrice = priceResult?.ethPrice;
        _bnbPrice = priceResult?.bnbPrice;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// 拉取价格并计算总 USD，同时返回价格供每行代币估值用
  Future<({double total, double ethPrice, double bnbPrice})?> _fetchPricesAndTotal(String? nativeWei, List<TokenBalanceItem> tokens, String chain) async {
    if (chain == 'solana') return null;
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));
    double? ethPrice;
    double? bnbPrice;
    try {
      final ethResp = await dio.get<Map<String, dynamic>>(
        'https://api.binance.com/api/v3/ticker/price',
        queryParameters: {'symbol': 'ETHUSDT'},
      );
      final bnbResp = await dio.get<Map<String, dynamic>>(
        'https://api.binance.com/api/v3/ticker/price',
        queryParameters: {'symbol': 'BNBUSDT'},
      );
      final ethP = ethResp.data?['price'];
      final bnbP = bnbResp.data?['price'];
      if (ethP != null) ethPrice = (ethP is num ? ethP : double.tryParse(ethP.toString()))?.toDouble();
      if (bnbP != null) bnbPrice = (bnbP is num ? bnbP : double.tryParse(bnbP.toString()))?.toDouble();
    } catch (_) {}
    if (ethPrice == null || bnbPrice == null) {
      try {
        final resp = await dio.get<Map<String, dynamic>>(
          'https://api.coingecko.com/api/v3/simple/price',
          queryParameters: {'ids': 'ethereum,binancecoin,tether', 'vs_currencies': 'usd'},
        );
        final data = resp.data;
        if (data != null) {
          final eth = (data['ethereum'] as Map<String, dynamic>?)?['usd'];
          final bnb = (data['binancecoin'] as Map<String, dynamic>?)?['usd'];
          if (eth != null) ethPrice = (eth as num).toDouble();
          if (bnb != null) bnbPrice = (bnb as num).toDouble();
        }
      } catch (_) {}
    }
    const double fallbackEth = 3500;
    const double fallbackBnb = 600;
    if (ethPrice == null) ethPrice = fallbackEth;
    if (bnbPrice == null) bnbPrice = fallbackBnb;
    const usdtPrice = 1.0;
    final isBnb = chain == AlchemyService.bnbMainnet;
    final nativePrice = isBnb ? bnbPrice! : ethPrice!;
    double total = 0;
    if (nativeWei != null && nativeWei.isNotEmpty) {
      final wei = BigInt.tryParse(nativeWei) ?? BigInt.zero;
      total += wei.toDouble() / 1e18 * nativePrice;
    }
    for (final t in tokens) {
      final meta = KnownTokens.getMeta(chain, t.contractAddress);
      if (meta == null) continue;
      final amount = t.balanceWei.toDouble() / (BigInt.from(10).pow(meta.decimals).toDouble());
      if (meta.symbol == 'USDT') total += amount * usdtPrice;
    }
    return (total: total, ethPrice: ethPrice!, bnbPrice: bnbPrice!);
  }

  String get _nativeSymbol {
    if (_currentChain == AlchemyService.bnbMainnet) return 'BNB';
    if (_currentChain == AlchemyService.ethMainnet) return 'ETH';
    return 'ETH';
  }

  _NetworkOption get _currentNetwork =>
      _networks.firstWhere(
        (n) => n.id == _currentChain,
        orElse: () => _networks[1],
      );

  void _showNetworkSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        final maxH = MediaQuery.of(ctx).size.height * 0.5;
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxH),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '请选择网络',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: Colors.grey.shade300, indent: 20, endIndent: 20),
                Flexible(
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: _networks.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade300, indent: 72, endIndent: 20),
                    itemBuilder: (_, i) {
                      final n = _networks[i];
                      final selected = n.id == _currentChain;
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: n.iconColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(n.icon, color: n.iconColor, size: 22),
                        ),
                        title: Text(
                          n.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check, color: Color(0xFF00D1A7), size: 24)
                            : null,
                    onTap: () {
                      if (n.id != 'solana') {
                        setState(() => _currentChain = n.id);
                        _load();
                        if (!_tabTokens) _loadNfts();
                      }
                      Navigator.pop(ctx);
                    },
                      );
                    },
                  ),
                ),
                SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
              ],
            ),
          ),
        );
      },
    );
  }

  static const Color _bgDark = Color(0xFF121212);
  static const Color _cardDark = Color(0xFF1E1E1E);
  static const Color _green = Color(0xFF00D1A7);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgDark,
      appBar: AppBar(
        backgroundColor: _bgDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        title: GestureDetector(
          onTap: _showNetworkSheet,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _cardDark,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: _currentNetwork.iconColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_currentNetwork.icon, color: _currentNetwork.iconColor, size: 16),
                ),
                const SizedBox(width: 8),
                Text(
                  _currentNetwork.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.keyboard_arrow_down, color: Colors.white70, size: 20),
              ],
            ),
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 余额（有资产时显示 CoinGecko 估算总价）
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Text(
              _totalUsd != null
                  ? '${_totalUsd!.toStringAsFixed(2)} USD'
                  : '0 USD',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          // 四个操作按钮（按钮之间间距与左右边距一致）
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _actionButton(Icons.arrow_upward, '转账', () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                    builder: (_) => TokenTransferPage(walletAddress: widget.walletAddress),
                  ),
                  );
                }),
                _actionButton(Icons.arrow_downward, '接收', () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReceiveTokenPage(
                        walletAddress: widget.walletAddress,
                        initialChain: _currentChain,
                      ),
                    ),
                  );
                }),
                _actionButton(Icons.swap_horiz, '闪兑', () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => QuickBuySwapPage(
                        walletAddress: widget.walletAddress,
                        chain: _currentChain,
                      ),
                    ),
                  );
                }),
                _actionButton(Icons.history, '交易历史', () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('交易历史功能开发中')));
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // 白色区域：Tab + 列表
          Expanded(
            child: Container(
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 代币 / NFT 标签
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Row(
                      children: [
                        _tab('代币', _tabTokens, () => setState(() => _tabTokens = true)),
                        const SizedBox(width: 24),
                        _tab('NFT', !_tabTokens, () {
                          setState(() => _tabTokens = false);
                          if (_nfts.isEmpty && !_nftLoading) _loadNfts();
                        }),
                      ],
                    ),
                  ),
                  // 代币 / NFT 列表
                  Expanded(
                    child: _tabTokens
                        ? (_loading
                            ? const Center(child: CircularProgressIndicator(color: _green))
                            : _error != null
                                ? _errorBody()
                                : _tokenListBody())
                        : (_nftLoading
                            ? const Center(child: CircularProgressIndicator(color: _green))
                            : _nftError != null
                                ? _nftErrorBody()
                                : _nftListBody()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton(IconData icon, String label, VoidCallback onTap) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: _cardDark,
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
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _tab(String label, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black87 : Colors.grey,
              fontSize: 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(
              color: selected ? _green : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _load,
              style: FilledButton.styleFrom(backgroundColor: _green),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nftErrorBody() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _nftError!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[600], fontSize: 14),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loadNfts,
              style: FilledButton.styleFrom(backgroundColor: _green),
              child: const Text('重试'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _nftListBody() {
    if (_nfts.isEmpty) {
      return const EmptyStateView();
    }
    return RefreshIndicator(
      onRefresh: _loadNfts,
      color: _green,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: _nfts.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (_, i) => _nftRow(_nfts[i]),
      ),
    );
  }

  Widget _nftRow(AlchemyNftItem nft) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: nft.imageUrl != null && nft.imageUrl!.isNotEmpty
                ? Image.network(
                    nft.imageUrl!,
                    width: 48,
                    height: 48,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _nftPlaceholder(),
                  )
                : _nftPlaceholder(),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nft.name ?? 'NFT #${nft.tokenId}',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (nft.collectionName != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    nft.collectionName!,
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _nftPlaceholder() => Container(
        width: 48,
        height: 48,
        color: Colors.grey[200],
        child: const Icon(Icons.image, color: Colors.grey),
      );

  /// 当前链原生币单价（USD）
  double? get _nativePriceUsd {
    if (_currentChain == AlchemyService.bnbMainnet) return _bnbPrice;
    return _ethPrice;
  }

  /// 单一代币数量折合 USD 字符串（用于列表行）
  String _tokenValueUsd(String symbol, BigInt balanceWei, int decimals) {
    final price = _nativePriceUsd;
    if (price == null) return '\$0';
    if (symbol == 'USDT') {
      final amount = balanceWei.toDouble() / BigInt.from(10).pow(decimals).toDouble();
      return '\$${amount.toStringAsFixed(2)}';
    }
    if (symbol == 'BNB' || symbol == 'ETH') {
      final amount = balanceWei.toDouble() / 1e18;
      return '\$${(amount * price).toStringAsFixed(2)}';
    }
    return '\$0';
  }

  Widget _tokenListBody() {
    final list = <Widget>[];
    if (_nativeBalance != null) {
      final wei = BigInt.tryParse(_nativeBalance!) ?? BigInt.zero;
      final valueUsd = _tokenValueUsd(_nativeSymbol, wei, 18);
      list.add(_tokenRow(
        symbol: _nativeSymbol,
        amount: KnownTokens.formatBalanceDisplay(_nativeBalance!, 18, maxDecimals: 6),
        valueUsd: valueUsd,
        iconColor: _currentNetwork.iconColor,
      ));
    }
    for (final t in _tokens) {
      final meta = KnownTokens.getMeta(_currentChain, t.contractAddress);
      final symbol = meta?.symbol ?? '${t.contractAddress.substring(0, 6)}...';
      final amount = meta != null
          ? KnownTokens.formatBalanceDisplay(t.balanceWei.toString(), meta.decimals, maxDecimals: 6)
          : t.balanceWei.toString();
      final valueUsd = meta != null
          ? _tokenValueUsd(meta.symbol, t.balanceWei, meta.decimals)
          : '\$0';
      list.add(_tokenRow(
        symbol: symbol,
        amount: amount,
        valueUsd: valueUsd,
        iconColor: Colors.grey,
      ));
    }
    if (list.isEmpty) {
      return const EmptyStateView();
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: _green,
      backgroundColor: Colors.white,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        itemCount: list.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey[200]),
        itemBuilder: (_, i) => list[i],
      ),
    );
  }

  Widget _tokenRow({
    required String symbol,
    required String amount,
    required String valueUsd,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                symbol.length > 4 ? symbol.substring(0, 2) : symbol,
                style: TextStyle(
                  color: iconColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              symbol,
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                valueUsd,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
