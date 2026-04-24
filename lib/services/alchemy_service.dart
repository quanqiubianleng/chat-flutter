import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:education/config/app_config.dart';
import 'package:education/config/app_env.dart';
import 'package:education/core/utils/logger.dart';

/// Alchemy API 服务：Token 余额、NFT 等
/// API Key 请在 dashboard.alchemy.com 创建应用获取，勿使用登录密码
class AlchemyService {
  static String? get _apiKey => currentEnv.alchemyApiKey;
  static String? get _proxyBase => currentEnv.walletProxyBaseUrl;
  /// 可用：配置了代理基地址（服务端带 Key）或配置了客户端 Alchemy Key
  static bool get isAvailable =>
      (_proxyBase != null && _proxyBase!.isNotEmpty) ||
      (_apiKey != null && _apiKey!.isNotEmpty);

  static Dio? _dioInstance;
  static Dio get _dio {
    _dioInstance ??= _createDio();
    return _dioInstance!;
  }

  static Dio _createDio() {
    final dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    if (AppConfig.isDebug) {
      dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.badCertificateCallback = (_, __, ___) => true;
          return client;
        },
      );
    }
    return dio;
  }

  /// 以太坊主网
  static const String ethMainnet = 'eth-mainnet';
  /// BNB Chain
  static const String bnbMainnet = 'bnb-mainnet';

  static String _baseUrl(String chain) {
    final proxy = _proxyBase;
    if (proxy != null && proxy.isNotEmpty) {
      return '$proxy/alchemy/rpc?chain=${Uri.encodeComponent(chain)}';
    }
    final base = currentEnv.alchemyBaseUrl;
    if (base != null && base.isNotEmpty) {
      return '$base/$chain/v2/${_apiKey ?? ''}';
    }
    return 'https://$chain.g.alchemy.com/v2/${_apiKey ?? ''}';
  }

  static String _nftBaseUrl(String chain) {
    final proxy = _proxyBase;
    if (proxy != null && proxy.isNotEmpty) {
      return proxy; // 实际请求用 _nftUrl(chain, owner, pageSize, pageKey)
    }
    final base = currentEnv.alchemyBaseUrl;
    if (base != null && base.isNotEmpty) {
      return '$base/$chain/nft/v2/${_apiKey ?? ''}';
    }
    return 'https://$chain.g.alchemy.com/nft/v2/${_apiKey ?? ''}';
  }

  static String _nftUrl(String chain, String owner, int pageSize, String? pageKey) {
    final proxy = _proxyBase;
    if (proxy != null && proxy.isNotEmpty) {
      var u = '$proxy/alchemy/nft?chain=${Uri.encodeComponent(chain)}&owner=${Uri.encodeComponent(owner)}&pageSize=$pageSize';
      if (pageKey != null && pageKey.isNotEmpty) {
        u += '&pageKey=${Uri.encodeComponent(pageKey)}';
      }
      return u;
    }
    return '${_nftBaseUrl(chain)}/getNFTs/?owner=$owner&pageSize=$pageSize'
        + (pageKey != null && pageKey.isNotEmpty ? '&pageKey=${Uri.encodeComponent(pageKey)}' : '');
  }

  /// 将接口返回统一转为 Map（Dio 有时在部分环境下返回未解析的 String 或 null）
  static Map<String, dynamic>? _responseToMap(dynamic raw) {
    if (raw == null) {
      if (AppConfig.isDebug) AppLogger.d('[Alchemy] resp.data 为 null');
      return null;
    }
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      final lower = raw.toLowerCase();
      if (AppConfig.isDebug && (lower.contains('<html') || lower.contains('resource not found'))) {
        AppLogger.d('[Alchemy] 网络返回 HTML(无法访问节点)，请切换网络或使用后端代理');
        return null;
      }
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
      if (AppConfig.isDebug) {
        AppLogger.d('[Alchemy] 接口返回非 JSON，类型=${raw.runtimeType}');
      }
    }
    return null;
  }

  /// 根据原始响应给出可读的错误提示（如被代理/网络返回 HTML 时）
  static String? _formatErrorHint(dynamic raw) {
    if (raw == null) return null;
    final s = raw is String ? raw : raw.toString();
    final lower = s.toLowerCase();
    if (lower.contains('<html') || lower.contains('resource not found') || lower.contains('cdn')) {
      return '无法访问区块链节点服务，请检查网络（如关闭代理/VPN 或切换网络）后重试';
    }
    return null;
  }

  /// 获取代币余额（ERC20）
  /// [owner] 钱包地址 0x...
  /// [chain] 链标识，如 eth-mainnet、bnb-mainnet
  /// [contractAddresses] 可选，指定要查询的合约地址列表；不传则返回该地址持有的所有代币
  Future<AlchemyTokenBalancesResult> getTokenBalances(
    String owner, {
    String chain = ethMainnet,
    List<String>? contractAddresses,
  }) async {
    if (!isAvailable) {
      return AlchemyTokenBalancesResult(
        error: '未配置 Alchemy API Key，请使用 --dart-define=ALCHEMY_API_KEY=xxx',
      );
    }
    try {
      final url = _baseUrl(chain);
      if (AppConfig.isDebug) {
        final via = (_proxyBase != null && _proxyBase!.isNotEmpty) ? '代理' : '直连';
        AppLogger.d('[Alchemy] getTokenBalances 请求($via): $url');
      }
      final params = contractAddresses != null && contractAddresses.isNotEmpty
          ? [owner, contractAddresses.map((a) => a.startsWith('0x') ? a : '0x$a').toList()]
          : [owner];
      final resp = await _dio.post<dynamic>(
        url,
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'alchemy_getTokenBalances',
          'params': params,
        },
        options: Options(responseType: ResponseType.json, validateStatus: (_) => true),
      );
      if (resp.statusCode != null && resp.statusCode! >= 500) {
        final msg = _responseToMap(resp.data)?['error']?.toString() ?? '服务端代理异常(${resp.statusCode})，请检查服务端配置与日志';
        return AlchemyTokenBalancesResult(error: msg);
      }
      final data = _responseToMap(resp.data);
      if (data == null) {
        return AlchemyTokenBalancesResult(
          error: _formatErrorHint(resp.data) ?? '接口返回格式异常',
        );
      }
      final err = data['error'];
      if (err != null) {
        final msg = err is Map ? (err['message']?.toString()) : err.toString();
        return AlchemyTokenBalancesResult(error: msg ?? 'RPC 错误');
      }
      final resultRaw = data['result'];
      if (resultRaw is! Map<String, dynamic>) {
        return AlchemyTokenBalancesResult(error: '无返回数据');
      }
      final result = resultRaw as Map<String, dynamic>;
      final list = result['tokenBalances'];
      final listDynamic = list is List<dynamic> ? list : null;
      final tokenBalances = <TokenBalanceItem>[];
      if (listDynamic != null) {
        for (final e in listDynamic) {
          if (e is Map<String, dynamic>) {
            try {
              tokenBalances.add(TokenBalanceItem.fromJson(e));
            } catch (_) {}
          }
        }
      }
      return AlchemyTokenBalancesResult(tokenBalances: tokenBalances);
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code != null && code >= 500) {
        final msg = e.response?.data is Map ? (e.response?.data as Map)['error']?.toString() : null;
        return AlchemyTokenBalancesResult(error: msg ?? '服务端代理异常($code)，请检查服务端配置与日志');
      }
      return AlchemyTokenBalancesResult(error: e.message ?? e.toString());
    } catch (e) {
      return AlchemyTokenBalancesResult(error: e.toString());
    }
  }

  /// 获取原生币余额（ETH/BNB）
  Future<String?> getNativeBalance(String owner, {String chain = ethMainnet}) async {
    if (!isAvailable) return null;
    try {
      final url = _baseUrl(chain);
      if (AppConfig.isDebug) {
        final via = (_proxyBase != null && _proxyBase!.isNotEmpty) ? '代理' : '直连';
        AppLogger.d('[Alchemy] getNativeBalance 请求($via): $url');
      }
      final resp = await _dio.post<dynamic>(
        url,
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'eth_getBalance',
          'params': [owner, 'latest'],
        },
        options: Options(responseType: ResponseType.json, validateStatus: (_) => true),
      );
      if (resp.statusCode != null && resp.statusCode! >= 500) return null;
      final data = _responseToMap(resp.data);
      if (data == null) return null;
      final hex = data['result'] as String?;
      if (hex == null) return null;
      return BigInt.tryParse(hex.replaceFirst('0x', ''), radix: 16)?.toString();
    } catch (_) {
      return null;
    }
  }

  /// 获取 NFT 列表
  /// [owner] 钱包地址
  /// [chain] 链
  /// [pageSize] 每页数量
  /// [pageKey] 分页游标
  Future<AlchemyNftsResult> getNfts(
    String owner, {
    String chain = ethMainnet,
    int pageSize = 20,
    String? pageKey,
  }) async {
    if (!isAvailable) {
      return AlchemyNftsResult(
        error: '未配置 Alchemy API Key，请使用 --dart-define=ALCHEMY_API_KEY=xxx',
      );
    }
    try {
      final url = _nftUrl(chain, owner, pageSize, pageKey);
      if (AppConfig.isDebug) {
        final via = (_proxyBase != null && _proxyBase!.isNotEmpty) ? '代理' : '直连';
        AppLogger.d('[Alchemy] getNfts 请求($via): $url');
      }
      final resp = await _dio.get<dynamic>(url, options: Options(responseType: ResponseType.json));
      final data = _responseToMap(resp.data);
      if (data == null) {
        return AlchemyNftsResult(error: _formatErrorHint(resp.data) ?? '接口返回格式异常');
      }
      final nfts = (data['ownedNfts'] as List<dynamic>?)
          ?.map((e) => AlchemyNftItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [];
      final nextPageKey = data['pageKey'] as String?;
      return AlchemyNftsResult(
        nfts: nfts,
        pageKey: nextPageKey,
      );
    } catch (e) {
      return AlchemyNftsResult(error: e.toString());
    }
  }
}

class AlchemyTokenBalancesResult {
  final List<TokenBalanceItem> tokenBalances;
  final String? error;

  AlchemyTokenBalancesResult({List<TokenBalanceItem>? tokenBalances, this.error})
      : tokenBalances = tokenBalances ?? [];
}

class TokenBalanceItem {
  final String contractAddress;
  final String tokenBalance; // hex

  TokenBalanceItem({required this.contractAddress, required this.tokenBalance});

  static TokenBalanceItem fromJson(Map<String, dynamic> json) {
    return TokenBalanceItem(
      contractAddress: (json['contractAddress'] as String? ?? '').toLowerCase(),
      tokenBalance: json['tokenBalance'] as String? ?? '0x0',
    );
  }

  BigInt get balanceWei {
    final hex = tokenBalance.replaceFirst('0x', '');
    return BigInt.tryParse(hex, radix: 16) ?? BigInt.zero;
  }
}

class AlchemyNftsResult {
  final List<AlchemyNftItem> nfts;
  final String? pageKey;
  final String? error;

  AlchemyNftsResult({List<AlchemyNftItem>? nfts, this.pageKey, this.error})
      : nfts = nfts ?? [];
}

class AlchemyNftItem {
  final String contractAddress;
  final String tokenId;
  final String? name;
  final String? description;
  final String? imageUrl;
  final String? collectionName;

  AlchemyNftItem({
    required this.contractAddress,
    required this.tokenId,
    this.name,
    this.description,
    this.imageUrl,
    this.collectionName,
  });

  static AlchemyNftItem fromJson(Map<String, dynamic> json) {
    String? imageUrl;
    try {
      final media = json['media'] as List<dynamic>?;
      if (media != null && media.isNotEmpty) {
        final first = media.first as Map<String, dynamic>?;
        imageUrl = first?['gateway'] as String? ?? first?['raw'] as String?;
      }
      if (imageUrl == null) {
        final meta = json['rawMetadata'] as Map<String, dynamic>?;
        imageUrl = meta?['image'] as String?;
      }
      if (imageUrl != null && imageUrl.startsWith('ipfs://')) {
        imageUrl = 'https://ipfs.io/ipfs/${imageUrl.substring(7)}';
      }
    } catch (_) {}
    final contract = json['contract'] as Map<String, dynamic>?;
    String tokenId = '';
    try {
      final id = json['id'] as Map<String, dynamic>?;
      if (id != null) {
        final hex = id['tokenId'] as String?;
        if (hex != null) tokenId = BigInt.tryParse(hex.replaceFirst('0x', ''), radix: 16)?.toString() ?? hex;
      }
    } catch (_) {}
    if (tokenId.isEmpty) tokenId = json['tokenId']?.toString() ?? '';
    return AlchemyNftItem(
      contractAddress: contract?['address'] as String? ?? '',
      tokenId: tokenId,
      name: json['title'] as String?,
      description: json['description'] as String?,
      imageUrl: imageUrl,
      collectionName: contract?['name'] as String?,
    );
  }
}
