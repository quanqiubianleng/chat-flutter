import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:education/config/app_env.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/core/utils/logger.dart';
import 'package:education/services/swap_aggregator.dart';

/// ParaSwap 聚合 API：无需 KYC/API Key，公开接口。报价 /prices + 构建交易 POST /transactions
/// 请求经网关代理：GET /paraswap/prices，POST /paraswap/transactions
class ParaSwapService {
  static String? get _proxyBase => currentEnv.walletProxyBaseUrl;
  static const String _directBase = 'https://api.paraswap.io';
  static String get _baseUrl =>
      (_proxyBase != null && _proxyBase!.isNotEmpty) ? _proxyBase! : _directBase;

  static Dio? _dio;
  static Dio get _dioClient {
    _dio ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ));
    return _dio!;
  }

  static int _chainId(String chain) {
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

  /// ParaSwap 要求原生币地址为全小写
  static const String _nativeAddress = '0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

  static String _tokenAddress(String chain, String? symbol, String? contractAddress) {
    if (symbol == 'BNB' || symbol == 'ETH') return _nativeAddress;
    if (contractAddress != null && contractAddress.isNotEmpty) {
      final addr = contractAddress.startsWith('0x') ? contractAddress : '0x$contractAddress';
      return addr.toLowerCase();
    }
    if (symbol == 'USDT') {
      return (chain == KnownTokens.bnbMainnet ? KnownTokens.usdtBsc : KnownTokens.usdtEth).toLowerCase();
    }
    if (symbol == 'BBT') return KnownTokens.bbtContract.toLowerCase();
    return contractAddress?.toLowerCase() ?? _nativeAddress;
  }

  /// 报价：GET /prices，返回 destAmount（wei 字符串）
  /// 上游 4xx/5xx 时不再抛错，解析 body 中的 error 后返回 null（便于展示友好提示）
  static Future<String?> getPrices({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
    int srcDecimals = 18,
    int destDecimals = 18,
  }) async {
    final network = _chainId(chain);
    final src = _tokenAddress(chain, fromSymbol, fromContract);
    final dest = _tokenAddress(chain, toSymbol, toContract);
    final useProxy = _proxyBase != null && _proxyBase!.isNotEmpty;
    try {
      final resp = await _dioClient.get<dynamic>(
        useProxy ? '$_baseUrl/paraswap/prices' : '$_directBase/prices',
        queryParameters: {
          'srcToken': src,
          'destToken': dest,
          'amount': amountWei,
          'network': network,
          'srcDecimals': srcDecimals,
          'destDecimals': destDecimals,
          'side': 'SELL',
          'version': '5',
        },
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (_) => true,
        ),
      );
      if (resp.statusCode != null && resp.statusCode! >= 400) {
        final body = resp.data;
        String msg = '暂无法获取该交易对报价';
        if (body is Map && body.containsKey('error')) {
          final err = body['error'];
          if (err is String && err.isNotEmpty) msg = err;
        }
        AppLogger.d('[paraswap] prices ${resp.statusCode}: $msg');
        return null;
      }
      final data = resp.data;
      if (data is! Map<String, dynamic>) return null;
      final destAmount = data['destAmount'] ?? (data['priceRoute'] as Map?)?['destAmount'];
      if (destAmount == null) return null;
      return destAmount is String ? destAmount : destAmount.toString();
    } catch (e) {
      AppLogger.d('[paraswap] prices error: $e');
      return null;
    }
  }

  /// 构建交易：先 /prices 取 priceRoute，再 POST /transactions/:network
  static Future<SwapTx?> buildTransaction({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
    required String fromAddress,
    double slippagePercent = 1.0,
    int srcDecimals = 18,
    int destDecimals = 18,
  }) async {
    final network = _chainId(chain);
    final src = _tokenAddress(chain, fromSymbol, fromContract);
    final dest = _tokenAddress(chain, toSymbol, toContract);
    final useProxy = _proxyBase != null && _proxyBase!.isNotEmpty;
    final fromAddr = fromAddress.startsWith('0x') ? fromAddress : '0x$fromAddress';
    try {
      final priceResp = await _dioClient.get<dynamic>(
        useProxy ? '$_baseUrl/paraswap/prices' : '$_directBase/prices',
        queryParameters: {
          'srcToken': src,
          'destToken': dest,
          'amount': amountWei,
          'network': network,
          'srcDecimals': srcDecimals,
          'destDecimals': destDecimals,
          'side': 'SELL',
          'version': '5',
        },
        options: Options(
          responseType: ResponseType.json,
          validateStatus: (_) => true,
        ),
      );
      if (priceResp.statusCode != null && priceResp.statusCode! >= 400) {
        String msg = '暂无法获取该交易对报价';
        final body = priceResp.data;
        if (body is Map && body.containsKey('error')) {
          final err = body['error'];
          if (err is String && err.isNotEmpty) msg = err;
        }
        AppLogger.d('[paraswap] prices ${priceResp.statusCode}: $msg');
        throw Exception(msg);
      }
      final priceData = priceResp.data;
      if (priceData == null || priceData is! Map<String, dynamic>) {
        AppLogger.d('[paraswap] prices empty');
        throw Exception('闪兑报价失败，请稍后重试');
      }
      final priceRoute = priceData['priceRoute'] as Map<String, dynamic>? ?? priceData;
      if (priceRoute.isEmpty) {
        AppLogger.d('[paraswap] no priceRoute in prices');
        throw Exception('闪兑报价无结果，可能流动性不足');
      }
      // ParaSwap：side=SELL 时只传 slippage（基点），不传 destAmount
      final body = {
        'priceRoute': priceRoute,
        'userAddress': fromAddr,
        'srcToken': src,
        'destToken': dest,
        'srcAmount': amountWei,
        'srcDecimals': srcDecimals,
        'destDecimals': destDecimals,
        'slippage': (slippagePercent * 100).round(),
      };

      final txResp = await _dioClient.post<String>(
        useProxy ? '$_baseUrl/paraswap/transactions' : '$_directBase/transactions/$network',
        data: body,
        queryParameters: useProxy ? {'network': network} : null,
        options: Options(
          responseType: ResponseType.plain,
          contentType: Headers.jsonContentType,
          validateStatus: (_) => true,
        ),
      );
      final raw = txResp.data;
      if (txResp.statusCode != null && txResp.statusCode! >= 400) {
        String msg = '闪兑构建交易失败';
        if (raw is String && raw.isNotEmpty) {
          final errData = _parseJson(raw);
          if (errData != null) {
            final err = errData['error'] as String? ?? errData['message'] as String? ?? raw;
            msg = err is String ? err : msg;
          } else if (raw.length < 200) {
            msg = raw;
          }
        }
        AppLogger.d('[paraswap] transactions ${txResp.statusCode}: $msg');
        throw Exception(msg);
      }
      if (raw is! String || raw.isEmpty) {
        AppLogger.d('[paraswap] transactions empty');
        throw Exception('闪兑构建交易失败，请稍后重试');
      }
      final txData = _parseJson(raw);
      if (txData == null) {
        AppLogger.d('[paraswap] transactions invalid json');
        throw Exception('闪兑接口返回格式异常，请稍后重试');
      }
      final err = txData['error'] as String? ?? txData['message'] as String?;
      if (err != null && err.isNotEmpty) {
        AppLogger.d('[paraswap] api error: $err');
        throw Exception(err);
      }
      final to = txData['to'] as String?;
      final data = txData['data'] as String?;
      if (to == null || to.isEmpty || data == null || data.isEmpty) return null;
      final value = txData['value'];
      BigInt valueWei = BigInt.zero;
      if (value != null) {
        if (value is String) {
          final s = value.startsWith('0x') ? value.substring(2) : value;
          valueWei = BigInt.tryParse(s, radix: 16) ?? BigInt.tryParse(value) ?? BigInt.zero;
        } else if (value is int) {
          valueWei = BigInt.from(value);
        }
      }
      final gas = txData['gas'];
      int gasInt = 300000;
      if (gas != null) {
        if (gas is int) gasInt = gas;
        else if (gas is String) gasInt = int.tryParse(gas) ?? 300000;
      }
      final gasPrice = txData['gasPrice'];
      BigInt? gasPriceWei;
      if (gasPrice != null) {
        if (gasPrice is String) gasPriceWei = BigInt.tryParse(gasPrice);
        else if (gasPrice is int) gasPriceWei = BigInt.from(gasPrice);
      }
      return SwapTx(
        to: to,
        data: data,
        valueWei: valueWei,
        gas: gasInt,
        gasPriceWei: gasPriceWei,
      );
    } on DioException catch (e) {
      AppLogger.d('[paraswap] error: $e');
      final msg = e.response?.data is String
          ? (e.response!.data as String).length > 80
              ? '${(e.response!.data as String).substring(0, 80)}...'
              : e.response!.data as String
          : (e.message ?? '');
      throw Exception('闪兑请求失败: $msg');
    }
  }

  static Map<String, dynamic>? _parseJson(dynamic raw) {
    if (raw is! String) return null;
    try {
      final d = jsonDecode(raw);
      return d is Map<String, dynamic> ? d : null;
    } catch (_) {
      return null;
    }
  }
}

/// 聚合器实现：使用 ParaSwap
class ParaSwapAggregator implements SwapAggregator {
  @override
  Future<String?> getQuote({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
  }) async {
    int srcDec = 18, destDec = 18;
    final srcMeta = fromContract != null ? KnownTokens.getMeta(chain, fromContract) : null;
    final destMeta = toContract != null ? KnownTokens.getMeta(chain, toContract) : null;
    if (srcMeta != null) srcDec = srcMeta.decimals;
    if (destMeta != null) destDec = destMeta.decimals;
    return ParaSwapService.getPrices(
      chain: chain,
      fromSymbol: fromSymbol,
      fromContract: fromContract,
      toSymbol: toSymbol,
      toContract: toContract,
      amountWei: amountWei,
      srcDecimals: srcDec,
      destDecimals: destDec,
    );
  }

  @override
  Future<SwapTx?> getSwap({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
    required String fromAddress,
    double slippagePercent = 1.0,
  }) async {
    int srcDec = 18, destDec = 18;
    final srcMeta = fromContract != null ? KnownTokens.getMeta(chain, fromContract) : null;
    final destMeta = toContract != null ? KnownTokens.getMeta(chain, toContract) : null;
    if (srcMeta != null) srcDec = srcMeta.decimals;
    if (destMeta != null) destDec = destMeta.decimals;
    return ParaSwapService.buildTransaction(
      chain: chain,
      fromSymbol: fromSymbol,
      fromContract: fromContract,
      toSymbol: toSymbol,
      toContract: toContract,
      amountWei: amountWei,
      fromAddress: fromAddress,
      slippagePercent: slippagePercent,
      srcDecimals: srcDec,
      destDecimals: destDec,
    );
  }

  @override
  Future<double?> getTokenUsdPriceByQuote({
    required String chain,
    required String tokenSymbol,
    required String? tokenContract,
    required int tokenDecimals,
  }) async {
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
    final usdtAddress =
        chain == KnownTokens.bnbMainnet ? KnownTokens.usdtBsc : KnownTokens.usdtEth;
    final usdtMeta = KnownTokens.getMeta(chain, usdtAddress);
    final usdtDecimals = usdtMeta?.decimals ?? (chain == KnownTokens.bnbMainnet ? 18 : 6);
    final quoteWei = BigInt.tryParse(quote) ?? BigInt.zero;
    if (quoteWei == BigInt.zero) return null;
    final price =
        quoteWei.toDouble() / BigInt.from(10).pow(usdtDecimals).toDouble();
    return price.isFinite && price > 0 ? price : null;
  }
}
