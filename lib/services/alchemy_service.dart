import 'package:dio/dio.dart';
import 'package:education/config/app_env.dart';

/// Alchemy API 服务：Token 余额、NFT 等
/// API Key 请在 dashboard.alchemy.com 创建应用获取，勿使用登录密码
class AlchemyService {
  static String? get _apiKey => currentEnv.alchemyApiKey;
  static bool get isAvailable => _apiKey != null && _apiKey!.isNotEmpty;

  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  /// 以太坊主网
  static const String ethMainnet = 'eth-mainnet';
  /// BNB Chain
  static const String bnbMainnet = 'bnb-mainnet';

  static String _baseUrl(String chain) =>
      'https://$chain.g.alchemy.com/v2/${_apiKey ?? ''}';
  static String _nftBaseUrl(String chain) =>
      'https://$chain.g.alchemy.com/nft/v2/${_apiKey ?? ''}';

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
      final params = contractAddresses != null && contractAddresses.isNotEmpty
          ? [owner, contractAddresses.map((a) => a.startsWith('0x') ? a : '0x$a').toList()]
          : [owner];
      final resp = await _dio.post(
        url,
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'alchemy_getTokenBalances',
          'params': params,
        },
      );
      final data = resp.data as Map<String, dynamic>;
      if (data['error'] != null) {
        return AlchemyTokenBalancesResult(
          error: data['error']['message']?.toString() ?? 'RPC 错误',
        );
      }
      final result = data['result'] as Map<String, dynamic>?;
      if (result == null) {
        return AlchemyTokenBalancesResult(error: '无返回数据');
      }
      final tokenBalances = (result['tokenBalances'] as List<dynamic>?)
          ?.map((e) => TokenBalanceItem.fromJson(e as Map<String, dynamic>))
          .toList() ?? [];
      return AlchemyTokenBalancesResult(tokenBalances: tokenBalances);
    } catch (e) {
      return AlchemyTokenBalancesResult(error: e.toString());
    }
  }

  /// 获取原生币余额（ETH/BNB）
  Future<String?> getNativeBalance(String owner, {String chain = ethMainnet}) async {
    if (!isAvailable) return null;
    try {
      final url = _baseUrl(chain);
      final resp = await _dio.post(
        url,
        data: {
          'jsonrpc': '2.0',
          'id': 1,
          'method': 'eth_getBalance',
          'params': [owner, 'latest'],
        },
      );
      final data = resp.data as Map<String, dynamic>;
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
      var url = '${_nftBaseUrl(chain)}/getNFTs/?owner=$owner&pageSize=$pageSize';
      if (pageKey != null && pageKey.isNotEmpty) {
        url += '&pageKey=${Uri.encodeComponent(pageKey)}';
      }
      final resp = await _dio.get(url);
      final data = resp.data as Map<String, dynamic>;
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
