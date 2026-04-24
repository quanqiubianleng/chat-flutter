import 'package:dio/dio.dart';
import 'package:education/config/app_config.dart';
import 'package:education/config/app_env.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/pages/market/models/market_item.dart';

/// CoinGecko 公开 API：市值排行、按链+合约查单币（无需 API Key）
/// 统一走「Flutter → 服务器 → 第三方」：配置 walletProxyBaseUrl 时只请求网关，由网关转发 CoinGecko；未配置时直连
class CoinGeckoService {
  static const String _directBaseUrl = 'https://api.coingecko.com/api/v3';
  static String? get _proxyBase => currentEnv.walletProxyBaseUrl;
  static String get _baseUrl =>
      (_proxyBase != null && _proxyBase!.isNotEmpty) ? _proxyBase! : _directBaseUrl;

  static Dio? _dio;
  static Dio get _client {
    _dio ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    return _dio!;
  }

  /// 链 ID -> CoinGecko asset_platform_id
  static String? platformIdFromChain(String chain) {
    switch (chain) {
      case KnownTokens.bnbMainnet:
        return 'binance-smart-chain';
      case KnownTokens.ethMainnet:
        return 'ethereum';
      case KnownTokens.baseMainnet:
        return 'base';
      case KnownTokens.xLayer:
        return 'ethereum'; // X Layer 部分代币在 CoinGecko 用 ethereum 可查到
      default:
        return null;
    }
  }

  /// 网关 wallet proxy 基地址：优先 walletProxyBaseUrl，否则用 reqUrl + /v1/wallet/proxy
  static String? get _walletProxyBase {
    if (_proxyBase != null && _proxyBase!.isNotEmpty) return _proxyBase;
    final base = AppConfig.reqUrl.replaceFirst(RegExp(r'/$'), '');
    if (base.isEmpty) return null;
    return '$base/v1/wallet/proxy';
  }

  /// BBT 从币安链 DEX 池子取价：客户端 → 网关 → BSC PancakeSwap
  static Future<double?> _fetchBbtPriceFromGateway() async {
    final base = _walletProxyBase;
    if (base == null || base.isEmpty) return null;
    try {
      final resp = await _client.get<Map<String, dynamic>>(
        '$base/bbt/price',
        options: Options(responseType: ResponseType.json, validateStatus: (_) => true),
      );
      final data = resp.data;
      if (data == null || resp.statusCode != 200) return null;
      // 兼容网关统一包装：{ code, msg, data: { price } }
      final payload = data['data'] as Map<String, dynamic>? ?? data;
      final p = payload['price'];
      if (p == null) return null;
      if (p is num) return p.toDouble();
      if (p is String) return double.tryParse(p);
      return null;
    } catch (_) {
      return null;
    }
  }

  /// 闪兑/快速买入专用：只从网关拉 BBT 价格（币安链 DEX），与 getTokenUsdPrice 并行可用
  static Future<double?> getBbtPriceFromBsc() async {
    return _fetchBbtPriceFromGateway();
  }

  /// 仅获取某代币 USD 单价（便于在闪兑/代币列表等处复用）
  /// BBT 只走网关币安链 DEX，不请求第三方
  static Future<double?> getTokenUsdPrice(String chain, String contractAddress) async {
    final addr = contractAddress.trim().toLowerCase();
    if (addr == KnownTokens.bbtContract.toLowerCase()) {
      return _fetchBbtPriceFromGateway();
    }
    final data = await fetchCoinByContract(chain, contractAddress);
    return data?.price;
  }

  /// 按链+合约地址获取单代币行情（价格、市值、24h 量、24h 涨跌幅、图标）
  /// BBT 只走网关币安链，不请求第三方
  static Future<CoinGeckoContractData?> fetchCoinByContract(String chain, String contractAddress) async {
    final addr = contractAddress.trim().toLowerCase();
    if (addr == KnownTokens.bbtContract.toLowerCase()) {
      final price = await _fetchBbtPriceFromGateway();
      if (price != null) {
        return CoinGeckoContractData(price: price, marketCap: null, volume24h: null, changePercent24h: null, imageUrl: null);
      }
      return null;
    }
    final platform = platformIdFromChain(chain);
    if (platform == null) return null;
    if (!addr.startsWith('0x')) return null;
    final useProxy = _proxyBase != null && _proxyBase!.isNotEmpty;
    try {
      final url = useProxy
          ? '$_baseUrl/coingecko/contract?platform=${Uri.encodeComponent(platform)}&address=${Uri.encodeComponent(addr)}'
          : '$_directBaseUrl/coins/$platform/contract/$addr';
      final resp = await _client.get<Map<String, dynamic>>(url);
      final data = resp.data;
      if (data == null) return null;
      return CoinGeckoContractData.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  /// 获取市值前 15 的代币（价格、市值、24h 涨跌幅、图标等）
  /// 配置了 walletProxyBaseUrl 时只请求网关，由网关请求 CoinGecko（统一经服务器）
  static Future<List<MarketItem>> fetchTop15ByMarketCap() async {
    const queryParams = {
      'vs_currency': 'usd',
      'order': 'market_cap_desc',
      'per_page': 15,
      'page': 1,
      'sparkline': false,
    };
    try {
      final useProxy = _proxyBase != null && _proxyBase!.isNotEmpty;
      final path = useProxy ? '/coingecko/markets' : '/coins/markets';
      final resp = await _client.get<dynamic>(
        useProxy ? '$_baseUrl$path' : '$_directBaseUrl$path',
        queryParameters: queryParams,
        options: Options(responseType: ResponseType.json, validateStatus: (_) => true),
      );
      final list = _parseMarketsResponse(resp);
      return list ?? [];
    } catch (_) {
      return [];
    }
  }

  static List<MarketItem>? _parseMarketsResponse(Response<dynamic> resp) {
    if (resp.statusCode != 200) return null;
    final data = resp.data;
    if (data is! List || data.isEmpty) return null;
    final result = <MarketItem>[];
    for (final e in data) {
      if (e is! Map<String, dynamic>) continue;
      try {
        result.add(_parseItem(e));
      } catch (_) {
        continue;
      }
    }
    return result.isEmpty ? null : result;
  }

  static MarketItem _parseItem(Map<String, dynamic> m) {
    final symbol = (m['symbol'] as String? ?? '?').toUpperCase();
    final name = m['name'] as String?;
    final image = _imageUrlFromMarkets(m);
    final price = (m['current_price'] as num?)?.toDouble();
    final marketCap = (m['market_cap'] as num?)?.toDouble();
    final totalVolume = (m['total_volume'] as num?)?.toDouble();
    final changePercent = (m['price_change_percentage_24h'] as num?)?.toDouble();
    final id = m['id'] as String? ?? symbol.toLowerCase();
    return MarketItem(
      symbol: symbol,
      name: name,
      chain: 'coingecko',
      contractAddress: id,
      isToken: false,
      iconUrl: image,
      price: price,
      volume: totalVolume,
      marketCap: marketCap,
      changePercent: changePercent,
    );
  }

  /// /coins/markets 返回的 image 可能是 URL 字符串，或 { thumb, small, large } 对象
  /// 若 API 未返回（如经网关后缺失），用大盘常见币 id 兜底
  static String? _imageUrlFromMarkets(Map<String, dynamic> m) {
    try {
      final image = m['image'];
      if (image is String && image.isNotEmpty) return image;
      if (image is Map) {
        final url = image['large'] ?? image['small'] ?? image['thumb'];
        if (url is String && url.isNotEmpty) return url;
      }
    } catch (_) {}
    final id = m['id'] as String?;
    if (id != null && id.isNotEmpty) return _topMarketCoinImageFallback[id.toLowerCase()];
    return null;
  }

  /// 大盘市值前常见币 id -> CoinGecko 图标 URL（API 未返回 image 时兜底）
  static const Map<String, String> _topMarketCoinImageFallback = {
    'bitcoin': 'https://coin-images.coingecko.com/coins/images/1/large/bitcoin.png',
    'ethereum': 'https://coin-images.coingecko.com/coins/images/279/large/ethereum.png',
    'tether': 'https://coin-images.coingecko.com/coins/images/325/large/Tether.png',
    'binancecoin': 'https://coin-images.coingecko.com/coins/images/825/large/bnb-icon2_2x.png',
    'solana': 'https://coin-images.coingecko.com/coins/images/4128/large/solana.png',
    'usd-coin': 'https://coin-images.coingecko.com/coins/images/6319/large/usdc.png',
    'xrp': 'https://coin-images.coingecko.com/coins/images/44/large/xrp-symbol-white-128.png',
    'dogecoin': 'https://coin-images.coingecko.com/coins/images/5/large/dogecoin.png',
    'toncoin': 'https://coin-images.coingecko.com/coins/images/17980/large/ton_symbol.png',
    'tron': 'https://coin-images.coingecko.com/coins/images/1094/large/tron-logo.png',
    'cardano': 'https://coin-images.coingecko.com/coins/images/975/large/cardano.png',
    'avalanche-2': 'https://coin-images.coingecko.com/coins/images/12559/large/Avalanche_Circle_RedWhite_Trans.png',
    'shiba-inu': 'https://coin-images.coingecko.com/coins/images/11939/large/shiba.png',
    'chainlink': 'https://coin-images.coingecko.com/coins/images/877/large/chainlink-new-logo.png',
    'polkadot': 'https://coin-images.coingecko.com/coins/images/12171/large/polkadot.png',
    'wrapped-bitcoin': 'https://coin-images.coingecko.com/coins/images/7598/large/wrapped_bitcoin_wbtc.png',
    'dai': 'https://coin-images.coingecko.com/coins/images/9956/large/Badge_Dai.png',
    'litecoin': 'https://coin-images.coingecko.com/coins/images/2/large/litecoin.png',
    'uniswap': 'https://coin-images.coingecko.com/coins/images/12504/large/uniswap-logo.png',
    'bitcoin-cash': 'https://coin-images.coingecko.com/coins/images/780/large/bitcoin-cash-circle.png',
  };
}

/// CoinGecko 按合约接口返回的行情数据
class CoinGeckoContractData {
  final double? price;
  final double? marketCap;
  final double? volume24h;
  final double? changePercent24h;
  final String? imageUrl;

  const CoinGeckoContractData({
    this.price,
    this.marketCap,
    this.volume24h,
    this.changePercent24h,
    this.imageUrl,
  });

  static CoinGeckoContractData fromJson(Map<String, dynamic> m) {
    final marketData = m['market_data'] as Map<String, dynamic>?;
    double? price;
    double? marketCap;
    double? volume24h;
    double? changePercent24h;
    if (marketData != null) {
      final cp = marketData['current_price'];
      if (cp is Map && cp.containsKey('usd')) {
        price = (cp['usd'] as num?)?.toDouble();
      }
      final mc = marketData['market_cap'];
      if (mc is Map && mc.containsKey('usd')) {
        marketCap = (mc['usd'] as num?)?.toDouble();
      }
      final tv = marketData['total_volume'];
      if (tv is Map && tv.containsKey('usd')) {
        volume24h = (tv['usd'] as num?)?.toDouble();
      }
      changePercent24h = (marketData['price_change_percentage_24h'] as num?)?.toDouble();
    }
    String? imageUrl;
    final image = m['image'] as Map<String, dynamic>?;
    if (image != null) {
      imageUrl = image['small'] as String? ?? image['large'] as String? ?? image['thumb'] as String?;
    }
    return CoinGeckoContractData(
      price: price,
      marketCap: marketCap,
      volume24h: volume24h,
      changePercent24h: changePercent24h,
      imageUrl: imageUrl,
    );
  }
}
