/// 各链上需要优先展示的已知代币（符号、精度）
/// 用于代币列表展示名称与正确小数位
class KnownTokenMeta {
  final String contractAddress;
  final String symbol;
  final int decimals;

  const KnownTokenMeta({
    required this.contractAddress,
    required this.symbol,
    required this.decimals,
  });

  String get addressLower => contractAddress.toLowerCase();
}

/// 已知代币配置：按链 ID 存储
class KnownTokens {
  KnownTokens._();

  static const String bnbMainnet = 'bnb-mainnet';
  static const String ethMainnet = 'eth-mainnet';
  static const String baseMainnet = 'base-mainnet';
  static const String xLayer = 'x-layer';

  /// BBT 合约（EVM 多链同地址）
  static const String bbtContract = '0x832AB3f581ADD131D50C24d9a85087648bd16934';
  /// BNB Chain 上 USDT (BEP20)
  static const String usdtBsc = '0x55d398326f99059fF775485246999027B3197955';
  /// BNB Chain PancakeSwap V2 Router（单链闪兑 USDT→BBT 等需先授权给此合约）
  static const String pancakeRouterBsc = '0x10ED43C718714eb63d5aA57B78B54704E256024E';
  /// Ethereum / Base / X Layer 等链上 USDT
  static const String usdtEth = '0xdAC17F958D2ee523a2206206994597C13D831ec7';
  /// BSC 热门代币
  static const String btcBsc = '0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c';  // BTCB
  static const String usdcBsc = '0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d';  // USDC
  static const String daiBsc = '0x1AF3F329e8BE154074D8769D1FFa4eE058AB1FBE';   // DAI
  static const String busdBsc = '0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56';   // BUSD
  static const String wethBsc = '0x2170Ed0880ac9A755fd29B2688956BD959F933F8';   // ETH (WETH)
  /// Ethereum 常用
  static const String usdcEth = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';
  static const String daiEth = '0x6B175474E89094C44Da98b954EedeAC495271d0F';
  static const String wbtcEth = '0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599';

  static final Map<String, List<KnownTokenMeta>> byChain = {
    ethMainnet: const [
      KnownTokenMeta(contractAddress: bbtContract, symbol: 'BBT', decimals: 18),
      KnownTokenMeta(contractAddress: usdtEth, symbol: 'USDT', decimals: 6),
      KnownTokenMeta(contractAddress: usdcEth, symbol: 'USDC', decimals: 6),
      KnownTokenMeta(contractAddress: daiEth, symbol: 'DAI', decimals: 18),
      KnownTokenMeta(contractAddress: wbtcEth, symbol: 'WBTC', decimals: 8),
    ],
    bnbMainnet: const [
      KnownTokenMeta(contractAddress: bbtContract, symbol: 'BBT', decimals: 18),
      KnownTokenMeta(contractAddress: usdtBsc, symbol: 'USDT', decimals: 18),
      KnownTokenMeta(contractAddress: btcBsc, symbol: 'BTCB', decimals: 18),
      KnownTokenMeta(contractAddress: usdcBsc, symbol: 'USDC', decimals: 18),
      KnownTokenMeta(contractAddress: daiBsc, symbol: 'DAI', decimals: 18),
      KnownTokenMeta(contractAddress: busdBsc, symbol: 'BUSD', decimals: 18),
      KnownTokenMeta(contractAddress: wethBsc, symbol: 'ETH', decimals: 18),
    ],
    baseMainnet: const [
      KnownTokenMeta(contractAddress: bbtContract, symbol: 'BBT', decimals: 18),
      KnownTokenMeta(contractAddress: usdtEth, symbol: 'USDT', decimals: 6),
      KnownTokenMeta(contractAddress: usdcEth, symbol: 'USDC', decimals: 6),
    ],
    xLayer: const [
      KnownTokenMeta(contractAddress: bbtContract, symbol: 'BBT', decimals: 18),
      KnownTokenMeta(contractAddress: usdtEth, symbol: 'USDT', decimals: 6),
      KnownTokenMeta(contractAddress: usdcEth, symbol: 'USDC', decimals: 6),
    ],
  };

  /// 当前链需要“额外拉取”的合约地址列表（用于 alchemy_getTokenBalances 的 contractAddresses 参数）
  static List<String> getTrackedContractAddresses(String chain) {
    final list = byChain[chain];
    if (list == null) return [];
    return list.map((e) => e.contractAddress).toList();
  }

  /// 根据合约地址取符号与精度；未知代币返回 null
  static KnownTokenMeta? getMeta(String chain, String contractAddress) {
    final addr = contractAddress.toLowerCase();
    for (final t in byChain[chain] ?? []) {
      if (t.addressLower == addr) return t;
    }
    return null;
  }

  /// 本地代币 Logo（assets/images/）：BBT、BNB、USDT 优先用本地图，其余再用 getLogoUrl
  static const Map<String, String> _localLogoAssets = {
    'BBT': 'assets/images/BBT.png',
    'BNB': 'assets/images/BNB.jpg',
    'USDT': 'assets/images/USDT.jpg',
  };

  /// 若该 symbol 有本地 logo 则返回 asset 路径，否则返回 null
  static String? getLocalLogoAsset(String symbol) {
    if (symbol.isEmpty) return null;
    return _localLogoAssets[symbol.trim().toUpperCase()];
  }

  /// Trust Wallet Assets CDN：按链与合约地址返回代币图标 URL，无则返回 null（UI 用首字母）
  /// 仓库中目录名多为小写，部分为 checksum，此处用小写；若 404 则 TokenAvatar 显示首字母占位
  static String? getLogoUrl(String chain, String? contractAddress) {
    if (contractAddress == null || contractAddress.isEmpty) return null;
    final addr = contractAddress.trim().toLowerCase();
    if (!addr.startsWith('0x')) return null;
    final blockchain = _trustWalletBlockchain(chain);
    if (blockchain == null) return null;
    return 'https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/$blockchain/assets/$addr/logo.png';
  }

  static String? _trustWalletBlockchain(String chain) {
    switch (chain) {
      case bnbMainnet:
        return 'smartchain';
      case ethMainnet:
        return 'ethereum';
      case baseMainnet:
        return 'base';
      case xLayer:
        return 'ethereum'; // X Layer 代币多在 ethereum 有图
      default:
        return null;
    }
  }

  /// 格式化余额：wei -> 显示字符串（按 decimals 除）
  static String formatBalance(String weiStr, int decimals) {
    final wei = BigInt.tryParse(weiStr) ?? BigInt.zero;
    if (wei == BigInt.zero) return '0';
    final divisor = BigInt.from(10).pow(decimals);
    final intPart = wei ~/ divisor;
    final frac = wei % divisor;
    if (frac == BigInt.zero) return intPart.toString();
    final fracStr = frac.toString().padLeft(decimals, '0').replaceAll(RegExp(r'0+$'), '');
    return '$intPart.$fracStr';
  }

  /// 格式化为最多 [maxDecimals] 位小数的显示字符串（用于列表展示）
  static String formatBalanceDisplay(String weiStr, int decimals, {int maxDecimals = 6}) {
    final raw = formatBalance(weiStr, decimals);
    if (!raw.contains('.')) return raw;
    final parts = raw.split('.');
    final frac = parts[1].length > maxDecimals ? parts[1].substring(0, maxDecimals) : parts[1];
    return frac.isEmpty ? parts[0] : '${parts[0]}.$frac';
  }
}
