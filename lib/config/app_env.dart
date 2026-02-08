/// 运行环境：通过 flutter run --dart-define=ENV=prod 或构建时传入。
/// 可选值：dev | staging | prod
enum AppEnv {
  dev,
  staging,
  prod,
}

/// 当前环境（来自 --dart-define=ENV=xxx，非 const 因 _envFromString 非常量表达式）
final AppEnv kAppEnv = _envFromString(
  String.fromEnvironment('ENV', defaultValue: 'dev'),
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

/// 各环境下的接口与 WS 地址（可按需改为从后端下发或 .env 读取）
class EnvConfig {
  final String wsUrl;
  final String reqUrl;
  final String agreeUrl;
  final String privacyUrl;
  final bool isDebug;

  const EnvConfig({
    required this.wsUrl,
    required this.reqUrl,
    required this.agreeUrl,
    required this.privacyUrl,
    this.isDebug = true,
  });

  static const EnvConfig dev = EnvConfig(
    // wsUrl: 'ws://192.168.1.103:8899/ws',
    wsUrl: 'ws://129.211.215.59:8899/ws',
    // reqUrl: 'http://192.168.1.103:8860',
    reqUrl: 'http://129.211.215.59:8860',
    agreeUrl: 'https://uat-dev.fadada.com/api-doc/4GSRGR45LY/WEOBQWTXXXMJPCPW/5-1',
    privacyUrl: 'https://uat-dev.fadada.com/api-doc/4GSRGR45LY/WEOBQWTXXXMJPCPW/5-1',
    isDebug: true,
  );

  static const EnvConfig staging = EnvConfig(
    wsUrl: 'ws://129.211.215.59:8899/ws',
    reqUrl: 'http://129.211.215.59:8860',
    agreeUrl: 'https://uat-dev.fadada.com/api-doc/4GSRGR45LY/WEOBQWTXXXMJPCPW/5-1',
    privacyUrl: 'https://uat-dev.fadada.com/api-doc/4GSRGR45LY/WEOBQWTXXXMJPCPW/5-1',
    isDebug: true,
  );

  static const EnvConfig prod = EnvConfig(
    wsUrl: 'ws://129.211.215.59:8899/ws',
    reqUrl: 'http://129.211.215.59:8860',
    agreeUrl: 'https://uat-dev.fadada.com/api-doc/4GSRGR45LY/WEOBQWTXXXMJPCPW/5-1',
    privacyUrl: 'https://uat-dev.fadada.com/api-doc/4GSRGR45LY/WEOBQWTXXXMJPCPW/5-1',
    isDebug: false,
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
