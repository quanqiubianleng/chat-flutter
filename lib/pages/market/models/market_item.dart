import 'package:education/config/known_tokens.dart';

/// 行情列表单项：代币或美股等
class MarketItem {
  final String symbol;
  final String? name;
  final String chain;
  final String contractAddress;
  /// 是否为链上代币（false 表示大盘/美股等，不可加自选）
  final bool isToken;
  /// 代币图标 URL（如 CoinGecko 返回的 image；为空时用 KnownTokens 或首字母）
  final String? iconUrl;
  final double? price;
  final double? volume;
  final double? marketCap;
  final double? changePercent;

  const MarketItem({
    required this.symbol,
    this.name,
    required this.chain,
    required this.contractAddress,
    this.isToken = true,
    this.iconUrl,
    this.price,
    this.volume,
    this.marketCap,
    this.changePercent,
  });

  String get displayName => name ?? symbol;

  /// 唯一 key：chain|address
  String get key => '${chain}|${contractAddress.toLowerCase()}';

  /// Beta 分类：币安链（BNB Chain）固定 20 个代币，价格/市值经网关拉取；搜索在此 20 条中按名称/符号/合约筛选
  static const int _betaCount = 20;

  /// 币安链 Beta 展示用：symbol + 合约地址（与 KnownTokens 一致的前 7 个 + 常见 BSC 代币至 20 个）
  static const List<({String symbol, String contract})> _betaBnbTokens = [
    (symbol: 'BBT', contract: '0x832AB3f581ADD131D50C24d9a85087648bd16934'),
    (symbol: 'USDT', contract: '0x55d398326f99059fF775485246999027B3197955'),
    (symbol: 'BTCB', contract: '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c'),
    (symbol: 'USDC', contract: '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d'),
    (symbol: 'DAI', contract: '0x1AF3F329e8BE154074D8769D1FFa4eE058AB1FBE'),
    (symbol: 'BUSD', contract: '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56'),
    (symbol: 'ETH', contract: '0x2170Ed0880ac9A755fd29B2688956BD959F933F8'),
    (symbol: 'CAKE', contract: '0x0E09FaBB73Bd3Ade0a17ECC321fD13a19e81cE82'),
    (symbol: 'XRP', contract: '0x1D2F0da169ceB9fC7B3144628dB156f3F6c60dBE'),
    (symbol: 'DOGE', contract: '0xbA2aE424d960c26247Dd6c32edC70B295c691C0D'),
    (symbol: 'SHIB', contract: '0x2859e4544C4b03957903cF1a2c84368928610827'),
    (symbol: 'LINK', contract: '0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD'),
    (symbol: 'UNI', contract: '0xBf5140A22578168FD562DCcF235E5D43A02ce9B1'),
    (symbol: 'DOT', contract: '0x7083609fCE4d1d8Dc0C979AAb8c869Ea2C873402'),
    (symbol: 'LTC', contract: '0x4338665CBB7B2485A8855A139b75D5e34AB0DB94'),
    (symbol: 'MATIC', contract: '0xCC42724C6683B7E57334c4E856f4c9965ED682bD'),
    (symbol: 'AVAX', contract: '0x1CE0c2827e2eF14D5C4f29a091d735A204794041'),
    (symbol: 'ATOM', contract: '0x0Eb3a705fc54725037CC9e008bDede697f62F335'),
    (symbol: 'FIL', contract: '0x0D8Ce2A99Bb6e3B7Db580eD848240e4a0F9aE153'),
    (symbol: 'TRX', contract: '0x85EAC5e2c85803C0e0f0c2f2aF6495e6493d2b2'),
  ];

  static List<MarketItem> betaList() {
    const chain = KnownTokens.bnbMainnet;
    final list = <MarketItem>[];
    for (final t in _betaBnbTokens) {
      if (list.length >= _betaCount) break;
      list.add(MarketItem(
        symbol: t.symbol,
        chain: chain,
        contractAddress: t.contract,
        isToken: true,
        iconUrl: null,
        price: null,
        volume: null,
        marketCap: null,
        changePercent: null,
      ));
    }
    return list;
  }

  /// 大盘分类：由 CoinGeckoService 拉取市值前 15，不在此处生成
  static List<MarketItem> marketCapList() {
    return [];
  }

  /// 美股分类：15 个 mock 项（当前为写死数据，价格/涨跌幅不会实时变化；
  /// 如需实时行情可接入第三方如 Finnhub、Alpha Vantage、Yahoo Finance 等）
  /// iconUrl 使用 Clearbit 公司 logo（logo.clearbit.com/域名）
  static List<MarketItem> usStocksList() {
    const mock = [
      _MockStock('NVDA', 'NVIDIA', 178.13, 871690, 36510000, 1.14, 'https://logo.clearbit.com/nvidia.com'),
      _MockStock('TSLA', 'Tesla', 388.01, 520000, 120000000, -1.61, 'https://logo.clearbit.com/tesla.com'),
      _MockStock('CRCL', 'Circle', 95.43, 310000, 7800000, -3.10, 'https://logo.clearbit.com/circle.com'),
      _MockStock('COIN', 'Coinbase', 245.20, 180000, 52000000, -4.30, 'https://logo.clearbit.com/coinbase.com'),
      _MockStock('AAPL', 'Apple', 228.50, 5000000, 3500000000, -0.32, 'https://logo.clearbit.com/apple.com'),
      _MockStock('GOOGL', 'Google', 175.80, 1200000, 2200000000, -2.33, 'https://logo.clearbit.com/google.com'),
      _MockStock('AMBR', 'Amber', 12.40, 89000, 1200000, -1.89, null),
      _MockStock('QQQ', 'Nasdaq ETF', 485.20, 2100000, 450000000, 1.14, 'https://logo.clearbit.com/nasdaq.com'),
      _MockStock('META', 'Meta', 585.30, 980000, 1500000000, 5.86, 'https://logo.clearbit.com/meta.com'),
      _MockStock('MSFT', 'Microsoft', 420.15, 2200000, 3100000000, -0.85, 'https://logo.clearbit.com/microsoft.com'),
      _MockStock('AMZN', 'Amazon', 198.60, 3500000, 2050000000, 2.10, 'https://logo.clearbit.com/amazon.com'),
      _MockStock('NVDAX', 'NVDA X', 178.10, 871000, 36500000, 1.12, 'https://logo.clearbit.com/nvidia.com'),
      _MockStock('TSLAX', 'TSLA X', 387.80, 518000, 119800000, -1.60, 'https://logo.clearbit.com/tesla.com'),
      _MockStock('COINX', 'COIN X', 245.00, 179000, 51900000, -4.28, 'https://logo.clearbit.com/coinbase.com'),
      _MockStock('AAPLX', 'AAPL X', 228.40, 4990000, 3498000000, -0.30, 'https://logo.clearbit.com/apple.com'),
    ];
    return mock
        .map((e) => MarketItem(
              symbol: e.symbol,
              name: e.name,
              chain: 'us-stock',
              contractAddress: e.symbol,
              isToken: false,
              iconUrl: e.logoUrl,
              price: e.price,
              volume: e.volume.toDouble(),
              marketCap: e.marketCap.toDouble(),
              changePercent: e.changePercent,
            ))
        .toList();
  }
}

class _MockStock {
  final String symbol;
  final String name;
  final double price;
  final int volume;
  final int marketCap;
  final double changePercent;
  final String? logoUrl;
  const _MockStock(this.symbol, this.name, this.price, this.volume, this.marketCap, this.changePercent, this.logoUrl);
}
