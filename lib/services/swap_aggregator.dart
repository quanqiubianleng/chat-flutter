import 'package:education/config/app_env.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/services/oneinch_service.dart';
import 'package:education/services/paraswap_service.dart';
import 'package:education/services/server_swap_service.dart';

/// 闪兑聚合器统一返回的 tx 结构（与 EvmTransferService.sendSwapTransaction 入参一致）
class SwapTx {
  final String to;
  final String data;
  final BigInt valueWei;
  final int gas;
  final BigInt? gasPriceWei;

  const SwapTx({
    required this.to,
    required this.data,
    required this.valueWei,
    required this.gas,
    this.gasPriceWei,
  });
}

/// 闪兑聚合器抽象：报价 + 构建交易，按配置切换 1inch / ParaSwap
abstract class SwapAggregator {
  /// 报价：返回预计得到的 toToken 数量（wei 字符串），失败返回 null
  Future<String?> getQuote({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
  });

  /// 构建 swap 交易数据，用于后续签名并广播
  Future<SwapTx?> getSwap({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
    required String fromAddress,
    double slippagePercent = 1.0,
  });

  /// 通过报价估算某代币的 USD 单价（以 USDT 为计价），失败返回 null
  Future<double?> getTokenUsdPriceByQuote({
    required String chain,
    required String tokenSymbol,
    required String? tokenContract,
    required int tokenDecimals,
  });
}

/// 当前生效的聚合器：单链优先走服务器 → 链上，失败或非 BNB 链回退到第三方
SwapAggregator get swapAggregator {
  final fallback = currentEnv.swapProvider == SwapProvider.oneinch
      ? OneInchAggregator()
      : ParaSwapAggregator();
  return ServerFirstSwapAggregator(fallback);
}

/// 单链优先服务器（App → 服务器 → 链上），跨链/失败时回退到第三方聚合器
class ServerFirstSwapAggregator implements SwapAggregator {
  final SwapAggregator _fallback;

  ServerFirstSwapAggregator(this._fallback);

  @override
  Future<String?> getQuote({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
  }) async {
    final isBbtPair = fromSymbol == 'BBT' || toSymbol == 'BBT';
    try {
      final serverQuote = await ServerSwapService.getQuote(
        chain: chain,
        fromSymbol: fromSymbol,
        fromContract: fromContract,
        toSymbol: toSymbol,
        toContract: toContract,
        amountWei: amountWei,
      );
      if (serverQuote != null && serverQuote.isNotEmpty) return serverQuote;
    } catch (_) {
      if (chain == KnownTokens.bnbMainnet && isBbtPair) rethrow;
    }
    if (chain == KnownTokens.bnbMainnet && isBbtPair) return null;
    return _fallback.getQuote(
      chain: chain,
      fromSymbol: fromSymbol,
      fromContract: fromContract,
      toSymbol: toSymbol,
      toContract: toContract,
      amountWei: amountWei,
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
    final isBbtPair = fromSymbol == 'BBT' || toSymbol == 'BBT';
    try {
      final serverTx = await ServerSwapService.build(
        chain: chain,
        fromSymbol: fromSymbol,
        fromContract: fromContract,
        toSymbol: toSymbol,
        toContract: toContract,
        amountWei: amountWei,
        fromAddress: fromAddress,
        slippagePercent: slippagePercent,
      );
      if (serverTx != null) {
        return SwapTx(
          to: serverTx.to,
          data: serverTx.data,
          valueWei: serverTx.valueWei,
          gas: serverTx.gas,
          gasPriceWei: serverTx.gasPriceWei,
        );
      }
    } catch (e) {
      // BNB 链且涉及 BBT 时把服务端错误抛给上层展示；其他情况回退 ParaSwap
      if (chain == KnownTokens.bnbMainnet && isBbtPair) rethrow;
    }
    if (chain == KnownTokens.bnbMainnet && isBbtPair) return null;
    return _fallback.getSwap(
      chain: chain,
      fromSymbol: fromSymbol,
      fromContract: fromContract,
      toSymbol: toSymbol,
      toContract: toContract,
      amountWei: amountWei,
      fromAddress: fromAddress,
      slippagePercent: slippagePercent,
    );
  }

  @override
  Future<double?> getTokenUsdPriceByQuote({
    required String chain,
    required String tokenSymbol,
    required String? tokenContract,
    required int tokenDecimals,
  }) =>
      _fallback.getTokenUsdPriceByQuote(
        chain: chain,
        tokenSymbol: tokenSymbol,
        tokenContract: tokenContract,
        tokenDecimals: tokenDecimals,
      );
}

/// 1inch 实现
class OneInchAggregator implements SwapAggregator {
  @override
  Future<String?> getQuote({
    required String chain,
    required String fromSymbol,
    required String? fromContract,
    required String toSymbol,
    required String? toContract,
    required String amountWei,
  }) =>
      OneInchService.getQuote(
        chain: chain,
        fromSymbol: fromSymbol,
        fromContract: fromContract,
        toSymbol: toSymbol,
        toContract: toContract,
        amountWei: amountWei,
      );

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
    final tx = await OneInchService.getSwap(
      chain: chain,
      fromSymbol: fromSymbol,
      fromContract: fromContract,
      toSymbol: toSymbol,
      toContract: toContract,
      amountWei: amountWei,
      fromAddress: fromAddress,
      slippagePercent: slippagePercent,
    );
    if (tx == null) return null;
    return SwapTx(
      to: tx.to,
      data: tx.data,
      valueWei: tx.valueWei,
      gas: tx.gas,
      gasPriceWei: tx.gasPriceWei,
    );
  }

  @override
  Future<double?> getTokenUsdPriceByQuote({
    required String chain,
    required String tokenSymbol,
    required String? tokenContract,
    required int tokenDecimals,
  }) =>
      OneInchService.getTokenUsdPriceByQuote(
        chain: chain,
        tokenSymbol: tokenSymbol,
        tokenContract: tokenContract,
        tokenDecimals: tokenDecimals,
      );
}
