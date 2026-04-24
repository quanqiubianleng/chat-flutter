import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:education/config/app_env.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/core/utils/logger.dart';

/// 1inch 聚合协议 API：报价 + 获取 swap 交易数据，发交易仍用 EvmTransferService + Alchemy RPC
/// API Key 可选：不填用公开 API（约 1 次/秒）；在 https://portal.1inch.dev 注册后填入可提高限流
/// 配置 walletProxyBaseUrl 时请求走后端代理，服务端带 Key
class OneInchService {
  static String? get _apiKey => currentEnv.oneInchApiKey;
  static String? get _proxyBase => currentEnv.walletProxyBaseUrl;

  static const String _directBaseUrl = 'https://api.1inch.io/v5.0';
  static String get _baseUrl => (_proxyBase != null && _proxyBase!.isNotEmpty)
      ? _proxyBase!
      : _directBaseUrl;
  /// 1inch 中表示原生币（ETH/BNB）的地址
  static const String nativeTokenAddress = '0xEeeeeEeeeEeEeeEeEeEeEeeeEeEeeeeEeeEeeeEeE';

  static Dio? _dio;
  static Dio get _dioClient {
    _dio ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    return _dio!;
  }

  static int chainIdFromChain(String chain) {
    switch (chain) {
      case 'eth-mainnet':
      case KnownTokens.ethMainnet:
        return 1;
      case 'bnb-mainnet':
      case KnownTokens.bnbMainnet:
        return 56;
      case 'base-mainnet':
        return 8453;
      case 'x-layer':
        return 196;
      default:
        return 56;
    }
  }

  static String _tokenAddress(String chain, String? symbol, String? contractAddress) {
    if (symbol == 'BNB' || symbol == 'ETH') return nativeTokenAddress;
    if (contractAddress != null && contractAddress.isNotEmpty) {
      return contractAddress.startsWith('0x') ? contractAddress : '0x$contractAddress';
    }
    if (symbol == 'USDT') {
      return chain == KnownTokens.bnbMainnet ? KnownTokens.usdtBsc : KnownTokens.usdtEth;
    }
    if (symbol == 'BBT') return KnownTokens.bbtContract;
    return contractAddress ?? nativeTokenAddress;
  }

  static Map<String, String>? get _headers {
    if (_apiKey == null || _apiKey!.isEmpty) return null;
    return {'Authorization': 'Bearer $_apiKey'};
  }

  /// 获取报价：返回预计得到的 toToken 数量（wei 字符串），失败返回 null
  static Future<String?> getQuote({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
  }) async {
    final cid = chainIdFromChain(chain);
    final src = _tokenAddress(chain, fromSymbol, fromContract);
    final dst = _tokenAddress(chain, toSymbol, toContract);
    try {
      final useProxy = _proxyBase != null && _proxyBase!.isNotEmpty;
      final path = useProxy ? '/1inch/quote' : '/$cid/quote';
      final query = useProxy
          ? {'chainId': cid.toString(), 'src': src, 'dst': dst, 'amount': amountWei}
          : {'src': src, 'dst': dst, 'amount': amountWei};
      final resp = await _dioClient.get<Map<String, dynamic>>(
        useProxy ? (_baseUrl + path) : '$_directBaseUrl/$cid/quote',
        queryParameters: query,
        options: Options(
          headers: useProxy ? null : _headers,
          responseType: ResponseType.json,
        ),
      );
      final data = resp.data;
      if (data == null) return null;
      // 支持顶层或嵌套在 result/quote 中的数量
      Object? toAmount;
      if (data is Map<String, dynamic>) {
        toAmount = data['toTokenAmount'] ?? data['toAmount'] ?? data['dstAmount'];
        if (toAmount == null) {
          final result = data['result'];
          final quote = data['quote'];
          if (result is Map<String, dynamic>) {
            toAmount = result['toTokenAmount'] ?? result['toAmount'] ?? result['dstAmount'];
          }
          if (toAmount == null && quote is Map<String, dynamic>) {
            toAmount = quote['toTokenAmount'] ?? quote['toAmount'] ?? quote['dstAmount'];
          }
        }
      }
      if (toAmount == null) return null;
      return toAmount is String ? toAmount : toAmount.toString();
    } catch (e) {
      AppLogger.d('[1inch] quote error: $e');
      return null;
    }
  }

  /// 通过 1inch 报价估算某代币的 USD 单价（以 USDT 为计价）
  /// 原理：用 1 个整币的最小单位数量兑换为 USDT，再根据 USDT 的 decimals 换算为价格
  /// 若报价失败或无流动性，返回 null
  static Future<double?> getTokenUsdPriceByQuote({
    required String chain,
    required String tokenSymbol,
    required String? tokenContract,
    required int tokenDecimals,
  }) async {
    try {
      // 以 1 个整币作为报价基准
      final amountWei = BigInt.from(10).pow(tokenDecimals).toString();
      final quote = await getQuote(
        chain: chain,
        fromSymbol: tokenSymbol,
        fromContract: tokenContract,
        toSymbol: 'USDT',
        toContract: null,
        amountWei: amountWei,
      );
      if (quote == null || quote.isEmpty) return null;

      // 根据当前链的 USDT 精度，将 USDT 的最小单位数量换算为 1 个 token 的 USDT 价格
      final usdtAddress =
          chain == KnownTokens.bnbMainnet ? KnownTokens.usdtBsc : KnownTokens.usdtEth;
      final usdtMeta = KnownTokens.getMeta(chain, usdtAddress);
      // 默认：BSC 视为 18 小数；ETH 等视为 6 小数
      final usdtDecimals =
          usdtMeta?.decimals ?? (chain == KnownTokens.bnbMainnet ? 18 : 6);
      final quoteWei = BigInt.tryParse(quote) ?? BigInt.zero;
      if (quoteWei == BigInt.zero) return null;
      final price =
          quoteWei.toDouble() / BigInt.from(10).pow(usdtDecimals).toDouble();
      return price.isFinite && price > 0 ? price : null;
    } catch (e) {
      AppLogger.d('[1inch] price error: $e');
      return null;
    }
  }

  /// 获取 swap 交易数据，用于后续签名并广播
  /// 返回 tx 的 to、data、value、gas；失败抛异常或返回 null
  static Future<OneInchSwapTx?> getSwap({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
    required String fromAddress,
    double slippagePercent = 1.0,
  }) async {
    final cid = chainIdFromChain(chain);
    final src = _tokenAddress(chain, fromSymbol, fromContract);
    final dst = _tokenAddress(chain, toSymbol, toContract);
    try {
      final useProxy = _proxyBase != null && _proxyBase!.isNotEmpty;
      final fromAddr = fromAddress.startsWith('0x') ? fromAddress : '0x$fromAddress';
      final query = {
        'src': src,
        'dst': dst,
        'amount': amountWei,
        'from': fromAddr,
        'slippage': slippagePercent.toStringAsFixed(1),
      };
      if (useProxy) query['chainId'] = cid.toString();
      // 先以纯文本接收，避免服务端/1inch 返回 HTML 或非 JSON 时 Dio 抛 FormatException
      final resp = await _dioClient.get<String>(
        useProxy ? '$_baseUrl/1inch/swap' : '$_directBaseUrl/$cid/swap',
        queryParameters: query,
        options: Options(
          headers: useProxy ? null : _headers,
          responseType: ResponseType.plain,
        ),
      );
      final raw = resp.data;
      if (raw == null || raw.isEmpty) {
        AppLogger.d('[1inch] swap empty body');
        throw Exception('闪兑接口返回为空，请稍后重试或检查服务端 1inch 代理');
      }
      final data = _parseJsonMap(raw);
      if (data == null) {
        AppLogger.d('[1inch] swap invalid json: ${raw.length > 200 ? '${raw.substring(0, 200)}...' : raw}');
        throw Exception('闪兑接口返回格式异常，请查看服务端日志或稍后重试');
      }
      // 1inch 错误时可能仍为 200 且带 description
      final errDesc = data['description'] as String? ?? data['error'] as String?;
      if (errDesc != null && errDesc.isNotEmpty) {
        AppLogger.d('[1inch] swap api error: $errDesc');
        throw Exception(errDesc);
      }
      final tx = data['tx'];
      if (tx is! Map<String, dynamic>) return null;
      final to = tx['to'] as String?;
      final txData = tx['data'] as String?;
      if (to == null || to.isEmpty || txData == null || txData.isEmpty) return null;
      final value = tx['value'];
      BigInt valueWei = BigInt.zero;
      if (value != null) {
        if (value is String) valueWei = BigInt.tryParse(value) ?? BigInt.zero;
        else if (value is int) valueWei = BigInt.from(value);
      }
      final gas = tx['gas'];
      final gasPrice = tx['gasPrice'];
      int gasInt = 300000;
      if (gas != null) {
        if (gas is int) gasInt = gas;
        else if (gas is String) gasInt = int.tryParse(gas) ?? 300000;
      }
      BigInt? gasPriceWei;
      if (gasPrice != null) {
        if (gasPrice is String) gasPriceWei = BigInt.tryParse(gasPrice);
        else if (gasPrice is int) gasPriceWei = BigInt.from(gasPrice);
      }
      return OneInchSwapTx(
        to: to,
        data: txData,
        valueWei: valueWei,
        gas: gasInt,
        gasPriceWei: gasPriceWei,
      );
    } on DioException catch (e) {
      AppLogger.d('[1inch] swap error: $e');
      final msg = e.response?.data is String
          ? (e.response!.data as String).length > 100
              ? '${(e.response!.data as String).substring(0, 100)}...'
              : e.response!.data as String
          : '${e.type} ${e.message ?? ''}';
      throw Exception('闪兑请求失败: $msg');
    } catch (e) {
      AppLogger.d('[1inch] swap error: $e');
      rethrow;
    }
  }

  static Map<String, dynamic>? _parseJsonMap(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }
}

class OneInchSwapTx {
  final String to;
  final String data;
  final BigInt valueWei;
  final int gas;
  final BigInt? gasPriceWei;

  OneInchSwapTx({
    required this.to,
    required this.data,
    required this.valueWei,
    required this.gas,
    this.gasPriceWei,
  });
}
