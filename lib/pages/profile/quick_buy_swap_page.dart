import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:education/config/app_config.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/services/alchemy_service.dart';
import 'package:education/services/evm_transfer_service.dart';
import 'package:education/services/coingecko_service.dart';
import 'package:education/services/swap_aggregator.dart';
import 'package:education/services/user_service.dart';
import 'package:education/pages/profile/swap_token_sheet.dart';
import 'package:education/widgets/common/token_avatar.dart';
import 'package:education/pages/profile/token_kline_page.dart';
import 'package:education/pages/profile/swap_history_page.dart';
import 'package:education/widgets/account/verify_password_dialog.dart';
import 'package:url_launcher/url_launcher.dart';

/// 快速购买 / 闪兑 页（BBT）：Tab 切换、代币选择、余额、汇率、滑点、确认弹窗
class QuickBuySwapPage extends StatefulWidget {
  final String walletAddress;
  final String chain;
  /// 初始 Tab：0 快速购买，1 闪兑
  final int initialTabIndex;

  const QuickBuySwapPage({
    super.key,
    required this.walletAddress,
    this.chain = 'bnb-mainnet',
    this.initialTabIndex = 0,
  });

  @override
  State<QuickBuySwapPage> createState() => _QuickBuySwapPageState();
}

class _QuickBuySwapPageState extends State<QuickBuySwapPage> {
  static const Color _green = Color(0xFF00D1A7);
  static const Color _darkBg = Color(0xFF1A1A1A);

  late int _tabIndex;
  bool _isBuy = true;
  final TextEditingController _amountController = TextEditingController(text: '');
  final TextEditingController _fromAmountController = TextEditingController(text: '');
  final TextEditingController _toAmountController = TextEditingController(text: '');

  String get _chainKey => widget.chain == 'x-layer' ? KnownTokens.xLayer : widget.chain;
  String get _networkName {
    switch (widget.chain) {
      case AlchemyService.bnbMainnet: return 'BNB Chain';
      case AlchemyService.ethMainnet: return 'Ethereum';
      case 'base-mainnet': return 'Base';
      case 'x-layer': return 'X Layer';
      default: return 'BNB Chain';
    }
  }

  SwapTokenOption? _fromToken;
  SwapTokenOption? _toToken;
  double _slippagePercent = 1.0;
  double? _ethPrice;
  double? _bnbPrice;
  double? _bbtPrice;
  SwapTokenOption? _quickBuyToken;
  String _nativeBalance = '0';
  bool _balanceLoading = false;
  /// 当前选中的钱包地址（可从右上角第一个按钮切换）
  String _selectedWalletAddress = '';
  List<Map<String, dynamic>> _accountList = [];
  bool _swapLoading = false;
  Timer? _quoteDebounce;
  bool _quoteLoading = false;

  /// 按链返回预留 gas（wei）。用原生币兑换时，交易 = value(兑换额) + gas，故预留需覆盖单笔 swap 的 gas。
  BigInt get _gasReserveWei {
    switch (widget.chain) {
      case AlchemyService.ethMainnet:
        return BigInt.from(1000000000000000); // 0.001 ETH
      case 'base-mainnet':
        return BigInt.from(500000000000000); // 0.0005
      case 'x-layer':
        return BigInt.from(500000000000000); // 0.0005
      case AlchemyService.bnbMainnet:
      default:
        // BSC 上 swap 约 20 万 gas × 5 Gwei ≈ 0.001 BNB，预留 0.002 更稳
        return BigInt.from(2000000000000000); // 0.002 BNB
    }
  }

  @override
  void initState() {
    super.initState();
    _tabIndex = widget.initialTabIndex.clamp(0, 1);
    _selectedWalletAddress = widget.walletAddress;
    _initDefaultTokens();
    _fetchPrices();
    _loadNativeBalance();
    _loadTokenBalancesForSwap();
  }

  void _initDefaultTokens() {
    final nativeSym = widget.chain == AlchemyService.bnbMainnet ? 'BNB' : 'ETH';
    _fromToken ??= SwapTokenOption(symbol: nativeSym, balanceWeiStr: '0', decimals: 18, formattedBalance: '0', iconColor: _green);
    _toToken ??= SwapTokenOption(symbol: 'USDT', balanceWeiStr: '0', decimals: widget.chain == KnownTokens.bnbMainnet ? 18 : 6, contractAddress: widget.chain == KnownTokens.bnbMainnet ? KnownTokens.usdtBsc : KnownTokens.usdtEth, formattedBalance: '0', iconColor: const Color(0xFF26A17B));
    _quickBuyToken ??= _toToken;
  }

  Future<void> _fetchPrices() async {
    final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8), receiveTimeout: const Duration(seconds: 8)));
    if (AppConfig.isDebug) {
      dio.httpClientAdapter = IOHttpClientAdapter(createHttpClient: () {
        final client = HttpClient();
        client.badCertificateCallback = (_, __, ___) => true;
        return client;
      });
    }
    // 并行拉取：Binance 失败不影响 BBT，BBT 单独走网关
    double? ethP;
    double? bnbP;
    double? bbtPrice;
    try {
      final ethR = await dio.get('https://api.binance.com/api/v3/ticker/price',
          queryParameters: {'symbol': 'ETHUSDT'});
      if (ethR.data is Map) {
        final v = (ethR.data as Map)['price'];
        ethP = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
      }
    } catch (_) {}
    try {
      final bnbR = await dio.get('https://api.binance.com/api/v3/ticker/price',
          queryParameters: {'symbol': 'BNBUSDT'});
      if (bnbR.data is Map) {
        final v = (bnbR.data as Map)['price'];
        bnbP = v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '');
      }
    } catch (_) {}
    try {
      bbtPrice = await CoinGeckoService.getBbtPriceFromBsc();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _ethPrice = ethP != null && ethP > 0 ? ethP : 3500;
      _bnbPrice = bnbP != null && bnbP > 0 ? bnbP : 600;
      _bbtPrice = bbtPrice;
    });
  }

  Future<void> _loadNativeBalance() async {
    final addr = _selectedWalletAddress.isNotEmpty ? _selectedWalletAddress : widget.walletAddress;
    if (addr.isEmpty || !addr.startsWith('0x') || !AlchemyService.isAvailable) return;
    setState(() => _balanceLoading = true);
    try {
      final wei = await AlchemyService().getNativeBalance(addr, chain: widget.chain);
      if (mounted) {
        setState(() {
          _nativeBalance = wei ?? '0';
          _balanceLoading = false;
          if (_fromToken != null && (_fromToken!.symbol == 'BNB' || _fromToken!.symbol == 'ETH')) {
            _fromToken = SwapTokenOption(symbol: _fromToken!.symbol, balanceWeiStr: _nativeBalance, decimals: 18, contractAddress: null, formattedBalance: KnownTokens.formatBalanceDisplay(_nativeBalance, 18, maxDecimals: 6), iconColor: _fromToken!.iconColor);
          }
          if (_quickBuyToken != null && (_quickBuyToken!.symbol == 'BNB' || _quickBuyToken!.symbol == 'ETH')) {
            _quickBuyToken = SwapTokenOption(symbol: _quickBuyToken!.symbol, balanceWeiStr: _nativeBalance, decimals: 18, contractAddress: null, formattedBalance: KnownTokens.formatBalanceDisplay(_nativeBalance, 18, maxDecimals: 6), iconColor: _quickBuyToken!.iconColor);
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _balanceLoading = false);
    }
  }

  double? _priceForSymbol(String symbol) {
    if (symbol == 'USDT') return 1.0;
    if (symbol == 'BNB') return _bnbPrice;
    if (symbol == 'ETH') return _ethPrice;
    if (symbol == 'BBT') return _bbtPrice;
    return null;
  }

  String _priceDisplay(String symbol) {
    final p = _priceForSymbol(symbol);
    if (p == null) return '--';
    if (p >= 1) return '\$${p.toStringAsFixed(2)}';
    return '\$${p.toStringAsFixed(4)}';
  }

  String _marketCapDisplay(String symbol) {
    // 暂无市值接口，统一显示暂无
    return '暂无';
  }

  /// 代币符号 -> USD 单价，传给选择弹窗用于展示价值
  Map<String, double> get _tokenPricesMap => {
    'BNB': _bnbPrice ?? 0,
    'ETH': _ethPrice ?? 0,
    'USDT': 1.0,
    'BBT': _bbtPrice ?? 0,
  };

  String get _referenceRateText {
    if (_fromToken == null || _toToken == null) return '--';
    final fromP = _priceForSymbol(_fromToken!.symbol);
    final toP = _priceForSymbol(_toToken!.symbol);
    if (fromP == null || toP == null || toP == 0) return '--';
    final rate = fromP / toP;
    return '1 ${_fromToken!.symbol} ≈ ${rate.toStringAsFixed(4)} ${_toToken!.symbol}';
  }

  /// 根据「从」金额与两边价格估算「至」金额；同币种或缺价格时返回 null，避免「至」被误显为与输入相同
  double? get _estimatedToAmount {
    final fromStr = _fromAmountController.text.trim();
    if (fromStr.isEmpty) return null;
    final fromVal = double.tryParse(fromStr);
    if (fromVal == null || fromVal <= 0 || _fromToken == null || _toToken == null) return null;
    if (_fromToken!.symbol == _toToken!.symbol) return null;
    final fromP = _priceForSymbol(_fromToken!.symbol);
    final toP = _priceForSymbol(_toToken!.symbol);
    if (fromP == null || toP == null || toP == 0) return null;
    return fromVal * fromP / toP;
  }

  bool get _canSwap {
    if (_fromToken == null || _toToken == null || _fromToken!.symbol == _toToken!.symbol) return false;
    final fromStr = _fromAmountController.text.trim();
    if (fromStr.isEmpty) return false;
    final fromVal = double.tryParse(fromStr);
    if (fromVal == null || fromVal <= 0) return false;
    final balanceWei = BigInt.tryParse(_fromToken!.balanceWeiStr) ?? BigInt.zero;
    final amountWei = BigInt.from((fromVal * _pow10(_fromToken!.decimals)).round());
    return amountWei <= balanceWei;
  }

  double _pow10(int exp) {
    double r = 1;
    for (int i = 0; i < exp; i++) r *= 10;
    return r;
  }

  @override
  void dispose() {
    _quoteDebounce?.cancel();
    _amountController.dispose();
    _fromAmountController.dispose();
    _toAmountController.dispose();
    super.dispose();
  }

  void _showSlippageSheet() {
    final controller = TextEditingController(text: _slippagePercent.toString());
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text('滑点容差', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
            ),
            ListTile(
              title: const Text('0.5%'),
              trailing: _slippagePercent == 0.5 ? const Icon(Icons.check, color: _green) : null,
              onTap: () { setState(() => _slippagePercent = 0.5); Navigator.pop(ctx); },
            ),
            ListTile(
              title: const Text('1%'),
              trailing: _slippagePercent == 1 ? const Icon(Icons.check, color: _green) : null,
              onTap: () { setState(() => _slippagePercent = 1); Navigator.pop(ctx); },
            ),
            ListTile(
              title: const Text('3%'),
              trailing: _slippagePercent == 3 ? const Icon(Icons.check, color: _green) : null,
              onTap: () { setState(() => _slippagePercent = 3); Navigator.pop(ctx); },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Text('自定义'),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      controller: controller,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(isDense: true, suffixText: '%'),
                      onSubmitted: (v) {
                        final n = double.tryParse(v);
                        if (n != null && n >= 0.1 && n <= 50) { setState(() => _slippagePercent = n); Navigator.pop(ctx); }
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () {
                final n = double.tryParse(controller.text);
                if (n != null && n >= 0.1 && n <= 50) setState(() => _slippagePercent = n);
                Navigator.pop(ctx);
              },
              style: FilledButton.styleFrom(backgroundColor: _green),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSwapConfirmSheet() async {
    final fromAmt = _fromAmountController.text.trim();
    final toAmt = _estimatedToAmount?.toStringAsFixed(6) ?? '--';
    setState(() => _swapLoading = true);
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const Padding(
              padding: EdgeInsets.all(20),
              child: Text('确认闪兑', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            _confirmRow('支付', '$fromAmt ${_fromToken?.symbol ?? ''}'),
            _confirmRow('预计获得', '$toAmt ${_toToken?.symbol ?? ''}'),
            _confirmRow('参考汇率', _referenceRateText),
            _confirmRow('滑点容差', '${_slippagePercent.toStringAsFixed(1)}%'),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: _green, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('确认闪兑'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      if (mounted) setState(() => _swapLoading = false);
      return;
    }
    await _executeFlashSwap();
  }

  Future<void> _executeFlashSwap() async {
    final from = _fromToken;
    final to = _toToken;
    final fromStr = _fromAmountController.text.trim();
    if (from == null || to == null || from.symbol == to.symbol || fromStr.isEmpty) return;
    final fromVal = double.tryParse(fromStr);
    if (fromVal == null || fromVal <= 0) return;
    final amountWei = BigInt.from((fromVal * _pow10(from.decimals)).round());
    if (amountWei <= BigInt.zero) return;
    final fromAddress = widget.walletAddress;
    if (fromAddress.isEmpty || !fromAddress.startsWith('0x')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前钱包地址无效')));
      return;
    }
    final didId = await UserCache.getDid();
    if (didId == null || didId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    final privateKey = await VerifyPasswordDialog.showForPrivateKey(context, didId: didId);
    if (privateKey == null || !mounted) return;
    setState(() => _swapLoading = true);
    try {
      final swapTx = await swapAggregator.getSwap(
        chain: widget.chain,
        fromSymbol: from.symbol,
        fromContract: from.contractAddress,
        toSymbol: to.symbol,
        toContract: to.contractAddress,
        amountWei: amountWei.toString(),
        fromAddress: fromAddress,
        slippagePercent: _slippagePercent,
      );
      if (swapTx == null) {
        if (mounted) _showNoQuoteFeedback(context, from.symbol, to.symbol, _noQuoteMessage(from.symbol, to.symbol, widget.chain));
        return;
      }
      if (!mounted) return;
      // 发送前检查原生币余额是否足够支付 gas（BNB 链约需 0.002 BNB），不足则直接提示不发交易
      final nativeWei = BigInt.tryParse(_nativeBalance) ?? BigInt.zero;
      if (nativeWei < _gasReserveWei && mounted) {
        final curStr = KnownTokens.formatBalanceDisplay(_nativeBalance, 18, maxDecimals: 6);
        final needStr = KnownTokens.formatBalanceDisplay(_gasReserveWei.toString(), 18, maxDecimals: 6);
        final gasHint = widget.chain == KnownTokens.bnbMainnet
            ? 'BNB 余额不足，无法支付 gas 费。当前约 $curStr BNB，建议至少 $needStr BNB。请先转入 BNB 后再试闪兑。'
            : '原生币余额不足，无法支付 gas 费。当前约 $curStr，建议至少 $needStr。请先转入后再试。';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(gasHint), duration: const Duration(seconds: 6)));
        return;
      }
      // BNB 链且交易目标是 PancakeSwap Router 时，发送前先检查 ERC20 授权，不足则弹窗授权（避免链上执行失败才提示）
      if (widget.chain == KnownTokens.bnbMainnet &&
          from.contractAddress != null &&
          from.contractAddress!.isNotEmpty &&
          swapTx.to.toLowerCase() == KnownTokens.pancakeRouterBsc.toLowerCase()) {
        final allowance = await EvmTransferService.getErc20Allowance(
          tokenContractAddress: from.contractAddress!,
          ownerAddress: fromAddress,
          spenderAddress: KnownTokens.pancakeRouterBsc,
          networkId: widget.chain,
        );
        if (allowance == null || allowance < amountWei) {
          final doApprove = await _showPancakeAllowanceDialog(context, fromSymbol: from.symbol);
          if (doApprove != true || !mounted) return;
          await _doApproveAndNotify(
            context,
            didId: didId!,
            tokenContractAddress: from.contractAddress!,
            spenderAddress: KnownTokens.pancakeRouterBsc,
            fromAddress: fromAddress,
            networkId: widget.chain,
          );
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('已授权，请再次点击「确认闪兑」完成兑换')),
          );
          return;
        }
      }
      final txHash = await EvmTransferService.sendSwapTransaction(
        fromAddress: fromAddress,
        toAddress: swapTx.to,
        dataHex: swapTx.data,
        valueWei: swapTx.valueWei,
        gasLimit: swapTx.gas,
        gasPriceWei: swapTx.gasPriceWei,
        privateKeyHex: privateKey,
        networkId: widget.chain,
      );
      if (!mounted) return;
      _showSwapSuccessSnackBar(context, txHash);
      _fromAmountController.clear();
      _toAmountController.clear();
      _loadNativeBalance();
      _loadTokenBalancesForSwap();
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final friendly = _swapFriendlyError(msg);
        if (_isNoQuoteError(msg)) {
          _showNoQuoteFeedback(context, from.symbol, to.symbol, _noQuoteMessage(from.symbol, to.symbol, widget.chain));
        } else if (_isAllowanceError(msg)) {
          final spender = _parseSpenderFromAllowanceError(msg);
          if (spender != null &&
              from.contractAddress != null &&
              from.contractAddress!.isNotEmpty) {
            final doApprove = await _showAllowanceErrorDialog(
              context,
              fromSymbol: from.symbol,
            );
            if (doApprove == true && mounted) {
              await _doApproveAndNotify(
                context,
                didId: didId!,
                tokenContractAddress: from.contractAddress!,
                spenderAddress: spender,
                fromAddress: fromAddress,
                networkId: widget.chain,
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('闪兑失败: $friendly')));
          }
        } else if (_isTransferFromFailedError(msg) &&
            widget.chain == KnownTokens.bnbMainnet &&
            from.contractAddress != null &&
            from.contractAddress!.isNotEmpty) {
          final doApprove = await _showAllowanceErrorDialog(context, fromSymbol: from.symbol);
          if (doApprove == true && mounted) {
            await _doApproveAndNotify(
              context,
              didId: didId!,
              tokenContractAddress: from.contractAddress!,
              spenderAddress: KnownTokens.pancakeRouterBsc,
              fromAddress: fromAddress,
              networkId: widget.chain,
            );
          }
        } else {
          final isBbtPair = from.symbol == 'BBT' || to.symbol == 'BBT';
          final serverReason = _extractServerError(msg);
          if (_isGasInsufficientError(msg)) {
            final curStr = KnownTokens.formatBalanceDisplay(_nativeBalance, 18, maxDecimals: 6);
            final needStr = KnownTokens.formatBalanceDisplay(_gasReserveWei.toString(), 18, maxDecimals: 6);
            final gasHint = widget.chain == KnownTokens.bnbMainnet
                ? 'BNB 余额不足，无法支付 gas 费。当前约 $curStr BNB，建议至少 $needStr BNB。请先转入 BNB 后再试。'
                : '原生币余额不足，无法支付 gas 费。当前约 $curStr，建议至少 $needStr。请先转入后再试。';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(gasHint), duration: const Duration(seconds: 6)),
            );
          } else if (_isTxSendError(msg)) {
            final hint = isBbtPair
                ? '交易提交失败，请检查 BNB 余额（gas 费）或稍后重试'
                : '交易提交失败，请检查余额与网络';
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(serverReason != null ? '$hint\n$serverReason' : hint), duration: const Duration(seconds: 5)),
            );
          } else if (isBbtPair) {
            _showNoQuoteFeedback(context, from.symbol, to.symbol, _noQuoteMessage(from.symbol, to.symbol, widget.chain), serverDetail: serverReason);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('闪兑失败: $friendly')));
          }
        }
      }
    } finally {
      if (mounted) setState(() => _swapLoading = false);
    }
  }

  /// 无报价/不支持时的提示文案。BBT 在 BNB 链走单链闪兑服务，其他链/失败时提示聚合器或服务不可用。
  static String _noQuoteMessage(String fromSymbol, String toSymbol, [String? chain]) {
    final isBbt = fromSymbol == 'BBT' || toSymbol == 'BBT';
    if (isBbt) {
      if (chain == KnownTokens.bnbMainnet) {
        return 'BBT 单链闪兑暂不可用，请检查网络或确认网关已部署单链闪兑接口（/v1/swap/quote、/v1/swap/build）后重试。';
      }
      return '当前聚合器暂不支持 BBT 交易对闪兑，请使用其他代币或切换至 BNB 链使用单链闪兑。';
    }
    return '当前交易对暂无报价，请更换代币或稍后重试。';
  }

  /// 是否为「无报价」类错误（聚合器不支持该交易对等）
  static bool _isNoQuoteError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('bad usd price') ||
        lower.contains('暂无报价') ||
        lower.contains('暂无法获取') ||
        lower.contains('no quote') ||
        lower.contains('price not available');
  }

  /// 是否为「gas 费不足」类错误（BNB/ETH 余额不够支付链上 gas）
  static bool _isGasInsufficientError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('insufficient funds for gas') ||
        (lower.contains('insufficient') && lower.contains('balance') && (lower.contains('gas') || lower.contains('value')));
  }

  /// 是否为「链上提交交易」阶段错误（build 已成功，发送 tx 时 RPC/链返回的错误）
  static bool _isTxSendError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('rpc error') ||
        lower.contains('sendtransaction') ||
        lower.contains('insufficient funds for gas') ||
        lower.contains('nonce') ||
        lower.contains('transaction underpriced') ||
        lower.contains('revert') ||
        lower.contains('execution reverted');
  }

  /// 从异常信息中取出服务端返回的可读原因（去掉 "Exception:" 等前缀）
  static String? _extractServerError(String msg) {
    final s = msg.replaceFirst(RegExp(r'^Exception:\s*'), '').trim();
    if (s.isEmpty || s == '报价请求失败' || s == '构建交易失败') return null;
    return s;
  }

  /// 闪兑提交成功后的提示：说明需等待确认、获得代币到账当前钱包，并提供「查看交易」跳转区块浏览器
  void _showSwapSuccessSnackBar(BuildContext context, String txHash) {
    if (!context.mounted) return;
    final chain = widget.chain;
    final isBsc = chain == KnownTokens.bnbMainnet;
    final explorerBase = isBsc ? 'https://bscscan.com' : (chain == 'base-mainnet' ? 'https://basescan.org' : 'https://etherscan.io');
    final txUrl = '$explorerBase/tx/${txHash.startsWith('0x') ? txHash : '0x$txHash'}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('闪兑已提交，请等待区块确认。获得的 BNB/BBT 等将到账当前钱包，可在区块浏览器查看交易状态。'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: '查看交易',
          onPressed: () async {
            final uri = Uri.parse(txUrl);
            if (await canLaunchUrl(uri)) launchUrl(uri, mode: LaunchMode.externalApplication);
          },
        ),
      ),
    );
  }

  /// 无报价时提示：BBT 对用 SnackBar（可带服务端原因），其他用弹窗
  static void _showNoQuoteFeedback(BuildContext context, String fromSymbol, String toSymbol, String message, {String? serverDetail}) {
    if (!context.mounted) return;
    final isBbtPair = fromSymbol == 'BBT' || toSymbol == 'BBT';
    if (isBbtPair) {
      final text = serverDetail != null && serverDetail.isNotEmpty ? '$message\n$serverDetail' : message;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), duration: const Duration(seconds: 5)));
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('暂无报价'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 无报价时弹窗提示（用于输入金额后无报价等场景）
  static Future<void> _showNoQuoteDialog(BuildContext context, {String? message}) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('暂无报价'),
        content: Text(message ?? '当前交易对暂无报价，请稍后重试或更换代币。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('知道了'),
          ),
        ],
      ),
    );
  }

  /// 授权不足时弹窗：是否现在授权
  static Future<bool?> _showAllowanceErrorDialog(BuildContext context, {required String fromSymbol}) async {
    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要授权'),
        content: Text('需要先授权 $fromSymbol 给闪兑合约才能继续。是否现在授权？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('去授权'),
          ),
        ],
      ),
    );
  }

  /// 对 PancakeSwap Router 授权（BNB 链闪兑前检查）：弹窗提示并让用户选择是否授权
  static Future<bool?> _showPancakeAllowanceDialog(BuildContext context, {required String fromSymbol}) async {
    if (!context.mounted) return null;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('需要授权'),
        content: Text('需要先授权 $fromSymbol 给 PancakeSwap 才能进行闪兑。是否现在授权？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('去授权'),
          ),
        ],
      ),
    );
  }

  /// 执行 ERC20 授权（无限额度），成功后提示用户再次点击确认闪兑
  static Future<void> _doApproveAndNotify(
    BuildContext context, {
    required String didId,
    required String tokenContractAddress,
    required String spenderAddress,
    required String fromAddress,
    required String networkId,
  }) async {
    final privateKey = await VerifyPasswordDialog.showForPrivateKey(context, didId: didId);
    if (privateKey == null || !context.mounted) return;
    try {
      final maxUint256 = (BigInt.from(2).pow(256)) - BigInt.one;
      final txHash = await EvmTransferService.sendErc20Approve(
        fromAddress: fromAddress,
        tokenContractAddress: tokenContractAddress,
        spenderAddress: spenderAddress,
        amountWei: maxUint256,
        privateKeyHex: privateKey,
        networkId: networkId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('授权成功\n$txHash\n请再次点击「确认闪兑」完成交易')),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('授权失败: ${e.toString().replaceAll(RegExp(r'Exception:?\s*'), '')}')),
        );
      }
    }
  }

  /// 是否为「授权不足」类错误（需先 approve 代币给闪兑合约）
  static bool _isAllowanceError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('not enough') && lower.contains('allowance') ||
        lower.contains('tokentransferproxy') ||
        lower.contains('allowance given');
  }

  /// 是否为 PancakeSwap Router 的 TRANSFER_FROM_FAILED（未授权或额度不足，需对 Router 授权）
  static bool _isTransferFromFailedError(String msg) {
    final lower = msg.toLowerCase();
    return lower.contains('transfer_from_failed') ||
        lower.contains('transferhelper');
  }

  /// 从 ParaSwap 错误文案中解析出授权合约地址，如 TokenTransferProxy(0x...)
  static String? _parseSpenderFromAllowanceError(String msg) {
    final reg = RegExp(r'0x[a-fA-F0-9]{40}');
    final m = reg.firstMatch(msg);
    return m?.group(0);
  }

  /// 将异常信息转为用户可读提示：区分「报价已变」「余额/滑点」「授权不足」「链上提交」与其它
  static String _swapFriendlyError(String msg) {
    final lower = msg.toLowerCase();
    if (lower.contains('rate has changed') || lower.contains('re-query') || lower.contains('报价已变')) {
      return '报价已变化，请调高滑点或重新尝试';
    }
    if (lower.contains('insufficient') || lower.contains('余额') || lower.contains('not enough balance')) {
      return '余额不足或滑点过小';
    }
    if (_isAllowanceError(msg)) {
      return '请先授权该代币给闪兑合约后再试';
    }
    if (_isTransferFromFailedError(msg)) {
      return '请先授权该代币给 PancakeSwap 后再试';
    }
    if (_isTxSendError(msg)) {
      return '链上提交失败，请检查余额与网络或稍后重试';
    }
    if (msg.length > 60) return '${msg.substring(0, 60)}...';
    return msg;
  }

  Future<void> _loadTokenBalancesForSwap() async {
    if (!AlchemyService.isAvailable || _selectedWalletAddress.isEmpty) return;
    try {
      final chainKey = widget.chain == 'x-layer' ? KnownTokens.xLayer : widget.chain;
      final tracked = KnownTokens.getTrackedContractAddresses(chainKey);
      final result = await AlchemyService().getTokenBalances(_selectedWalletAddress.isNotEmpty ? _selectedWalletAddress : widget.walletAddress, chain: widget.chain, contractAddresses: tracked.isEmpty ? null : tracked);
      final nativeWei = await AlchemyService().getNativeBalance(_selectedWalletAddress.isNotEmpty ? _selectedWalletAddress : widget.walletAddress, chain: widget.chain);
      if (!mounted) return;
      final nativeSym = widget.chain == AlchemyService.bnbMainnet ? 'BNB' : 'ETH';
      if (_fromToken != null && (_fromToken!.symbol == 'BNB' || _fromToken!.symbol == 'ETH')) {
        _fromToken = SwapTokenOption(symbol: _fromToken!.symbol, balanceWeiStr: nativeWei ?? '0', decimals: 18, contractAddress: null, formattedBalance: KnownTokens.formatBalanceDisplay(nativeWei ?? '0', 18, maxDecimals: 6), iconColor: _fromToken!.iconColor);
      }
      if (_toToken != null && (_toToken!.symbol == 'BNB' || _toToken!.symbol == 'ETH')) {
        _toToken = SwapTokenOption(symbol: _toToken!.symbol, balanceWeiStr: nativeWei ?? '0', decimals: 18, contractAddress: null, formattedBalance: KnownTokens.formatBalanceDisplay(nativeWei ?? '0', 18, maxDecimals: 6), iconColor: _toToken!.iconColor);
      }
      if (result.tokenBalances.isNotEmpty) {
        for (final t in result.tokenBalances) {
          final meta = KnownTokens.getMeta(chainKey, t.contractAddress);
          if (meta == null) continue;
          if (_fromToken?.symbol == meta.symbol) {
            _fromToken = SwapTokenOption(symbol: meta.symbol, balanceWeiStr: t.balanceWei.toString(), decimals: meta.decimals, contractAddress: meta.contractAddress, formattedBalance: KnownTokens.formatBalanceDisplay(t.balanceWei.toString(), meta.decimals, maxDecimals: 6), iconColor: _fromToken!.iconColor);
          }
          if (_toToken?.symbol == meta.symbol) {
            _toToken = SwapTokenOption(symbol: meta.symbol, balanceWeiStr: t.balanceWei.toString(), decimals: meta.decimals, contractAddress: meta.contractAddress, formattedBalance: KnownTokens.formatBalanceDisplay(t.balanceWei.toString(), meta.decimals, maxDecimals: 6), iconColor: _toToken!.iconColor);
          }
        }
      }
      setState(() {});
    } catch (_) {}
  }

  Widget _confirmRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _swapFromTo() {
    final f = _fromToken;
    final t = _toToken;
    final fromAmt = _fromAmountController.text;
    final toAmt = _toAmountController.text;
    setState(() {
      _fromToken = t;
      _toToken = f;
      _fromAmountController.text = toAmt;
      _toAmountController.text = fromAmt;
    });
  }

  void _copyContract(String? address) {
    if (address == null || address.isEmpty) return;
    Clipboard.setData(ClipboardData(text: address));
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已复制合约地址')));
  }

  Future<void> _showWalletSelector() async {
    try {
      final api = UserApi();
      final userInfo = await api.getUserInfo();
      final info = userInfo;
      final deviceNo = info['device_no'] ?? info['deviceNo'] ?? await UserCache.getDevice() ?? '';
      if (deviceNo.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('无法获取设备账号列表')));
        return;
      }
      final accountResp = await api.getAccountDevice({'deviceNo': deviceNo});
      final rawList = accountResp['data'] as List<dynamic>? ?? [];
      final list = rawList.map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        m['isCurrent'] = (m['wallet_address'] ?? '') == _selectedWalletAddress;
        return m;
      }).toList();
      if (list.isEmpty && mounted) {
        list.add({'wallet_address': _selectedWalletAddress, 'username': '当前', 'isCurrent': true});
      }
      if (!mounted) return;
      _accountList = list;
      showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Text('选择钱包', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    const Spacer(),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
              ),
              ...list.asMap().entries.expand((entry) {
                final index = entry.key;
                final a = entry.value;
                final addr = a['wallet_address'] ?? '';
                final short = addr.length > 10 ? '${addr.substring(0, 6)}...${addr.substring(addr.length - 4)}' : addr;
                final selected = addr == _selectedWalletAddress;
                final nickname = a['username']?.toString() ?? '未命名';
                final avatarUrl = a['avatar_url']?.toString();
                return [
                  if (index > 0) const Divider(height: 1),
                  ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundColor: _green.withValues(alpha: 0.2),
                      backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                      child: avatarUrl == null || avatarUrl.isEmpty ? Text(nickname.isNotEmpty ? nickname.substring(0, 1) : '?', style: const TextStyle(color: _green, fontWeight: FontWeight.w600)) : null,
                    ),
                    title: Text(nickname, style: const TextStyle(fontWeight: FontWeight.w500)),
                    subtitle: Text(short, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontFamily: 'monospace')),
                    trailing: selected ? const Icon(Icons.check, color: _green) : null,
                    onTap: () {
                      setState(() {
                        _selectedWalletAddress = addr;
                        _nativeBalance = '0';
                        _balanceLoading = false;
                      });
                      _loadNativeBalance();
                      Navigator.pop(ctx);
                    },
                  ),
                ];
              }),
            ],
          ),
        ),
      );
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('加载账号列表失败: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, color: Colors.black87, size: 20), onPressed: () => Navigator.pop(context)),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _appBarTab('快速购买', 0),
              const SizedBox(width: 12),
              _appBarTab('闪兑', 1),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _appBarActionIcon(Icons.account_balance_wallet_outlined, Colors.purple.shade300, _showWalletSelector),
                _appBarActionIcon(Icons.show_chart, Colors.blue.shade700, () {
                  final token = _quickBuyToken ?? _toToken;
                  final symbol = token?.symbol ?? 'USDT';
                  final contract = token?.contractAddress ?? '';
                  Navigator.push(context, MaterialPageRoute(builder: (_) => TokenKlinePage(symbol: symbol, contractAddress: contract, chain: widget.chain)));
                }),
                _appBarActionIcon(Icons.history, Colors.grey.shade700, () => Navigator.push(context, MaterialPageRoute(builder: (_) => SwapHistoryPage(walletAddress: _selectedWalletAddress.isNotEmpty ? _selectedWalletAddress : widget.walletAddress, chain: widget.chain)))),
                _appBarActionIcon(Icons.share_outlined, Colors.grey.shade700, () async { try { await Share.share('我在使用闪兑'); } catch (_) {} }),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: _tabIndex == 0 ? _buildQuickBuy() : _buildFlashSwap(),
      ),
    );
  }

  Widget _appBarTab(String label, int index) {
    final selected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: TextStyle(fontSize: 16, fontWeight: selected ? FontWeight.w600 : FontWeight.normal, color: selected ? Colors.black87 : Colors.grey.shade600)),
          const SizedBox(height: 8),
          Container(height: 3, width: 48, decoration: BoxDecoration(color: selected ? _green : Colors.transparent, borderRadius: BorderRadius.circular(2))),
        ],
      ),
    );
  }

  /// 紧凑的 AppBar 图标按钮，仅保留 4px 内边距，按钮之间几乎无间隙
  Widget _appBarActionIcon(IconData icon, Color color, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    );
  }

  void _onFromAmountChanged() {
    final fromStr = _fromAmountController.text.trim();
    final fromVal = fromStr.isEmpty ? null : double.tryParse(fromStr);
    final toEst = _estimatedToAmount;
    if (toEst != null) {
      if (fromVal != null && (toEst - fromVal).abs() < 1e-9) {
        _toAmountController.text = '';
      } else {
        _toAmountController.text = toEst.toStringAsFixed(6);
      }
    } else {
      _toAmountController.text = '';
    }
    setState(() {});
    _quoteDebounce?.cancel();
    _quoteDebounce = Timer(const Duration(milliseconds: 400), _fetchSwapQuote);
  }

  /// 根据当前「从」金额请求聚合器报价，更新「至」金额（避免依赖价格加载、点一次全部即有数）
  Future<void> _fetchSwapQuote() async {
    final from = _fromToken;
    final to = _toToken;
    final fromStr = _fromAmountController.text.trim();
    if (from == null || to == null || fromStr.isEmpty || from.symbol == to.symbol) {
      if (fromStr.isEmpty && mounted) setState(() { _toAmountController.text = ''; });
      return;
    }
    final fromVal = double.tryParse(fromStr);
    if (fromVal == null || fromVal <= 0) return;
    final amountWei = BigInt.from((fromVal * _pow10(from.decimals)).round());
    if (amountWei == BigInt.zero) return;
    if (!mounted) return;
    setState(() => _quoteLoading = true);
    try {
      final quote = await swapAggregator.getQuote(
        chain: widget.chain,
        fromSymbol: from.symbol,
        fromContract: from.contractAddress,
        toSymbol: to.symbol,
        toContract: to.contractAddress,
        amountWei: amountWei.toString(),
      );
      if (!mounted) return;
      if (quote != null && quote.isNotEmpty) {
        final toDecimals = to.decimals;
        final formatted = KnownTokens.formatBalanceDisplay(quote, toDecimals, maxDecimals: 6);
        _toAmountController.text = formatted;
      } else {
        final toEst = _estimatedToAmount;
        final fromVal = double.tryParse(fromStr);
        if (toEst != null && (fromVal == null || (toEst - fromVal).abs() >= 1e-9)) {
          _toAmountController.text = toEst.toStringAsFixed(6);
        } else if (toEst == null) {
          _toAmountController.text = '';
        }
        final isBbtPair = from.symbol == 'BBT' || to.symbol == 'BBT';
        if (mounted && (!isBbtPair || toEst == null)) _showNoQuoteDialog(context);
      }
      setState(() {});
    } catch (_) {
      if (mounted) {
        final toEst = _estimatedToAmount;
        final fromVal = double.tryParse(_fromAmountController.text.trim());
        if (toEst != null && (fromVal == null || (toEst - fromVal).abs() >= 1e-9)) {
          _toAmountController.text = toEst.toStringAsFixed(6);
        } else if (toEst == null) {
          _toAmountController.text = '';
        }
        final isBbtPair = from.symbol == 'BBT' || to.symbol == 'BBT';
        if (!isBbtPair || toEst == null) _showNoQuoteDialog(context);
        setState(() {});
      }
    } finally {
      if (mounted) setState(() => _quoteLoading = false);
    }
  }

  Widget _buildQuickBuy() {
    final token = _quickBuyToken ?? _toToken;
    final symbol = token?.symbol ?? 'USDT';
    final contract = token?.contractAddress;
    final isNative = symbol == 'BNB' || symbol == 'ETH';
    final paySymbol = widget.chain == AlchemyService.bnbMainnet ? 'BNB' : 'ETH';
    final balanceStr = _balanceLoading ? '...' : KnownTokens.formatBalanceDisplay(_nativeBalance, 18, maxDecimals: 6);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade300)),
          child: Row(
            children: [
              Expanded(child: _segmentChip('买入', _isBuy, () => setState(() => _isBuy = true), left: true)),
              Expanded(child: _segmentChip('卖出', !_isBuy, () => setState(() => _isBuy = false), left: false)),
            ],
          ),
        ),
        const SizedBox(height: 20),
        GestureDetector(
          onTap: () async {
            final r = await showModalBottomSheet<SwapTokenSelectionResult>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => SwapTokenSheet(walletAddress: _selectedWalletAddress.isNotEmpty ? _selectedWalletAddress : widget.walletAddress, chain: widget.chain, title: '请选择要购买的代币', tokenPrices: _tokenPricesMap, onSelect: (_) {}),
            );
            if (r != null && mounted) {
              if (r.chain == widget.chain) setState(() => _quickBuyToken = r.token);
              else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择当前链上的代币')));
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
            child: Row(
              children: [
                TokenAvatar(symbol: symbol, iconUrl: KnownTokens.getLogoUrl(widget.chain, token?.contractAddress), iconColor: token?.iconColor ?? _green, size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [Text(symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600, size: 20)]),
                      const SizedBox(height: 4),
                      Text('价格: ${_priceDisplay(symbol)}  市值: ${_marketCapDisplay(symbol)}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              contract != null ? '${contract.substring(0, 10)}...${contract.substring(contract.length - 8)}' : (isNative ? '原生代币' : '--'),
                              style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontFamily: contract != null ? 'monospace' : null),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () {
                              if (contract != null) {
                                _copyContract(contract);
                              } else if (isNative && mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('原生代币无合约地址')));
                              } else {
                                _copyContract(null);
                              }
                            },
                            icon: Icon(Icons.copy, size: 16, color: Colors.grey.shade700),
                            label: Text('复制', style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                            style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap, backgroundColor: Colors.grey.shade200),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('余额: $balanceStr $paySymbol', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            GestureDetector(
              onTap: () {
                final v = KnownTokens.formatBalanceDisplay(_nativeBalance, 18, maxDecimals: 6);
                _amountController.text = v;
                setState(() {});
              },
              child: const Text('MAX', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _green)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  decoration: const InputDecoration(hintText: '0.00', border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero),
                  style: const TextStyle(fontSize: 18),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              Text(paySymbol, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.grey.shade800)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _isBuy
            ? Row(
                children: [
                  _quickAmount('0.05'),
                  const SizedBox(width: 10),
                  _quickAmount('0.1'),
                  const SizedBox(width: 10),
                  _quickAmount('0.5'),
                  const SizedBox(width: 10),
                  _quickAmount('1'),
                  const SizedBox(width: 10),
                  _quickAmount('2'),
                ],
              )
            : Row(
                children: [
                  _quickPercent(20),
                  const SizedBox(width: 10),
                  _quickPercent(40),
                  const SizedBox(width: 10),
                  _quickPercent(60),
                  const SizedBox(width: 10),
                  _quickPercent(80),
                  const SizedBox(width: 10),
                  _quickPercent(100),
                ],
              ),
        const SizedBox(height: 32),
        _buildQuickBuyButton(symbol, paySymbol),
      ],
    );
  }

  Widget _buildQuickBuyButton(String symbol, String paySymbol) {
    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr) ?? 0;
    final balance = double.tryParse(KnownTokens.formatBalanceDisplay(_nativeBalance, 18, maxDecimals: 8)) ?? 0;
    final insufficient = amount > 0 && amount > balance;
    final token = _quickBuyToken ?? _toToken;
    final isLoading = _swapLoading;
    if (_isBuy) {
      return SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: insufficient || isLoading
              ? (insufficient ? () => setState(() => _tabIndex = 1) : null)
              : () => _showQuickBuyConfirmAndExecute(symbol, paySymbol, token, amount, true),
          style: FilledButton.styleFrom(backgroundColor: _darkBg, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          child: Text(isLoading ? '处理中...' : (insufficient ? '余额不足 去兑换' : '快速买入 $symbol'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      );
    }
    final tokenBalance = double.tryParse(token?.formattedBalance ?? '0') ?? 0;
    final sellInsufficient = amount > 0 && amount > tokenBalance;
    return SizedBox(
      height: 52,
      child: FilledButton(
        onPressed: sellInsufficient || isLoading
            ? (sellInsufficient ? () => setState(() => _tabIndex = 1) : null)
            : () => _showQuickBuyConfirmAndExecute(symbol, paySymbol, token, amount, false),
        style: FilledButton.styleFrom(backgroundColor: Colors.grey.shade600, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        child: Text(isLoading ? '处理中...' : (sellInsufficient ? '余额不足 去兑换' : '快速卖出 $symbol'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  Future<void> _showQuickBuyConfirmAndExecute(String symbol, String paySymbol, SwapTokenOption? token, double amount, bool isBuy) async {
    if (token == null || amount <= 0) return;
    setState(() => _swapLoading = true);
    final fromSym = isBuy ? paySymbol : symbol;
    final toSym = isBuy ? symbol : paySymbol;
    final fromContract = isBuy ? null : token.contractAddress;
    final toContract = isBuy ? token.contractAddress : null;
    BigInt amountWei;
    if (isBuy) {
      amountWei = BigInt.from((amount * _pow10(18)).round());
    } else {
      amountWei = BigInt.from((amount * _pow10(token.decimals)).round());
    }
    String? expectedTo;
    try {
      final quote = await swapAggregator.getQuote(
        chain: widget.chain,
        fromSymbol: fromSym,
        fromContract: fromContract,
        toSymbol: toSym,
        toContract: toContract,
        amountWei: amountWei.toString(),
      );
      if (quote != null && quote.isNotEmpty) {
        final toDecimals = isBuy ? token.decimals : 18;
        try {
          expectedTo = KnownTokens.formatBalanceDisplay(quote, toDecimals, maxDecimals: 6);
        } catch (_) {
          expectedTo = quote; // 若格式化异常则直接显示原始字符串
        }
      }
    } catch (e) {
      debugPrint('[QuickBuy] getQuote error: $e');
    }
    if (!mounted) return;
    final expectedStr = expectedTo ?? '--';
    final expectedLabel = expectedTo != null ? '$expectedStr $toSym' : '--（报价失败，请检查网络；若已配置服务端代理请检查服务端 1inch 配置）';
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(isBuy ? '确认快速买入' : '确认快速卖出', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            _confirmRow('支付', '$amount $fromSym'),
            _confirmRow('预计获得', expectedLabel),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('取消'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(backgroundColor: isBuy ? _darkBg : Colors.grey.shade600, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      child: const Text('确认'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      if (mounted) setState(() => _swapLoading = false);
      return;
    }
    final fromAddress = widget.walletAddress;
    if (fromAddress.isEmpty || !fromAddress.startsWith('0x')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('当前钱包地址无效')));
      return;
    }
    final didId = await UserCache.getDid();
    if (didId == null || didId.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请先登录')));
      return;
    }
    final privateKey = await VerifyPasswordDialog.showForPrivateKey(context, didId: didId);
    if (privateKey == null || !mounted) return;
    setState(() => _swapLoading = true);
    try {
      final swapTx = await swapAggregator.getSwap(
        chain: widget.chain,
        fromSymbol: fromSym,
        fromContract: fromContract,
        toSymbol: toSym,
        toContract: toContract,
        amountWei: amountWei.toString(),
        fromAddress: fromAddress,
        slippagePercent: _slippagePercent,
      );
      if (swapTx == null) {
        if (mounted) _showNoQuoteFeedback(context, fromSym, toSym, _noQuoteMessage(fromSym, toSym, widget.chain));
        return;
      }
      if (!mounted) return;
      final txHash = await EvmTransferService.sendSwapTransaction(
        fromAddress: fromAddress,
        toAddress: swapTx.to,
        dataHex: swapTx.data,
        valueWei: swapTx.valueWei,
        gasLimit: swapTx.gas,
        gasPriceWei: swapTx.gasPriceWei,
        privateKeyHex: privateKey,
        networkId: widget.chain,
      );
      if (!mounted) return;
      _showSwapSuccessSnackBar(context, txHash);
      _amountController.clear();
      _loadNativeBalance();
      if (token.symbol == 'BNB' || token.symbol == 'ETH') {
        setState(() {
          _quickBuyToken = SwapTokenOption(symbol: token.symbol, balanceWeiStr: _nativeBalance, decimals: 18, contractAddress: null, formattedBalance: KnownTokens.formatBalanceDisplay(_nativeBalance, 18, maxDecimals: 6), iconColor: token.iconColor);
        });
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final serverReason = _extractServerError(msg);
        if (_isNoQuoteError(msg)) {
          _showNoQuoteFeedback(context, fromSym, toSym, _noQuoteMessage(fromSym, toSym, widget.chain), serverDetail: serverReason);
        } else if (_isGasInsufficientError(msg)) {
          final curStr = KnownTokens.formatBalanceDisplay(_nativeBalance, 18, maxDecimals: 6);
          final needStr = KnownTokens.formatBalanceDisplay(_gasReserveWei.toString(), 18, maxDecimals: 6);
          final gasHint = widget.chain == KnownTokens.bnbMainnet
              ? 'BNB 余额不足，无法支付 gas 费。当前约 $curStr BNB，建议至少 $needStr BNB。请先转入 BNB 后再试。'
              : '原生币余额不足，无法支付 gas 费。当前约 $curStr，建议至少 $needStr。请先转入后再试。';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(gasHint), duration: const Duration(seconds: 6)),
          );
        } else if (_isTxSendError(msg)) {
          final hint = (fromSym == 'BBT' || toSym == 'BBT')
              ? '交易提交失败，请检查 BNB 余额（gas 费）或稍后重试'
              : '交易提交失败，请检查余额与网络';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(serverReason != null ? '$hint\n$serverReason' : hint), duration: const Duration(seconds: 5)),
          );
        } else {
          final isBbtPair = fromSym == 'BBT' || toSym == 'BBT';
          if (isBbtPair) {
            _showNoQuoteFeedback(context, fromSym, toSym, _noQuoteMessage(fromSym, toSym, widget.chain), serverDetail: serverReason);
          } else {
            final friendly = _swapFriendlyError(msg);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('失败: $friendly')));
          }
        }
      }
    } finally {
      if (mounted) setState(() => _swapLoading = false);
    }
  }

  Widget _segmentChip(String label, bool selected, VoidCallback onTap, {required bool left}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.horizontal(left: const Radius.circular(8), right: left ? Radius.zero : const Radius.circular(8)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? _darkBg : Colors.transparent,
            borderRadius: BorderRadius.horizontal(left: const Radius.circular(8), right: left ? Radius.zero : const Radius.circular(8)),
          ),
          alignment: Alignment.center,
          child: Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: selected ? Colors.white : Colors.grey.shade800)),
        ),
      ),
    );
  }

  Widget _quickAmount(String value) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () { _amountController.text = value; setState(() {}); },
        style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text(value, style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _quickPercent(int percent) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () {
          final balance = double.tryParse(KnownTokens.formatBalanceDisplay(_nativeBalance, 18, maxDecimals: 8)) ?? 0;
          final v = balance * percent / 100;
          _amountController.text = v.toStringAsFixed(6).replaceAll(RegExp(r'\.?0+$'), '');
          setState(() {});
        },
        style: OutlinedButton.styleFrom(foregroundColor: Colors.black87, side: BorderSide(color: Colors.grey.shade300), padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        child: Text('$percent%', style: const TextStyle(fontSize: 14)),
      ),
    );
  }

  Widget _buildFlashSwap() {
    final from = _fromToken;
    final to = _toToken;
    final fromBalance = from?.formattedBalance ?? '0';
    final toBalance = to?.formattedBalance ?? '0';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _swapCard(
          title: '从 $_networkName',
          balanceText: '余额: $fromBalance',
          rightAction: '全部',
          token: from,
          controller: _fromAmountController,
          onTokenTap: () async {
            final r = await showModalBottomSheet<SwapTokenSelectionResult>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => SwapTokenSheet(walletAddress: _selectedWalletAddress.isNotEmpty ? _selectedWalletAddress : widget.walletAddress, chain: widget.chain, title: '选择支付代币', excludeSymbol: to?.symbol, tokenPrices: _tokenPricesMap, onSelect: (_) {}),
            );
            if (r != null && mounted) {
              if (r.chain == widget.chain) setState(() { _fromToken = r.token; _fromAmountController.clear(); _toAmountController.clear(); _onFromAmountChanged(); });
              else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择当前链上的代币')));
            }
          },
          onMaxTap: () {
            if (from == null) return;
            final balanceWei = BigInt.tryParse(from.balanceWeiStr) ?? BigInt.zero;
            if (from.symbol == 'BNB' || from.symbol == 'ETH') {
              final afterReserve = balanceWei > _gasReserveWei ? balanceWei - _gasReserveWei : BigInt.zero;
              _fromAmountController.text = KnownTokens.formatBalanceDisplay(afterReserve.toString(), from.decimals, maxDecimals: 8);
              if (balanceWei > BigInt.zero && balanceWei <= _gasReserveWei && mounted) {
                final reserveStr = KnownTokens.formatBalanceDisplay(_gasReserveWei.toString(), from.decimals, maxDecimals: 6);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('余额较少，需至少预留 $reserveStr ${from.symbol} 用于 gas 费')));
              }
            } else {
              _fromAmountController.text = from.formattedBalance;
            }
            _onFromAmountChanged();
            setState(() {});
            _quoteDebounce?.cancel();
            _fetchSwapQuote();
          },
        ),
        const SizedBox(height: 8),
        Center(
          child: GestureDetector(
            onTap: _swapFromTo,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle, border: Border.all(color: Colors.grey.shade300)),
              child: Icon(Icons.swap_vert, color: Colors.grey.shade700, size: 24),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _swapCard(
          title: '至 $_networkName',
          balanceText: '余额: $toBalance',
          token: to,
          controller: _toAmountController,
          readOnly: true,
          onTokenTap: () async {
            final r = await showModalBottomSheet<SwapTokenSelectionResult>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => SwapTokenSheet(walletAddress: _selectedWalletAddress.isNotEmpty ? _selectedWalletAddress : widget.walletAddress, chain: widget.chain, title: '选择获得代币', excludeSymbol: from?.symbol, tokenPrices: _tokenPricesMap, onSelect: (_) {}),
            );
            if (r != null && mounted) {
              if (r.chain == widget.chain) setState(() { _toToken = r.token; _fromAmountController.clear(); _toAmountController.clear(); _onFromAmountChanged(); });
              else ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请选择当前链上的代币')));
            }
          },
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: (_canSwap && !_swapLoading) ? _showSwapConfirmSheet : null,
            style: FilledButton.styleFrom(
              backgroundColor: (_canSwap && !_swapLoading) ? _green : Colors.grey.shade400,
              disabledBackgroundColor: Colors.grey.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(_swapLoading ? '处理中...' : '闪兑', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 24),
        _detailRow('参考汇率', hasInfo: true, value: _quoteLoading ? '请求中...' : _referenceRateText),
        const SizedBox(height: 12),
        _detailRow('滑点', hasInfo: true, value: '${_slippagePercent.toStringAsFixed(1)}%', trailing: InkWell(onTap: _showSlippageSheet, child: Icon(Icons.settings, size: 18, color: Colors.grey.shade600))),
        const SizedBox(height: 12),
        _detailRow('最优通道', hasInfo: true, value: '聚合路由'),
        const SizedBox(height: 28),
        Row(
          children: [
            Container(width: 4, height: 18, decoration: BoxDecoration(color: _green, borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('最近一条交易', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('暂无交易记录'))),
              child: Text('查看更多 >', style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 32),
          decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
          child: Center(child: Text('暂无记录', style: TextStyle(fontSize: 14, color: Colors.grey.shade500))),
        ),
      ],
    );
  }

  Widget _swapCard({
    required String title,
    required String balanceText,
    required TextEditingController controller,
    required VoidCallback onTokenTap,
    SwapTokenOption? token,
    String? rightAction,
    VoidCallback? onMaxTap,
    bool readOnly = false,
  }) {
    final symbol = token?.symbol ?? '--';
    final iconColor = token?.iconColor ?? Colors.grey;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
              Row(
                children: [
                  Text(balanceText, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  if (rightAction != null && onMaxTap != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(onTap: onMaxTap, child: Text(rightAction, style: const TextStyle(fontSize: 12, color: _green, fontWeight: FontWeight.w500))),
                  ],
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              GestureDetector(
                onTap: onTokenTap,
                child: Row(
                  children: [
                    TokenAvatar(symbol: symbol, iconUrl: KnownTokens.getLogoUrl(widget.chain, token?.contractAddress), iconColor: iconColor, size: 40),
                    const SizedBox(width: 12),
                    Text(symbol, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Icon(Icons.keyboard_arrow_down, color: Colors.grey.shade600, size: 22),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: 120,
                child: readOnly
                    ? Text(
                        controller.text.isEmpty ? '0.00' : controller.text,
                        textAlign: TextAlign.right,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                      )
                    : TextField(
                        controller: controller,
                        textAlign: TextAlign.right,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                        decoration: const InputDecoration(border: InputBorder.none, isDense: true, contentPadding: EdgeInsets.zero, hintText: '0.00'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        onChanged: (_) {
                          _onFromAmountChanged();
                          setState(() {});
                        },
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailRow(String label, {required bool hasInfo, required String value, Widget? trailing}) {
    return Row(
      children: [
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
        if (hasInfo) ...[const SizedBox(width: 4), Icon(Icons.info_outline, size: 16, color: Colors.grey.shade500)],
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 14, color: Colors.grey.shade600)),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ],
    );
  }
}
