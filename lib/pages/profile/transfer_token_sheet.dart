import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:education/config/app_config.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/services/alchemy_service.dart';
import 'package:education/widgets/common/empty_state_view.dart';
import 'package:education/widgets/common/token_avatar.dart';

/// 网络选项（与图二一致：BNB Chain 选中黄色，其余灰色）
class TransferNetworkOption {
  final String id;
  final String name;
  final Widget? icon;
  /// 对应 Alchemy 链 id，空表示暂不支持拉取
  final String? alchemyChain;
  /// 用于 KnownTokens 的链 key（如 x-layer）
  final String knownTokensChain;

  const TransferNetworkOption({
    required this.id,
    required this.name,
    this.icon,
    this.alchemyChain,
    required this.knownTokensChain,
  });
}

/// 代币选项（与 token 页展示一致：符号、格式化余额、USD）
class TransferTokenOption {
  final String symbol;
  final String name;
  final String balance;
  final String usdValue;
  final Widget? logo;
  final String balanceWeiStr;
  final int decimals;
  final String? contractAddress;
  final Color iconColor;

  const TransferTokenOption({
    required this.symbol,
    required this.name,
    this.balance = '0',
    this.usdValue = '\$0',
    this.logo,
    required this.balanceWeiStr,
    required this.decimals,
    this.contractAddress,
    this.iconColor = Colors.grey,
  });
}

/// 选择转账代币弹窗：标题、搜索、网络横向标签、代币列表（与 token 页一致）；切换网络时按链拉取代币
class TransferTokenSheet extends StatefulWidget {
  final String walletAddress;
  /// 再次打开弹窗时恢复选中的网络（如 'eth-mainnet'）
  final String initialNetworkId;
  /// 选择后回调：networkId, networkName, tokenSymbol, balanceWeiStr, decimals, contractAddress(null=原生), formattedBalance, formattedUsd
  final void Function(
    String networkId,
    String networkName,
    String tokenSymbol,
    String balanceWeiStr,
    int decimals,
    String? contractAddress,
    String formattedBalance,
    String formattedUsd,
  ) onSelect;

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
    TransferNetworkOption(id: 'bnb-mainnet', name: 'BNB Chain', alchemyChain: AlchemyService.bnbMainnet, knownTokensChain: KnownTokens.bnbMainnet),
    TransferNetworkOption(id: 'x-layer', name: 'X Layer', alchemyChain: 'x-layer', knownTokensChain: KnownTokens.xLayer),
    TransferNetworkOption(id: 'base-mainnet', name: 'Base', alchemyChain: 'base-mainnet', knownTokensChain: KnownTokens.baseMainnet),
    TransferNetworkOption(id: 'eth-mainnet', name: 'Ethereum', alchemyChain: AlchemyService.ethMainnet, knownTokensChain: KnownTokens.ethMainnet),
  ];

  static Color _iconColorForChain(String? alchemyChain) {
    if (alchemyChain == AlchemyService.bnbMainnet) return const Color(0xFFF3BA2F);
    if (alchemyChain == AlchemyService.ethMainnet) return const Color(0xFF627EEA);
    if (alchemyChain == 'base-mainnet') return const Color(0xFF0052FF);
    return Colors.grey;
  }

  late int _selectedNetworkIndex;
  List<TransferTokenOption> _tokens = [];
  List<TransferTokenOption> _filteredTokens = [];
  bool _loading = false;
  String? _loadError;
  double? _ethPrice;
  double? _bnbPrice;

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
    if (alchemyChain == AlchemyService.ethMainnet || alchemyChain == 'base-mainnet' || alchemyChain == 'x-layer') return 'ETH';
    return 'ETH';
  }

  Future<void> _fetchPrices() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10), receiveTimeout: const Duration(seconds: 10)));
    if (AppConfig.isDebug) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (_, __, ___) => true;
          return client;
        },
      );
    }
    double? ethPrice;
    double? bnbPrice;
    try {
      final ethResp = await dio.get('https://api.binance.com/api/v3/ticker/price', queryParameters: {'symbol': 'ETHUSDT'});
      final bnbResp = await dio.get('https://api.binance.com/api/v3/ticker/price', queryParameters: {'symbol': 'BNBUSDT'});
      final ethP = ethResp.data is Map ? (ethResp.data as Map)['price'] : null;
      final bnbP = bnbResp.data is Map ? (bnbResp.data as Map)['price'] : null;
      if (ethP != null) ethPrice = (ethP is num ? ethP : double.tryParse(ethP.toString()))?.toDouble();
      if (bnbP != null) bnbPrice = (bnbP is num ? bnbP : double.tryParse(bnbP.toString()))?.toDouble();
    } catch (_) {}
    if (ethPrice == null || bnbPrice == null) {
      try {
        final resp = await dio.get('https://api.coingecko.com/api/v3/simple/price', queryParameters: {'ids': 'ethereum,binancecoin', 'vs_currencies': 'usd'});
        final data = resp.data;
        if (data is Map<String, dynamic>) {
          final e = data['ethereum'];
          final b = data['binancecoin'];
          if (e is num) ethPrice = e.toDouble();
          else if (e is Map && e['usd'] is num) ethPrice = (e['usd'] as num).toDouble();
          if (b is num) bnbPrice = b.toDouble();
          else if (b is Map && b['usd'] is num) bnbPrice = (b['usd'] as num).toDouble();
        }
      } catch (_) {}
    }
    if (ethPrice == null) ethPrice = 3500;
    if (bnbPrice == null) bnbPrice = 600;
    if (mounted) {
      setState(() {
        _ethPrice = ethPrice;
        _bnbPrice = bnbPrice;
      });
    }
  }

  String _tokenValueUsd(String chain, String symbol, BigInt balanceWei, int decimals) {
    final isBnb = chain == AlchemyService.bnbMainnet;
    final price = isBnb ? _bnbPrice : _ethPrice;
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

  Future<void> _loadTokensForCurrentNetwork() async {
    final net = _networks[_selectedNetworkIndex];
    final chain = net.alchemyChain;
    final chainKey = net.knownTokensChain;
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
      final nativeSym = _nativeSymbolForChain(chain);
      final iconColor = _iconColorForChain(chain);
      setState(() {
        _tokens = [
          TransferTokenOption(
            symbol: nativeSym,
            name: nativeSym,
            balance: '0',
            usdValue: '\$0',
            balanceWeiStr: '0',
            decimals: 18,
            contractAddress: null,
            iconColor: iconColor,
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
      await _fetchPrices();
      if (!mounted) return;
      final tracked = KnownTokens.getTrackedContractAddresses(chainKey);
      final balanceResult = await _alchemy.getTokenBalances(addr, chain: chain, contractAddresses: tracked.isEmpty ? null : tracked);
      final nativeBalance = await _alchemy.getNativeBalance(addr, chain: chain);
      if (!mounted) return;

      // Build native + known tokens only (same as token list page)
      final list = <TransferTokenOption>[];
      final nativeSym = _nativeSymbolForChain(chain);
      final nativeWei = nativeBalance ?? '0';
      final nativeWeiBig = BigInt.tryParse(nativeWei) ?? BigInt.zero;
      final nativeFormatted = KnownTokens.formatBalanceDisplay(nativeWei, 18, maxDecimals: 6);
      final nativeUsd = _tokenValueUsd(chain, nativeSym, nativeWeiBig, 18);
      list.add(TransferTokenOption(
        symbol: nativeSym,
        name: nativeSym,
        balance: nativeFormatted,
        usdValue: nativeUsd,
        balanceWeiStr: nativeWei,
        decimals: 18,
        contractAddress: null,
        iconColor: _iconColorForChain(chain),
      ));
      for (final t in balanceResult.tokenBalances) {
        final meta = KnownTokens.getMeta(chainKey, t.contractAddress);
        if (meta == null) continue;
        final weiStr = t.balanceWei.toString();
        final formatted = KnownTokens.formatBalanceDisplay(weiStr, meta.decimals, maxDecimals: 6);
        final usd = _tokenValueUsd(chain, meta.symbol, t.balanceWei, meta.decimals);
        list.add(TransferTokenOption(
          symbol: meta.symbol,
          name: meta.symbol,
          balance: formatted,
          usdValue: usd,
          balanceWeiStr: weiStr,
          decimals: meta.decimals,
          contractAddress: meta.contractAddress,
          iconColor: Colors.grey,
        ));
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
                      widget.onSelect(
                        network.id,
                        network.name,
                        t.symbol,
                        t.balanceWeiStr,
                        t.decimals,
                        t.contractAddress,
                        t.balance,
                        t.usdValue,
                      );
                      Navigator.pop(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Row(
                        children: [
                          t.logo ??
                              TokenAvatar(
                                symbol: t.symbol,
                                iconUrl: KnownTokens.getLogoUrl(_networks[_selectedNetworkIndex].knownTokensChain, t.contractAddress),
                                iconColor: t.iconColor,
                                size: 40,
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
                              const SizedBox(height: 2),
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
