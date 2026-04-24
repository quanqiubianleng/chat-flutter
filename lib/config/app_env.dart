/// 运行环境：通过 flutter run --dart-define=ENV=prod 或构建时传入。
/// 可选值：dev | staging | prod
enum AppEnv {
  dev,
  staging,
  prod,
}

/// 当前环境（来自 --dart-define=ENV=xxx，非 const 因 _envFromString 非常量表达式）
/*final AppEnv kAppEnv = _envFromString(
  String.fromEnvironment('ENV', defaultValue: 'dev'),
);*/
const String kRawEnv = String.fromEnvironment('ENV', defaultValue: '');
final AppEnv kAppEnv = _envFromString(
  kRawEnv.isEmpty ? 'staging' : kRawEnv,
);

AppEnv _envFromString(String value) {
  switch (value.toLowerCase()) {
    case 'staging':
      return AppEnv.staging;
    case 'prod':
    case 'production':
      return AppEnv.prod;
    default:
      return AppEnv.dev;
  }
}

/// 闪兑聚合器：paraswap 无需 KYC/API Key；oneinch 需在 portal.1inch.dev 配置 Key
enum SwapProvider {
  paraswap,
  oneinch,
}

/// 各环境下的接口与 WS 地址（可按需改为从后端下发或 .env 读取）
class EnvConfig {
  final String wsUrl;
  final String reqUrl;
  final String agreeUrl;
  final String privacyUrl;
  final bool isDebug;
  /// Alchemy API Key（在 dashboard.alchemy.com 创建应用获取，用于 Token/NFT 数据）
  final String? alchemyApiKey;
  /// Alchemy 请求基地址（可选）。配置后所有 Alchemy 请求发往该地址，用于国内通过后端代理访问
  /// 示例：https://your-backend.com/alchemy（代理需将 /alchemy/{chain}/v2/{key} 转发到 https://{chain}.g.alchemy.com/v2/{key}）
  final String? alchemyBaseUrl;
  /// 1inch API Key（可选，在 https://portal.1inch.dev 注册可提高限流；不填则用公开 API，约 1 次/秒）
  final String? oneInchApiKey;
  /// 国外第三方 API 统一代理基地址（Alchemy/1inch/CoinGecko/ParaSwap）。配置后相关请求发往该地址
  /// 示例：https://your-gateway.com/v1/wallet/proxy（与 gateway 的 /v1/wallet/proxy/* 路由一致）
  final String? walletProxyBaseUrl;
  /// 新手引导页地址（个人中心「新手引导」点击后在小程序 WebView 中打开）
  final String newbieGuideUrl;
  /// 闪兑使用的聚合器：paraswap 无需 KYC；oneinch 需 API Key（且新账号可能需企业验证）
  final SwapProvider swapProvider;

  const EnvConfig({
    required this.wsUrl,
    required this.reqUrl,
    required this.agreeUrl,
    required this.privacyUrl,
    this.isDebug = false,
    this.alchemyApiKey,
    this.alchemyBaseUrl,
    this.oneInchApiKey,
    this.walletProxyBaseUrl,
    this.newbieGuideUrl = '',
    this.swapProvider = SwapProvider.paraswap,
  });

  /// Alchemy API Key：未传时用下面默认值（仅本地跑通用；正式环境建议改为 defaultValue: '' 并用 --dart-define 传入）
  static String? get _alchemyKey {
    const key = String.fromEnvironment(
      'ALCHEMY_API_KEY',
      defaultValue: '6wP4M25wCt5N6wUI3QkIA',
    );
    return key.isEmpty ? null : key;
  }

  /// Alchemy 代理基地址：--dart-define=ALCHEMY_BASE_URL=https://your-proxy.com/alchemy 便于国内走代理
  static String? get _alchemyBaseUrl {
    const url = String.fromEnvironment(
      'ALCHEMY_BASE_URL',
      defaultValue: '',
    );
    return url.isEmpty ? null : url.replaceFirst(RegExp(r'/$'), '');
  }

  /// 1inch API Key：不填则用公开 API。填写方式：flutter run --dart-define=ONEINCH_API_KEY=你的key 或在下方 defaultValue 写死（仅调试）
  static String? get _oneInchKey {
    const key = String.fromEnvironment(
      'ONEINCH_API_KEY',
      defaultValue: '',
    );
    return key.isEmpty ? null : key;
  }

  /// 统一代理基地址：未配置时用 reqUrl + /v1/wallet/proxy，便于国内全部走后端代理
  static String? _walletProxyBaseUrl(String reqUrl) {
    const url = String.fromEnvironment(
      'WALLET_PROXY_BASE_URL',
      defaultValue: '',
    );
    if (url.isNotEmpty) return url.replaceFirst(RegExp(r'/$'), '');
    return reqUrl.replaceFirst(RegExp(r'/$'), '') + '/v1/wallet/proxy';
  }

  /// 新手引导页 URL：可通过 --dart-define=NEWBIE_GUIDE_URL=https://... 传入
  static String get _newbieGuideUrl {
    const url = String.fromEnvironment(
      'NEWBIE_GUIDE_URL',
      defaultValue: 'http://8.210.232.129/intro.html',
    );
    return url;
  }

  static EnvConfig get dev => EnvConfig(
    wsUrl: 'ws://8.210.232.129:8899/ws',
    // reqUrl: 'http://8.210.232.129:8060',
    reqUrl: 'https://gateway.bbtglobal.io',
    agreeUrl: 'http://8.210.232.129/ua.html',
    privacyUrl: 'http://8.210.232.129/privacy.html',
    isDebug: true,
    alchemyApiKey: _alchemyKey,
    alchemyBaseUrl: _alchemyBaseUrl,
    oneInchApiKey: _oneInchKey,
    // 与 reqUrl 保持同一网关端口，避免仅 dev 走到不可达端口导致连接超时
    walletProxyBaseUrl: _walletProxyBaseUrl('http://8.210.232.129:8060'),
    newbieGuideUrl: _newbieGuideUrl,
    swapProvider: SwapProvider.paraswap,
  );

  static EnvConfig get staging => EnvConfig(
    wsUrl: 'ws://47.83.189.255:8899/ws',
    reqUrl: 'http://47.83.189.255:8060',
    agreeUrl: 'http://47.83.189.255/ua.html',
    privacyUrl: 'http://47.83.189.255/privacy.html',
    isDebug: true,
    alchemyApiKey: _alchemyKey,
    alchemyBaseUrl: _alchemyBaseUrl,
    oneInchApiKey: _oneInchKey,
    walletProxyBaseUrl: _walletProxyBaseUrl('http://47.83.189.255:8060'),
    newbieGuideUrl: _newbieGuideUrl, 
    swapProvider: SwapProvider.paraswap,
  );

  static EnvConfig get prod => EnvConfig(
    wsUrl: 'ws://8.210.232.129:8899/ws',
    reqUrl: 'https://gateway.bbtglobal.io',
    agreeUrl: 'http://8.210.232.129/ua.html',
    privacyUrl: 'http://8.210.232.129/privacy.html',
    isDebug: false,
    alchemyApiKey: _alchemyKey,
    alchemyBaseUrl: _alchemyBaseUrl,
    oneInchApiKey: _oneInchKey,
    walletProxyBaseUrl: _walletProxyBaseUrl('https://gateway.bbtglobal.io'),
    newbieGuideUrl: _newbieGuideUrl,
    swapProvider: SwapProvider.paraswap,
  );
}

/// 当前环境配置
EnvConfig get currentEnv {
  switch (kAppEnv) {
    case AppEnv.staging:
      return EnvConfig.staging;
    case AppEnv.prod:
      return EnvConfig.prod;
    default:
      return EnvConfig.dev;
  }
}
