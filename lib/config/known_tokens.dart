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
  /// Ethereum / Base / X Layer 等链上 USDT
  static const String usdtEth = '0xdAC17F958D2ee523a2206206994597C13D831ec7';

  static final Map<String, List<KnownTokenMeta>> byChain = {
    ethMainnet: const [
      KnownTokenMeta(contractAddress: bbtContract, symbol: 'BBT', decimals: 18),
      KnownTokenMeta(contractAddress: usdtEth, symbol: 'USDT', decimals: 6),
    ],
    bnbMainnet: const [
      KnownTokenMeta(contractAddress: bbtContract, symbol: 'BBT', decimals: 18),
      KnownTokenMeta(contractAddress: usdtBsc, symbol: 'USDT', decimals: 18),
    ],
    baseMainnet: const [
      KnownTokenMeta(contractAddress: bbtContract, symbol: 'BBT', decimals: 18),
      KnownTokenMeta(contractAddress: usdtEth, symbol: 'USDT', decimals: 6),
    ],
    xLayer: const [
      KnownTokenMeta(contractAddress: bbtContract, symbol: 'BBT', decimals: 18),
      KnownTokenMeta(contractAddress: usdtEth, symbol: 'USDT', decimals: 6),
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
