import 'package:education/config/known_tokens.dart';
import 'package:education/core/cache/market_favorites_cache.dart';
import 'package:education/pages/market/models/market_item.dart';
import 'package:education/pages/profile/token_kline_page.dart';
import 'package:education/services/coingecko_service.dart';
import 'package:education/services/us_stock_service.dart';
import 'package:education/widgets/common/token_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

String _formatMoney(double? v) {
  if (v == null || v <= 0) return '--';
  if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(2)}B';
  if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(2)}M';
  if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(2)}K';
  return '\$${v.toStringAsFixed(2)}';
}

String _formatPrice(double? v) {
  if (v == null || v <= 0) return '--';
  if (v >= 1) return '\$${v.toStringAsFixed(2)}';
  if (v >= 0.0001) return '\$${v.toStringAsFixed(4)}';
  return '\$${v.toStringAsFixed(6)}';
}

/// BBT 风格行情 Tab：搜索栏 + 自选/Beta/大盘/美股 + 可排序列头 + 列表
/// - 自选：用户添加的币种
/// - Beta：币安链（BNB Chain）20 条代币，价格/市值经网关拉取；搜索在此 20 条中按名称/符号/合约筛选
/// - 大盘：市值排行（CoinGecko 动态 Top15，按市值排序）
/// - 美股：美股行情（Finnhub 经网关代理，失败时用 mock）
class MarketQuotesTab extends ConsumerStatefulWidget {
  const MarketQuotesTab({super.key});

  @override
  ConsumerState<MarketQuotesTab> createState() => _MarketQuotesTabState();
}

class _MarketQuotesTabState extends ConsumerState<MarketQuotesTab> {
  static const Color _green = Color(0xFF00D1A7);
  static const Color _red = Color(0xFFFF3B30);

  final TextEditingController _searchController = TextEditingController();
  int _categoryIndex = 0; // 0 自选 1 Beta 2 大盘 3 美股
  String _sortLeft = 'volume'; // volume | marketCap
  bool _sortLeftAsc = false;
  String _sortRight = 'price'; // price | change
  bool _sortRightAsc = false;

  List<String> _favorites = [];
  List<MarketItem> _list = [];
  bool _loading = true;
  bool _loadingPrices = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    _favorites = await MarketFavoritesCache.getFavorites();
    await _buildList();
    setState(() => _loading = false);
  }

  Future<void> _buildList() async {
    List<MarketItem> list;
    switch (_categoryIndex) {
      case 0:
        list = await _buildFavoritesList();
        break;
      case 1:
        list = MarketItem.betaList();
        break;
      case 2:
        list = await CoinGeckoService.fetchTop15ByMarketCap();
        break;
      case 3:
        list = await UsStockService.fetchUsStocks();
        break;
      default:
        list = [];
    }
    final query = _searchController.text.trim().toLowerCase();
    if (query.isNotEmpty) {
      list = list.where((e) {
        return e.symbol.toLowerCase().contains(query) ||
            (e.name?.toLowerCase().contains(query) ?? false) ||
            e.contractAddress.toLowerCase().contains(query);
      }).toList();
    }
    // 大盘、美股：固定按市值降序排列
    if ((_categoryIndex == 2 || _categoryIndex == 3) && list.isNotEmpty) {
      list.sort((a, b) => (b.marketCap ?? 0).compareTo(a.marketCap ?? 0));
    } else {
      _applySort(list);
    }
    if (mounted) setState(() => _list = list);
    _fetchPricesIfNeeded();
  }

  Future<List<MarketItem>> _buildFavoritesList() async {
    final items = <MarketItem>[];
    for (final key in _favorites) {
      final parts = key.split('|');
      if (parts.length != 2) continue;
      final chain = parts[0];
      final addr = parts[1];
      final meta = KnownTokens.getMeta(chain, addr);
      if (meta != null) {
        items.add(MarketItem(
          symbol: meta.symbol,
          chain: chain,
          contractAddress: meta.contractAddress,
          isToken: true,
          iconUrl: null,
        ));
      }
    }
    return items;
  }

  void _applySort(List<MarketItem> list) {
    list.sort((a, b) {
      int cmp = 0;
      if (_sortLeft == 'volume') {
        final va = a.volume ?? 0;
        final vb = b.volume ?? 0;
        cmp = va.compareTo(vb);
      } else {
        final va = a.marketCap ?? 0;
        final vb = b.marketCap ?? 0;
        cmp = va.compareTo(vb);
      }
      if (!_sortLeftAsc) cmp = -cmp;

      if (cmp != 0) return cmp;
      if (_sortRight == 'price') {
        final va = a.price ?? 0;
        final vb = b.price ?? 0;
        cmp = va.compareTo(vb);
      } else {
        final va = a.changePercent ?? 0;
        final vb = b.changePercent ?? 0;
        cmp = va.compareTo(vb);
      }
      if (!_sortRightAsc) cmp = -cmp;
      return cmp;
    });
  }

  Future<void> _fetchPricesIfNeeded() async {
    if (_list.isEmpty) return;
    final needPriceItems = _list.where((e) => e.isToken && e.price == null).toList();
    if (needPriceItems.isEmpty) return;
    setState(() => _loadingPrices = true);
    final updated = List<MarketItem>.from(_list);
    const batchSize = 3;
    for (int i = 0; i < needPriceItems.length; i += batchSize) {
      final batch = needPriceItems.skip(i).take(batchSize).toList();
      final results = await Future.wait(batch.map(_fetchCoinGeckoData));
      for (int j = 0; j < batch.length; j++) {
        final item = batch[j];
        final data = results[j];
        final idx = updated.indexWhere((e) => e.chain == item.chain && e.contractAddress == item.contractAddress);
        if (idx >= 0 && data != null) {
          updated[idx] = MarketItem(
            symbol: item.symbol,
            name: item.name,
            chain: item.chain,
            contractAddress: item.contractAddress,
            isToken: item.isToken,
            iconUrl: data.imageUrl ?? item.iconUrl,
            price: data.price ?? item.price,
            volume: data.volume24h ?? item.volume,
            marketCap: data.marketCap ?? item.marketCap,
            changePercent: data.changePercent24h ?? item.changePercent,
          );
        }
      }
      if (!mounted) return;
      setState(() => _list = List.from(updated));
    }
    if (mounted) setState(() => _loadingPrices = false);
  }

  Future<CoinGeckoContractData?> _fetchCoinGeckoData(MarketItem item) async {
    return CoinGeckoService.fetchCoinByContract(item.chain, item.contractAddress);
  }

  Future<void> _toggleFavorite(MarketItem item) async {
    if (!item.isToken) return;
    final isFav = MarketFavoritesCache.isFavorite(_favorites, item.chain, item.contractAddress);
    if (isFav) {
      await MarketFavoritesCache.remove(item.chain, item.contractAddress);
    } else {
      await MarketFavoritesCache.add(item.chain, item.contractAddress);
    }
    _favorites = await MarketFavoritesCache.getFavorites();
    await _buildList();
  }

  void _unfocusSearch() {
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchBar(),
        Expanded(
          child: GestureDetector(
            onTap: _unfocusSearch,
            behavior: HitTestBehavior.translucent,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildCategoryTabs(),
                _buildSortHeaders(),
                Expanded(
                  child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _list.isEmpty
                        ? Center(
                            child: Text(
                              _categoryIndex == 0 ? '暂无自选，从 Beta/大盘 添加' : '暂无数据',
                              style: TextStyle(color: Colors.grey[600], fontSize: 14),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _list.length,
                            itemBuilder: (_, i) => _MarketRow(
                              item: _list[i],
                              isFavorite: _list[i].isToken &&
                                  MarketFavoritesCache.isFavorite(
                                      _favorites, _list[i].chain, _list[i].contractAddress),
                              onTap: () {
                                _unfocusSearch();
                                _onTapItem(_list[i]);
                              },
                              onToggleFavorite: () => _toggleFavorite(_list[i]),
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(10),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (_) => _buildList(),
        decoration: InputDecoration(
          hintText: _categoryIndex == 1 ? '搜索币安链代币（名称/符号/合约）' : '搜索代币名称或合约地址',
          hintStyle: TextStyle(fontSize: 14, color: Colors.grey[600]),
          prefixIcon: Icon(Icons.search, size: 22, color: Colors.grey[600]),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildCategoryTabs() {
    const labels = ['自选', 'Beta', '大盘', '美股'];
    return Row(
      children: List.generate(4, (i) {
        final selected = _categoryIndex == i;
        return GestureDetector(
          onTap: () {
            setState(() {
              _categoryIndex = i;
              _loading = true;
            });
            _buildList().then((_) => setState(() => _loading = false));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? _green : Colors.transparent,
                  width: 2,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    color: selected ? Colors.black : Colors.grey[600],
                  ),
                ),
                if (i == 1) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: _green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSortHeaders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _sortHeader('交易额', _sortLeft == 'volume', _sortLeftAsc, () {
            setState(() {
              _sortLeft = 'volume';
              _sortLeftAsc = !_sortLeftAsc;
              _applySort(_list);
            });
          }),
          const SizedBox(width: 8),
          _sortHeader('市值', _sortLeft == 'marketCap', _sortLeftAsc, () {
            setState(() {
              _sortLeft = 'marketCap';
              _sortLeftAsc = !_sortLeftAsc;
              _applySort(_list);
            });
          }),
          const SizedBox(width: 16),
          Container(width: 1, height: 16, color: Colors.grey.shade300),
          const SizedBox(width: 16),
          const Spacer(),
          _sortHeader('价格', _sortRight == 'price', _sortRightAsc, () {
            setState(() {
              _sortRight = 'price';
              _sortRightAsc = !_sortRightAsc;
              _applySort(_list);
            });
          }),
          const SizedBox(width: 8),
          _sortHeader('涨跌幅', _sortRight == 'change', _sortRightAsc, () {
            setState(() {
              _sortRight = 'change';
              _sortRightAsc = !_sortRightAsc;
              _applySort(_list);
            });
          }),
        ],
      ),
    );
  }

  Widget _sortHeader(String label, bool active, bool asc, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[700],
              fontWeight: active ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
          Icon(
            asc ? Icons.arrow_drop_up : Icons.arrow_drop_down,
            size: 18,
            color: Colors.grey[600],
          ),
        ],
      ),
    );
  }

  void _onTapItem(MarketItem item) {
    if (item.isToken) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => TokenKlinePage(
            symbol: item.symbol,
            contractAddress: item.contractAddress,
            chain: item.chain,
          ),
        ),
      );
    }
  }
}

class _MarketRow extends StatelessWidget {
  final MarketItem item;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onToggleFavorite;

  const _MarketRow({
    required this.item,
    required this.isFavorite,
    required this.onTap,
    required this.onToggleFavorite,
  });

  static const Color _green = Color(0xFF00D1A7);
  static const Color _red = Color(0xFFFF3B30);

  @override
  Widget build(BuildContext context) {
    // 名称下：有 24h 成交额则显示「成交额 | 总市值」，没有则只显示「总市值」
    final parts = <String>[];
    if (item.volume != null && item.volume! > 0) {
      parts.add(_formatMoney(item.volume));
    }
    if (item.marketCap != null && item.marketCap! > 0) {
      parts.add(_formatMoney(item.marketCap));
    }
    final subtitleStr = parts.isEmpty ? '--' : parts.join(' | ');
    final priceStr = _formatPrice(item.price);
    final change = item.changePercent;
    final changeStr = change != null
        ? '${change >= 0 ? '+' : ''}${change.toStringAsFixed(2)}%'
        : '--';
    final changeColor = change != null ? (change >= 0 ? _green : _red) : Colors.grey;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                TokenAvatar(
                  symbol: item.symbol,
                  iconUrl: item.iconUrl ?? (item.isToken ? KnownTokens.getLogoUrl(item.chain, item.contractAddress) : null),
                  size: 44,
                  iconColor: _green,
                ),
                if (item.isToken)
                  Positioned(
                    right: -4,
                    bottom: -4,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: const Icon(Icons.currency_bitcoin, size: 10, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.displayName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitleStr,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ),
            ),
            if (item.isToken)
              IconButton(
                icon: Icon(
                  isFavorite ? Icons.star : Icons.star_border,
                  color: isFavorite ? _green : Colors.grey,
                  size: 22,
                ),
                onPressed: onToggleFavorite,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  priceStr,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  changeStr,
                  style: TextStyle(fontSize: 12, color: changeColor),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
