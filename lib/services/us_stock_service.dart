import 'package:dio/dio.dart';
import 'package:education/config/app_env.dart';
import 'package:education/pages/market/models/market_item.dart';

/// 美股行情：国外 API（Finnhub）经网关代理拉取，未配置代理或失败时退回本地 mock
class UsStockService {
  static String? get _proxyBase => currentEnv.walletProxyBaseUrl;

  static final Dio _dio = Dio();

  /// 拉取美股列表（价格、涨跌幅、市值、logo）。走网关代理时为实时数据，否则为 mock
  static Future<List<MarketItem>> fetchUsStocks() async {
    final base = _proxyBase;
    if (base == null || base.isEmpty) {
      return MarketItem.usStocksList();
    }
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '$base/finnhub/us-stocks',
        options: Options(responseType: ResponseType.json, validateStatus: (_) => true),
      );
      if (resp.statusCode != 200) {
        return MarketItem.usStocksList();
      }
      final data = resp.data;
      if (data == null) return MarketItem.usStocksList();
      final list = data['data'];
      if (list is! List) return MarketItem.usStocksList();
      final items = <MarketItem>[];
      for (final e in list) {
        if (e is! Map<String, dynamic>) continue;
        final symbol = e['symbol'] as String? ?? '';
        if (symbol.isEmpty) continue;
        final name = e['name'] as String?;
        final rawPrice = (e['price'] as num?)?.toDouble();
        final rawChange = (e['changePercent'] as num?)?.toDouble();
        final marketCap = (e['marketCap'] as num?)?.toDouble();
        final rawVolume = (e['volume'] as num?)?.toDouble();
        final logo = e['logo'] as String?;
        // 网关无法访问 Finnhub 时会返回 0，按无数据处理避免显示 $0.00
        final price = (rawPrice != null && rawPrice > 0) ? rawPrice : null;
        final changePercent = (rawChange != null) ? rawChange : null;
        final volume = (rawVolume != null && rawVolume > 0) ? rawVolume : null;
        items.add(MarketItem(
          symbol: symbol,
          name: name,
          chain: 'us-stock',
          contractAddress: symbol,
          isToken: false,
          iconUrl: logo?.isNotEmpty == true ? logo : null,
          price: price,
          volume: volume,
          marketCap: (marketCap != null && marketCap > 0) ? marketCap : null,
          changePercent: changePercent,
        ));
      }
      if (items.isEmpty) return MarketItem.usStocksList();
      // 网关连不上 Finnhub 时会返回全 0，一条有效价格都没有则用 mock 避免整页空
      final hasAnyPrice = items.any((e) => e.price != null && e.price! > 0);
      return hasAnyPrice ? items : MarketItem.usStocksList();
    } catch (_) {
      return MarketItem.usStocksList();
    }
  }
}
