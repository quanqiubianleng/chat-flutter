import 'package:dio/dio.dart';
import 'package:education/config/app_config.dart';
import 'package:education/config/known_tokens.dart';

/// 单链闪兑：App → 服务器 → 链上 DEX（当前仅支持 BNB Chain）
/// 接口：POST /v1/swap/quote、POST /v1/swap/build
class ServerSwapService {
  static Dio? _dio;
  static Dio get _client {
    _dio ??= Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (_) => true, // 不因 4xx/5xx 抛异常，由调用方根据 statusCode 判断
    ));
    return _dio!;
  }

  static String get _baseUrl {
    final base = AppConfig.reqUrl.replaceFirst(RegExp(r'/$'), '');
    return '$base/v1';
  }

  /// 将前端 fromSymbol/fromContract 转为接口 fromToken：原生币为 "BNB"/"ETH"，否则为合约地址
  static String _toTokenParam(String symbol, String? contract) {
    if (symbol == 'BNB' || symbol == 'ETH') return symbol;
    if (contract != null && contract.isNotEmpty) {
      return contract.startsWith('0x') ? contract : '0x$contract';
    }
    return symbol;
  }

  /// 从响应中解析服务端返回的 error/message，用于抛给上层展示
  static String? _parseError(Map<String, dynamic>? data) {
    if (data == null) return null;
    final msg = data['message']?.toString() ?? data['error']?.toString();
    return msg != null && msg.isNotEmpty ? msg : null;
  }

  /// 单链报价：返回预计得到的 toToken 数量（wei 字符串），失败返回 null；4xx/5xx 时抛 Exception(服务端原因)
  static Future<String?> getQuote({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
  }) async {
    if (chain != KnownTokens.bnbMainnet) return null;
    final resp = await _client.post<Map<String, dynamic>>(
      '$_baseUrl/swap/quote',
      data: {
        'chain': chain,
        'fromToken': _toTokenParam(fromSymbol, fromContract),
        'toToken': _toTokenParam(toSymbol, toContract),
        'amountWei': amountWei,
      },
    );
    if (resp.data == null || resp.statusCode != 200) {
      final err = _parseError(resp.data);
      throw Exception(err ?? '报价请求失败');
    }
    final payload = resp.data!['data'] as Map<String, dynamic>? ?? resp.data!;
    final out = payload['amountOutWei']?.toString();
    if (out == null || out == '0') return null;
    return out;
  }

  /// 构建单链闪兑交易，返回 SwapTx 所需字段；失败返回 null；4xx/5xx 时抛 Exception(服务端原因)
  static Future<ServerSwapTx?> build({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
    required String fromAddress,
    double slippagePercent = 1.0,
  }) async {
    if (chain != KnownTokens.bnbMainnet) return null;
    final resp = await _client.post<Map<String, dynamic>>(
      '$_baseUrl/swap/build',
      data: {
        'chain': chain,
        'fromToken': _toTokenParam(fromSymbol, fromContract),
        'toToken': _toTokenParam(toSymbol, toContract),
        'amountWei': amountWei,
        'fromAddress': fromAddress.startsWith('0x') ? fromAddress : '0x$fromAddress',
        'slippageBps': (slippagePercent * 100).round(),
      },
    );
    if (resp.data == null || resp.statusCode != 200) {
      final err = _parseError(resp.data);
      throw Exception(err ?? '构建交易失败');
    }
    // 网关返回扁平 JSON：{ "to", "data", "value", "gasLimit" }，不要将 data 当嵌套 Map
    final d = resp.data!;
    final to = d['to']?.toString();
    final data = d['data']?.toString();
    if (to == null || to.isEmpty || data == null || data.isEmpty) return null;
    final value = d['value']?.toString() ?? '0';
    final gasLimit = d['gasLimit'] is int
        ? d['gasLimit'] as int
        : int.tryParse(d['gasLimit']?.toString() ?? '300000') ?? 300000;
    final valueWei = BigInt.tryParse(value) ?? BigInt.zero;
    return ServerSwapTx(
      to: to,
      data: data,
      valueWei: valueWei,
      gas: gasLimit,
      gasPriceWei: null,
    );
  }
}

class ServerSwapTx {
  final String to;
  final String data;
  final BigInt valueWei;
  final int gas;
  final BigInt? gasPriceWei;
  ServerSwapTx({
    required this.to,
    required this.data,
    required this.valueWei,
    required this.gas,
    this.gasPriceWei,
  });
}
