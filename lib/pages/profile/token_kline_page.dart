import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/modules/dynamic/models/post_info.dart';
import 'package:education/config/app_config.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/pages/market/dynamic_detail_page.dart';
import 'package:education/pages/market/publish_dynamic_page.dart';
import 'package:education/services/dynamic_service.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/chat/avatar.dart';
import 'package:education/widgets/follower/community_post_card.dart';
import 'package:education/widgets/follower/post_more_menu_sheet.dart';
import 'package:education/widgets/common/empty_state_view.dart';
import 'package:education/widgets/common/share_sheet.dart';
import 'package:education/widgets/common/token_avatar.dart';
import 'package:education/providers/user_provider.dart';
import 'package:education/services/coingecko_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// 代币 K 线页：布局与参考图一致（代币信息、周期、K 线/折线、开高低收、话题/概况、闪兑按钮）
///
/// 数据来源：本页所有接口统一走 App → 网关 → 第三方（不直连第三方）。
/// - 价格/市值/24h/涨跌幅：GET /v1/wallet/proxy/coingecko/contract → CoinGecko
/// - 流动性：GET /v1/wallet/proxy/dexscreener/token → DexScreener
/// - 持有人：GET /v1/wallet/proxy/token/holders → BSCScan 等
/// - K 线：GET /v1/wallet/proxy/coingecko/ohlc → 网关内部先取 contract 拿 id，再拉 market_chart 转 OHLC（CoinGecko）
/// - 概况（描述/名称/链接）：GET /v1/wallet/proxy/coingecko/contract → CoinGecko（与价格同源）
class TokenKlinePage extends ConsumerStatefulWidget {
  final String symbol;
  final String contractAddress;
  final String chain;

  const TokenKlinePage({
    super.key,
    required this.symbol,
    required this.contractAddress,
    this.chain = 'bnb-mainnet',
  });

  @override
  ConsumerState<TokenKlinePage> createState() => _TokenKlinePageState();
}

class _TokenKlinePageState extends ConsumerState<TokenKlinePage> {
  static const Color _green = Color(0xFF00D1A7);
  static const Color _red = Color(0xFFFF3B30);

  int _intervalIndex = 2; // 15分
  bool _isCandle = true;
  int _contentTabIndex = 0; // 话题 / 概况
  double? _price; // 来自 CoinGecko，null 表示加载中或未收录
  double? _changePercent;
  String _open = '—', _high = '—', _low = '—', _close = '—';
  double? _marketCap;
  double? _volume24h;
  double? _liquidity; // 来自 DexScreener 代理
  String? _holders; // 来自后端 proxy，如 "23.3K+"
  bool _tokenStatsLoading = true;
  bool _isInWatchlist = false; // 右上角第二个图标：自选

  /// 话题：与当前代币相关的动态
  final DynamicApi _dynamicApi = DynamicApi();
  List<PostInfo> _topicPosts = [];
  int _topicCursor = 0;
  bool _topicHasMore = true;
  bool _topicLoading = true;
  bool _topicLoadingMore = false;
  String? _topicError;
  final ScrollController _topicScrollController = ScrollController();
  Timer? _bottomTimeTimer;

  /// 概况：第三方代币描述
  bool _overviewLoading = false;
  String? _overviewError;
  String _overviewDescription = '';
  String _overviewName = '';
  Map<String, dynamic> _overviewLinks = {};

  static const List<String> _intervals = [
    '1分',
    '5分',
    '15分',
    '30分',
    '1小时',
    '2小时',
  ];

  /// 真实 K 线（从网关代理 CoinGecko 拉取）；null 或空时用 mock 兜底
  List<Map<String, double>>? _candles;
  bool _ohlcLoading = false;

  String get _gatewayProxyBase =>
      AppConfig.reqUrl.replaceFirst(RegExp(r'/$'), '') + '/v1/wallet/proxy';

  /// 当前代币唯一标识，用于 didUpdateWidget 判断是否换币、以及异步回调时丢弃过期数据
  String get _tokenKey =>
      '${widget.symbol}|${widget.contractAddress}|${widget.chain}';

  /// 清空当前代币相关数据（换币或重新进入时调用，避免显示上一代币数据）
  void _resetTokenData() {
    _price = null;
    _changePercent = null;
    _open = '—';
    _high = '—';
    _low = '—';
    _close = '—';
    _marketCap = null;
    _volume24h = null;
    _liquidity = null;
    _holders = null;
    _tokenStatsLoading = true;
    _candles = null;
    _ohlcLoading = false;
    _overviewLoading = true;
    _overviewError = null;
    _overviewDescription = '';
    _overviewName = '';
    _overviewLinks = {};
    _topicPosts = [];
    _topicCursor = 0;
    _topicHasMore = true;
    _topicLoading = true;
    _topicLoadingMore = false;
    _topicError = null;
  }

  /// Mock K 线兜底（无网络或接口失败时）
  List<Map<String, double>> _getMockCandles() {
    final base = _price ?? 1.0;
    final n = 12 + _intervalIndex * 4; // 1分约16根，2小时约36根，周期越长根数略多
    final list = <Map<String, double>>[];
    var o = base;
    for (int i = 0; i < n; i++) {
      final seed = (i + _intervalIndex * 7) % 5;
      final change = (seed - 2) * 0.0002 * (1 + _intervalIndex * 0.3);
      final h = o + 0.0003.abs();
      final l = o - 0.0003.abs();
      final c = o + change;
      list.add({'o': o, 'h': h, 'l': l, 'c': c});
      o = c;
    }
    return list;
  }

  void _updateOhlcFromCandles(List<Map<String, double>> candles) {
    if (candles.isEmpty) return;
    final last = candles.last;
    final first = candles.first;
    _open = first['o']!.toStringAsFixed(4);
    _close = last['c']!.toStringAsFixed(4);
    double h = first['h']!, l = first['l']!;
    for (final c in candles) {
      if (c['h']! > h) h = c['h']!;
      if (c['l']! < l) l = c['l']!;
    }
    _high = h.toStringAsFixed(4);
    _low = l.toStringAsFixed(4);
    // 价格与涨跌幅仅来自 CoinGecko，不用 mock K 线覆盖，避免出现 0.068 等错误展示（如 USDT 应为 ~1.0）
  }

  /// 价格/市值/24h/涨跌幅 + 概况（描述/名称/链接）：只请求一次 GET /wallet/proxy/coingecko/contract，避免重复调用触发 429
  Future<void> _loadTokenStats() async {
    final key = _tokenKey;
    if (widget.contractAddress.isEmpty) {
      if (mounted) {
        setState(() {
          _tokenStatsLoading = false;
          _overviewLoading = false;
          _overviewDescription = '该代币为原生币或暂无合约信息，无法获取概况。';
        });
      }
      return;
    }
    final platform = _coingeckoPlatform(widget.chain);
    if (platform == null) {
      if (mounted) {
        setState(() {
          _tokenStatsLoading = false;
          _overviewLoading = false;
          _overviewDescription = '当前链暂不支持从第三方获取代币概况。';
        });
      }
      _loadLiquidity();
      _loadHolders();
      return;
    }
    setState(() {
      _tokenStatsLoading = true;
      _overviewLoading = true;
      _overviewError = null;
      _overviewDescription = '';
    });
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12)));
      final addr = widget.contractAddress.toLowerCase().startsWith('0x')
          ? widget.contractAddress.toLowerCase()
          : '0x${widget.contractAddress.toLowerCase()}';
      final resp = await dio.get<Map<String, dynamic>>(
        '$_gatewayProxyBase/coingecko/contract',
        queryParameters: {'platform': platform, 'address': addr},
        options: Options(validateStatus: (_) => true),
      );
      if (!mounted || _tokenKey != key) return;
      final data = resp.data;
      final isRateLimited = resp.statusCode == 429;
      CoinGeckoContractData? stats;
      if (data != null && data is Map<String, dynamic>) {
        stats = CoinGeckoContractData.fromJson(data);
      }
      // 同一份 contract 响应同时填充价格与概况，只请求一次避免 429
      String overviewDesc = '';
      String overviewName = widget.symbol;
      Map<String, dynamic> overviewLinks = {};
      if (data != null && data is Map<String, dynamic> && !isRateLimited) {
        final desc = data['description'];
        if (desc is Map<String, dynamic>) {
          overviewDesc = (desc['en'] as String? ?? desc['zh'] as String? ?? '')
              .toString()
              .trim();
        } else if (desc is String) {
          overviewDesc = desc.trim();
        }
        overviewName = data['name'] as String? ?? widget.symbol;
        overviewLinks = data['links'] as Map<String, dynamic>? ?? {};
      }
      if (isRateLimited) {
        overviewDesc = '请求过于频繁，请稍后再试。';
      } else if (overviewDesc.isEmpty && !isRateLimited) {
        overviewDesc = '该代币在 CoinGecko 暂无描述。';
      }
      if (mounted && _tokenKey == key) {
        setState(() {
          _tokenStatsLoading = false;
          _overviewLoading = false;
          if (stats != null) {
            _price = stats.price;
            _changePercent = stats.changePercent24h;
            _marketCap = stats.marketCap;
            _volume24h = stats.volume24h;
          }
          _overviewDescription = overviewDesc;
          _overviewName = overviewName;
          _overviewLinks = overviewLinks;
        });
      }
    } catch (_) {
      if (mounted && _tokenKey == key) {
        setState(() {
          _tokenStatsLoading = false;
          _overviewLoading = false;
          _overviewDescription = '获取代币概况失败，请稍后重试。';
        });
      }
    }
    if (_tokenKey != key) return;
    _loadLiquidity();
    _loadHolders();
    _loadOhlc();
  }

  /// K 线：经网关 GET /wallet/proxy/coingecko/ohlc → CoinGecko market_chart 转 OHLC
  Future<void> _loadOhlc() async {
    final key = _tokenKey;
    if (widget.contractAddress.isEmpty) return;
    final platform = _coingeckoPlatform(widget.chain);
    if (platform == null) return;
    final days = _intervalIndex <= 1 ? '1' : (_intervalIndex <= 3 ? '7' : '14');
    final interval = _intervalIndex <= 3 ? '15m' : '1h';
    setState(() => _ohlcLoading = true);
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 12)));
      final addr = widget.contractAddress.toLowerCase().startsWith('0x')
          ? widget.contractAddress.toLowerCase()
          : '0x${widget.contractAddress.toLowerCase()}';
      final resp = await dio.get<Map<String, dynamic>>(
        '$_gatewayProxyBase/coingecko/ohlc',
        queryParameters: {
          'platform': platform,
          'address': addr,
          'days': days,
          'interval': interval,
        },
        options: Options(validateStatus: (_) => true),
      );
      if (!mounted || _tokenKey != key) return;
      final raw = resp.data?['ohlc'];
      List<Map<String, double>>? list;
      if (raw is List && raw.isNotEmpty) {
        list = [];
        for (final e in raw) {
          if (e is! List || e.length < 5) continue;
          final o = (e[1] is num)
              ? (e[1] as num).toDouble()
              : double.tryParse(e[1].toString());
          final h = (e[2] is num)
              ? (e[2] as num).toDouble()
              : double.tryParse(e[2].toString());
          final l = (e[3] is num)
              ? (e[3] as num).toDouble()
              : double.tryParse(e[3].toString());
          final c = (e[4] is num)
              ? (e[4] as num).toDouble()
              : double.tryParse(e[4].toString());
          if (o == null || h == null || l == null || c == null) continue;
          list.add({'o': o, 'h': h, 'l': l, 'c': c});
        }
      }
      if (mounted && _tokenKey == key) {
        setState(() {
          _ohlcLoading = false;
          _candles = list?.isNotEmpty == true ? list : null;
          if (list != null && list.isNotEmpty) _updateOhlcFromCandles(list);
        });
      }
    } catch (_) {
      if (mounted && _tokenKey == key)
        setState(() {
          _ohlcLoading = false;
          _candles = null;
        });
    }
  }

  /// 流动性：经网关 /wallet/proxy/dexscreener/token → DexScreener
  Future<void> _loadLiquidity() async {
    final key = _tokenKey;
    if (widget.contractAddress.isEmpty) return;
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
      final resp = await dio.get<Map<String, dynamic>>(
        '$_gatewayProxyBase/dexscreener/token',
        queryParameters: {
          'chain': widget.chain,
          'address': widget.contractAddress,
        },
        options: Options(validateStatus: (_) => true),
      );
      if (!mounted || _tokenKey != key || resp.data == null) return;
      final liq = resp.data!['liquidity'];
      if (liq != null) {
        final v = liq is num
            ? liq.toDouble()
            : (double.tryParse(liq.toString()));
        if (v != null && v > 0 && mounted && _tokenKey == key)
          setState(() => _liquidity = v);
      }
    } catch (_) {}
  }

  /// 持有人数：经网关 /wallet/proxy/token/holders → BSCScan 等
  Future<void> _loadHolders() async {
    final key = _tokenKey;
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 8)));
      final resp = await dio.get<Map<String, dynamic>>(
        '$_gatewayProxyBase/token/holders',
        queryParameters: {
          'chain': widget.chain,
          'address': widget.contractAddress,
        },
        options: Options(validateStatus: (_) => true),
      );
      if (!mounted || _tokenKey != key || resp.data == null) return;
      final count = resp.data!['holders'];
      if (count != null && mounted && _tokenKey == key)
        setState(() => _holders = _formatHolders(count));
    } catch (_) {}
  }

  static String _formatHolders(dynamic count) {
    if (count == null) return '—';
    double? n;
    if (count is num) n = count.toDouble();
    if (count is String) n = double.tryParse(count);
    if (n == null || n.isNaN) return count.toString();
    if (n >= 1000000) return '${(n / 1e6).toStringAsFixed(1)}M+';
    if (n >= 1000) return '${(n / 1e3).toStringAsFixed(1)}K+';
    return '${n.toInt()}+';
  }

  static String _formatMoney(double? v) {
    if (v == null || v <= 0) return '—';
    if (v >= 1e9) return '\$${(v / 1e9).toStringAsFixed(2)}B';
    if (v >= 1e6) return '\$${(v / 1e6).toStringAsFixed(2)}M';
    if (v >= 1e3) return '\$${(v / 1e3).toStringAsFixed(2)}K';
    return '\$${v.toStringAsFixed(2)}';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _updateOhlcFromCandles(_getMockCandles()));
    });
    _loadTokenStats(); // 一次请求同时拉取价格与概况，不再单独调用 _loadOverview
    _loadTopicFeed();
    _topicScrollController.addListener(_onTopicScroll);
    _bottomTimeTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant TokenKlinePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.contractAddress != widget.contractAddress ||
        oldWidget.chain != widget.chain) {
      _resetTokenData();
      _loadTokenStats();
      _loadTopicFeed();
    }
  }

  @override
  void dispose() {
    _bottomTimeTimer?.cancel();
    _topicScrollController.dispose();
    super.dispose();
  }

  void _onTopicScroll() {
    if (_contentTabIndex != 0 || !_topicHasMore || _topicLoadingMore) return;
    if (_topicScrollController.position.pixels >=
        _topicScrollController.position.maxScrollExtent - 200) {
      _loadMoreTopic();
    }
  }

  /// 拉取与当前代币相关的话题动态（服务端按代币过滤）
  Future<void> _loadTopicFeed() async {
    final key = _tokenKey;
    if (!mounted) return;
    setState(() {
      _topicLoading = true;
      _topicError = null;
      _topicPosts = [];
      _topicCursor = 0;
      _topicHasMore = true;
    });
    try {
      final resp = await _dynamicApi.getTokenTopicFeed(
        symbol: widget.symbol,
        contractAddress: widget.contractAddress,
        chain: widget.chain,
        topicKeyword: widget.symbol,
        cursor: 0,
        limit: 20,
      );
      if (!mounted || _tokenKey != key) return;
      final raw = resp['list'] as List<dynamic>? ?? [];
      final list = raw
          .map((e) => PostInfo.fromMap(e as Map<String, dynamic>))
          .toList();
      final next = (resp['next_cursor'] as num?)?.toInt() ?? 0;
      final hasMore = resp['has_more'] as bool? ?? false;
      if (mounted && _tokenKey == key) {
        setState(() {
          _topicPosts = list;
          _topicCursor = next;
          _topicHasMore = hasMore;
          _topicLoading = false;
        });
      }
    } catch (e) {
      if (mounted && _tokenKey == key) {
        setState(() {
          _topicLoading = false;
          _topicError = e.toString();
        });
      }
    }
  }

  Future<void> _loadMoreTopic() async {
    if (!_topicHasMore || _topicLoadingMore) return;
    setState(() => _topicLoadingMore = true);
    try {
      final resp = await _dynamicApi.getTokenTopicFeed(
        symbol: widget.symbol,
        contractAddress: widget.contractAddress,
        chain: widget.chain,
        topicKeyword: widget.symbol,
        cursor: _topicCursor,
        limit: 20,
      );
      final raw = resp['list'] as List<dynamic>? ?? [];
      final list = raw
          .map((e) => PostInfo.fromMap(e as Map<String, dynamic>))
          .toList();
      final next = (resp['next_cursor'] as num?)?.toInt() ?? 0;
      final hasMore = resp['has_more'] as bool? ?? false;
      if (mounted) {
        setState(() {
          _topicPosts.addAll(list);
          _topicCursor = next;
          _topicHasMore = hasMore;
          _topicLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _topicLoadingMore = false);
    }
  }

  /// 概况：经网关 GET /wallet/proxy/coingecko/contract 获取代币描述（与价格同源，走网关 → CoinGecko）
  Future<void> _loadOverview() async {
    final key = _tokenKey;
    if (widget.contractAddress.isEmpty) {
      setState(() {
        _overviewLoading = false;
        _overviewError = null;
        _overviewDescription = '该代币为原生币或暂无合约信息，无法获取概况。';
      });
      return;
    }
    final platform = _coingeckoPlatform(widget.chain);
    if (platform == null) {
      setState(() {
        _overviewLoading = false;
        _overviewError = null;
        _overviewDescription = '当前链暂不支持从第三方获取代币概况。';
      });
      return;
    }
    setState(() {
      _overviewLoading = true;
      _overviewError = null;
      _overviewDescription = '';
    });
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );
      final addr = widget.contractAddress.toLowerCase().startsWith('0x')
          ? widget.contractAddress.toLowerCase()
          : '0x${widget.contractAddress.toLowerCase()}';
      final resp = await dio.get<Map<String, dynamic>>(
        '$_gatewayProxyBase/coingecko/contract',
        queryParameters: {'platform': platform, 'address': addr},
        options: Options(validateStatus: (_) => true),
      );
      final data = resp.data;
      if (!mounted || _tokenKey != key) return;
      if (data == null) {
        setState(() {
          _overviewLoading = false;
          _overviewDescription = '暂无代币概况数据。';
        });
        return;
      }
      final desc = data['description'];
      String text = '';
      if (desc is Map<String, dynamic>) {
        text = (desc['en'] as String? ?? desc['zh'] as String? ?? '')
            .toString()
            .trim();
      } else if (desc is String) {
        text = desc.trim();
      }
      final name = data['name'] as String? ?? widget.symbol;
      final links = data['links'] as Map<String, dynamic>? ?? {};
      if (mounted && _tokenKey == key) {
        setState(() {
          _overviewLoading = false;
          _overviewDescription = text.isEmpty ? '该代币在 CoinGecko 暂无描述。' : text;
          _overviewName = name;
          _overviewLinks = links;
        });
      }
    } catch (e) {
      if (mounted && _tokenKey == key) {
        setState(() {
          _overviewLoading = false;
          _overviewError = e.toString();
          _overviewDescription = '获取代币概况失败，请稍后重试。';
        });
      }
    }
  }

  /// 链标识 -> CoinGecko asset_platform_id
  String? _coingeckoPlatform(String chain) {
    switch (chain) {
      case 'eth-mainnet':
        return 'ethereum';
      case 'bnb-mainnet':
        return 'binance-smart-chain';
      case 'base-mainnet':
        return 'base';
      default:
        return null;
    }
  }

  void _copyAddress() {
    if (widget.contractAddress.isEmpty) return;
    Clipboard.setData(ClipboardData(text: widget.contractAddress));
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已复制合约地址')));
  }

  /// DeBox 风格：分享代币（名称、合约、链）
  void _shareToken() {
    final chainName = _klineChainName(widget.chain);
    final text = '${widget.symbol} ($chainName)\n${widget.contractAddress}';
    Share.share(text, subject: '${widget.symbol} 代币');
  }

  /// 右上角单个图标：紧凑点击区，无默认留白
  Widget _appBarIcon(IconData icon, VoidCallback onTap, {Color? color}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          width: 36,
          height: 36,
          child: Icon(icon, size: 22, color: color ?? Colors.grey.shade700),
        ),
      ),
    );
  }

  /// K 线页右下角 + 号：打开发布动态页并自动选中当前代币
  void _openPublishWithToken() {
    final chainName = _klineChainName(widget.chain);
    final token = <String, dynamic>{
      'symbol': widget.symbol,
      'chain': widget.chain,
      'contract_address': widget.contractAddress,
      'chain_name': chainName,
    };
    final meta = KnownTokens.getMeta(widget.chain, widget.contractAddress);
    if (meta != null) token['decimals'] = meta.decimals;
    Navigator.of(context)
        .push<void>(
          MaterialPageRoute(
            builder: (_) => PublishDynamicPage(initialToken: token),
          ),
        )
        .then((_) {
          if (mounted) _loadTopicFeed();
        });
  }

  static String _klineChainName(String chain) {
    switch (chain) {
      case KnownTokens.bnbMainnet:
        return 'BNB Chain';
      case KnownTokens.ethMainnet:
        return 'Ethereum';
      case KnownTokens.baseMainnet:
        return 'Base';
      case KnownTokens.xLayer:
        return 'X Layer';
      default:
        return chain;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDown = (_changePercent ?? 0) < 0;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('', style: TextStyle(fontSize: 18)),
        centerTitle: true,
        actions: [
          // 用一个 Row 包住三个图标，自定义间距，避免 IconButton 默认留白
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _appBarIcon(
                  Icons.chat_bubble_outline,
                  () => setState(() => _contentTabIndex = 0),
                ),
                const SizedBox(width: 4),
                _appBarIcon(
                  _isInWatchlist ? Icons.star : Icons.star_border,
                  () {
                    setState(() => _isInWatchlist = !_isInWatchlist);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isInWatchlist ? '已添加自选' : '已取消自选'),
                        duration: const Duration(seconds: 1),
                      ),
                    );
                  },
                  color: _isInWatchlist ? const Color(0xFF00D1A7) : null,
                ),
                const SizedBox(width: 4),
                _appBarIcon(Icons.share_outlined, _shareToken),
              ],
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildTokenHeader(isDown),
            _buildMarketRow(),
            _buildIntervalBar(),
            _buildOhlcBar(isDown),
            _buildChartPlaceholder(),
            _buildChartBottomBar(),
            _buildContentTabs(),
            _buildTopicContent(),
            SizedBox(height: 88 + MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24),
        child: FloatingActionButton(
          onPressed: _openPublishWithToken,
          backgroundColor: _green,
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: _green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '闪兑',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTokenHeader(bool isDown) {
    final shortAddr = widget.contractAddress.length > 10
        ? '${widget.contractAddress.substring(0, 6)}...${widget.contractAddress.substring(widget.contractAddress.length - 6)}'
        : widget.contractAddress;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              TokenAvatar(
                symbol: widget.symbol,
                iconUrl: widget.contractAddress.isNotEmpty
                    ? KnownTokens.getLogoUrl(
                        widget.chain,
                        widget.contractAddress,
                      )
                    : null,
                iconColor: _green,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.symbol,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: _copyAddress,
                      child: Row(
                        children: [
                          Text(
                            shortAddr,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.copy,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              if (_tokenStatsLoading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                Text(
                  _price != null ? '\$${_price!.toStringAsFixed(4)}' : '—',
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(width: 12),
              if (!_tokenStatsLoading && _changePercent != null)
                Text(
                  '${_changePercent! >= 0 ? "+" : ""}${_changePercent!.toStringAsFixed(2)}%',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDown ? _red : _green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMarketRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _marketItem('市值', _formatMoney(_marketCap)),
          _marketItem('流动性', _formatMoney(_liquidity)),
          _marketItem('24小时交易量', _formatMoney(_volume24h)),
          _marketItem('持有人', _holders ?? '—'),
        ],
      ),
    );
  }

  Widget _marketItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildIntervalBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_intervals.length, (i) {
                  final selected = _intervalIndex == i;
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _intervalIndex = i);
                        _loadOhlc();
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _intervals[i],
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: selected
                                  ? FontWeight.w600
                                  : FontWeight.normal,
                              color: selected ? _green : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 2,
                            width: 28,
                            decoration: BoxDecoration(
                              color: selected ? _green : Colors.transparent,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          Row(
            children: [
              GestureDetector(
                onTap: () => setState(() => _isCandle = true),
                child: Icon(
                  Icons.candlestick_chart,
                  size: 24,
                  color: _isCandle ? _green : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => setState(() => _isCandle = false),
                child: Icon(
                  Icons.show_chart,
                  size: 24,
                  color: !_isCandle ? _green : Colors.grey.shade400,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOhlcBar(bool isDown) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '开 = $_open',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 8),
            Text(
              '高 = $_high',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 8),
            Text(
              '低 = $_low',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 8),
            Text(
              '收 = $_close',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 6),
            Text(
              '(${(_changePercent ?? 0).toStringAsFixed(2)}%)',
              style: TextStyle(fontSize: 12, color: isDown ? _red : _green),
            ),
          ],
        ),
      ),
    );
  }

  /// 底部时间轴刻度：按周期显示不同间隔
  List<String> _getTimeLabels() {
    const labels = [
      ['00:00', '00:05', '00:10', '00:15'], // 1分：约 5 分钟
      ['00:00', '00:10', '00:20', '00:30'], // 5分：约 10 分钟
      ['00:00', '01:00', '02:00', '03:00'], // 15分 / 30分 / 1小时：1 小时间隔
      ['00:00', '01:00', '02:00', '03:00'],
      ['00:00', '01:00', '02:00', '03:00'],
      ['00:00', '02:00', '04:00', '06:00'], // 2小时：2 小时间隔
    ];
    return labels[_intervalIndex.clamp(0, labels.length - 1)];
  }

  static const double _chartHeight = 220;
  static const double _minBarWidth = 6.0;

  Widget _buildChartPlaceholder() {
    final candles = _candles ?? _getMockCandles();
    final timeLabels = _getTimeLabels();
    final p = _price ?? 0.0;
    double priceMax = candles.isEmpty
        ? p + 0.001
        : candles.map((c) => c['h']!).reduce((a, b) => a > b ? a : b);
    double priceMin = candles.isEmpty
        ? p - 0.001
        : candles.map((c) => c['l']!).reduce((a, b) => a < b ? a : b);
    // 保证价格区间非零，否则 CustomPainter 不绘制柱体（默认 15 分等数据少时易出现）
    if (priceMax <= priceMin) {
      final eps = (p.abs() * 0.001).clamp(0.0001, 0.01);
      priceMin = priceMin - eps;
      priceMax = priceMax + eps;
    }
    final viewportWidth = MediaQuery.of(context).size.width - 40;
    final contentWidth = candles.isEmpty
        ? viewportWidth
        : (candles.length * _minBarWidth).clamp(viewportWidth, double.infinity);
    final canScroll = contentWidth > viewportWidth;

    final chartContent = SizedBox(
      width: contentWidth,
      height: _chartHeight,
      child: Stack(
        children: [
          if (_ohlcLoading)
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          CustomPaint(
            size: Size(contentWidth, _chartHeight),
            painter: _SimpleKlinePainter(
              isCandle: _isCandle,
              candles: candles,
              priceMin: priceMin,
              priceMax: priceMax,
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '\$${priceMax.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _red.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '\$${(_price ?? 0).toStringAsFixed(4)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _red,
                    ),
                  ),
                ),
                Text(
                  '\$${((priceMax + priceMin) / 2).toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
                Text(
                  '\$${priceMin.toStringAsFixed(4)}',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: timeLabels
                  .map(
                    (t) => Text(
                      t,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );

    return Container(
      height: _chartHeight,
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(8),
      ),
      child: canScroll
          ? SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: chartContent,
            )
          : chartContent,
    );
  }

  String _formatChartBottomTime(DateTime dt) {
    return '${dt.year}/${dt.month}/${dt.day} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
  }

  Widget _buildChartBottomBar() {
    final now = DateTime.now();
    final priceStr = _price != null ? _price!.toStringAsFixed(2) : '—';
    final priceDisplay = _price != null
        ? '\$${_price!.toStringAsFixed(2)}'
        : '\$—';
    final isUp = (_changePercent ?? 0) >= 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Text(
            _changePercent != null
                ? '${_changePercent! >= 0 ? '+' : ''}${_changePercent!.toStringAsFixed(2)}%'
                : '—',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(
                8,
                (i) => Expanded(
                  child: Container(
                    margin: EdgeInsets.only(right: i < 7 ? 2 : 0),
                    height: 16,
                    decoration: BoxDecoration(
                      color: i.isEven ? _green : _red,
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                priceStr,
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                '时间: ${_formatChartBottomTime(now)}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: (isUp ? _green : _red).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  priceDisplay,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isUp ? _green : _red,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContentTabs() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Row(
        children: [
          _contentTab('话题', 0),
          const SizedBox(width: 24),
          _contentTab('概况', 1),
        ],
      ),
    );
  }

  Widget _contentTab(String label, int index) {
    final selected = _contentTabIndex == index;
    return GestureDetector(
      onTap: () {
        setState(() => _contentTabIndex = index);
        // 概况已由 _loadTokenStats 一次请求拉取，不再单独请求
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
              color: selected ? Colors.black87 : Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(
              color: selected ? _green : Colors.transparent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopicContent() {
    if (_contentTabIndex == 1) {
      return _buildOverviewContent();
    }
    return _buildTopicListContent();
  }

  Widget _buildTopicListContent() {
    if (_topicLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: _green)),
      );
    }
    if (_topicError != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '加载失败: $_topicError',
                style: TextStyle(color: Colors.red[700], fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: _loadTopicFeed, child: const Text('重试')),
            ],
          ),
        ),
      );
    }
    if (_topicPosts.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: const EmptyStateView(),
      );
    }
    return RefreshIndicator(
      onRefresh: _loadTopicFeed,
      color: _green,
      child: ListView(
        controller: _topicScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          ..._topicPosts.map(
            (p) => _TokenKlinePostItem(
              post: p,
              onTap: () => _openTopicDetail(p),
              onLike: () => _onTopicLike(p),
              onComment: () => _openTopicDetail(p),
              onStar: () => _onTopicStar(p),
              onShare: () => _onTopicShare(p),
              onMoreWithLink: (link) => _showTopicPostMoreMenu(p, link),
            ),
          ),
          if (_topicLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _green,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showTopicPostMoreMenu(PostInfo post, LayerLink link) {
    final currentUid = ref.read(userProvider).valueOrNull;
    final isOwn = currentUid != null && currentUid == post.userId;
    showPostMoreMenuOverlay(
      context: context,
      layerLink: link,
      isOwnPost: isOwn,
      onShare: () => _onTopicShare(post),
      onPin: isOwn ? () => _onTopicPin(post) : null,
      onEdit: isOwn ? () => _onTopicEdit(post) : null,
      onPrivate: isOwn ? () => _onTopicPrivate(post) : null,
      onDelete: isOwn ? () => _onTopicDelete(post) : null,
    );
  }

  void _onTopicShare(PostInfo post) {
    showDynamicShareSheet(
      context: context,
      post: post,
      onShared: () {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('已分享到聊天')));
      },
    );
  }

  Future<void> _onTopicPin(PostInfo post) async {
    try {
      await _dynamicApi.updatePost(postId: post.postId, isPinned: true);
      if (mounted) _loadTopicFeed();
    } catch (_) {}
  }

  void _onTopicEdit(PostInfo post) {
    if (mounted)
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('编辑功能请到动态详情使用')));
  }

  Future<void> _onTopicPrivate(PostInfo post) async {
    try {
      await _dynamicApi.updatePost(postId: post.postId, visibility: 'private');
      if (mounted) _loadTopicFeed();
    } catch (_) {}
  }

  Future<void> _onTopicDelete(PostInfo post) async {
    try {
      await _dynamicApi.deletePost(postId: post.postId);
      if (mounted) _loadTopicFeed();
    } catch (_) {}
  }

  void _openTopicDetail(PostInfo post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            DynamicDetailPage(postId: post.postId, initialPost: post),
      ),
    ).then((_) {
      if (mounted) _loadTopicFeed();
    });
  }

  void _onTopicLike(PostInfo p) async {
    try {
      if (p.isLiked) {
        await _dynamicApi.unlikePost(postId: p.postId);
      } else {
        await _dynamicApi.likePost(postId: p.postId);
      }
      if (mounted) {
        setState(() {
          final i = _topicPosts.indexWhere((e) => e.postId == p.postId);
          if (i >= 0) {
            final old = _topicPosts[i];
            _topicPosts[i] = PostInfo(
              postId: old.postId,
              userId: old.userId,
              userNickname: old.userNickname,
              content: old.content,
              type: old.type,
              visibility: old.visibility,
              parentPostId: old.parentPostId,
              onChainData: old.onChainData,
              likesCount: p.isLiked ? old.likesCount - 1 : old.likesCount + 1,
              commentsCount: old.commentsCount,
              rewardsAmount: old.rewardsAmount,
              starsCount: old.starsCount,
              createdAt: old.createdAt,
              updatedAt: old.updatedAt,
              mediaList: old.mediaList,
              isLiked: !p.isLiked,
              isStarred: old.isStarred,
            );
          }
        });
      }
    } catch (_) {}
  }

  void _onTopicStar(PostInfo p) async {
    try {
      if (p.isStarred) {
        await _dynamicApi.unstarPost(postId: p.postId);
      } else {
        await _dynamicApi.starPost(postId: p.postId);
      }
      if (mounted) {
        setState(() {
          final i = _topicPosts.indexWhere((e) => e.postId == p.postId);
          if (i >= 0) {
            final old = _topicPosts[i];
            _topicPosts[i] = PostInfo(
              postId: old.postId,
              userId: old.userId,
              userNickname: old.userNickname,
              content: old.content,
              type: old.type,
              visibility: old.visibility,
              parentPostId: old.parentPostId,
              onChainData: old.onChainData,
              likesCount: old.likesCount,
              commentsCount: old.commentsCount,
              rewardsAmount: old.rewardsAmount,
              starsCount: p.isStarred ? old.starsCount - 1 : old.starsCount + 1,
              createdAt: old.createdAt,
              updatedAt: old.updatedAt,
              mediaList: old.mediaList,
              isLiked: old.isLiked,
              isStarred: !p.isStarred,
            );
          }
        });
      }
    } catch (_) {}
  }

  Widget _buildOverviewContent() {
    if (_overviewLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator(color: _green)),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_overviewName.isNotEmpty) ...[
            Text(
              _overviewName,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
          ],
          Text(
            _overviewDescription,
            style: TextStyle(
              fontSize: 15,
              height: 1.6,
              color: Colors.grey[800],
            ),
          ),
          if (_overviewLinks.isNotEmpty) ...[
            const SizedBox(height: 20),
            const Text(
              '链接',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ..._overviewLinks.entries
                .where(
                  (e) =>
                      e.value != null && e.value.toString().trim().isNotEmpty,
                )
                .take(5)
                .map((e) {
                  final url = e.value is List
                      ? ((e.value as List).isNotEmpty
                            ? (e.value as List).first.toString()
                            : '')
                      : e.value.toString();
                  if (url.isEmpty) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      onTap: () async {
                        final uri = Uri.tryParse(url);
                        if (uri != null && await canLaunchUrl(uri)) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
                        }
                      },
                      child: Row(
                        children: [
                          Icon(Icons.link, size: 18, color: Colors.grey[600]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              url,
                              style: TextStyle(
                                fontSize: 14,
                                color: _green,
                                decoration: TextDecoration.underline,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
          ],
        ],
      ),
    );
  }
}

/// K 线页内单条动态：左侧头像 + 右侧 CommunityPostCard（与动态列表一致）
class _TokenKlinePostItem extends StatefulWidget {
  final PostInfo post;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onComment;
  final VoidCallback? onStar;
  final VoidCallback? onShare;
  final void Function(LayerLink link)? onMoreWithLink;

  const _TokenKlinePostItem({
    required this.post,
    this.onTap,
    this.onLike,
    this.onComment,
    this.onStar,
    this.onShare,
    this.onMoreWithLink,
  });

  @override
  State<_TokenKlinePostItem> createState() => _TokenKlinePostItemState();
}

class _TokenKlinePostItemState extends State<_TokenKlinePostItem> {
  Map<String, dynamic>? _userInfo;
  final LayerLink _moreLink = LayerLink();

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    try {
      final data = await UserApi().getUserOtherInfo({
        'userId': widget.post.userId,
      });
      if (mounted) setState(() => _userInfo = data);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final avatarUrl = _userInfo?['avatar_url'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Avatar(url: avatarUrl, size: 42, borderRadius: 6),
          const SizedBox(width: 12),
          Expanded(
            child: CommunityPostCard(
              post: widget.post,
              userInfo: _userInfo,
              showLeadingAvatar: false,
              onTap: widget.onTap,
              onLike: widget.onLike,
              onComment: widget.onComment,
              onStar: widget.onStar,
              onShare: widget.onShare,
              moreButtonLink: _moreLink,
              onMoreWithLink: widget.onMoreWithLink,
            ),
          ),
        ],
      ),
    );
  }
}

class _SimpleKlinePainter extends CustomPainter {
  final bool isCandle;
  final List<Map<String, double>> candles;
  final double priceMin;
  final double priceMax;

  _SimpleKlinePainter({
    this.isCandle = true,
    this.candles = const [],
    this.priceMin = 0.066,
    this.priceMax = 0.07,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.grey.shade200
      ..strokeWidth = 0.5;
    for (int i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (int i = 1; i < 4; i++) {
      final x = size.width * i / 4;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    if (candles.isEmpty) return;
    final greenPaint = Paint()..color = const Color(0xFF00D1A7);
    final redPaint = Paint()..color = const Color(0xFFFF3B30);
    final pad = 20.0;
    final chartW = size.width - pad * 2;
    final chartH = size.height - 24;
    double range = priceMax - priceMin;
    double effMin = priceMin;
    double effMax = priceMax;
    if (range <= 0) {
      final mid = (priceMin + priceMax) * 0.5;
      range = (mid.abs() * 0.001).clamp(0.0001, 0.01);
      effMin = mid - range / 2;
      effMax = mid + range / 2;
    }
    final n = candles.length;
    double yFromPrice(double p) => 12 + chartH * (1 - (p - effMin) / range);
    final spacing = chartW / n;

    if (isCandle) {
      final w = (chartW / n).clamp(2.0, 24.0);
      for (int i = 0; i < n; i++) {
        final c = candles[i];
        final o = c['o']!, h = c['h']!, l = c['l']!, cl = c['c']!;
        final x = pad + i * spacing + spacing / 2;
        final yO = yFromPrice(o);
        final yC = yFromPrice(cl);
        final yH = yFromPrice(h);
        final yL = yFromPrice(l);
        final isUp = cl >= o;
        final p = isUp ? greenPaint : redPaint;
        canvas.drawLine(Offset(x, yH), Offset(x, yL), p..strokeWidth = 1.2);
        final bodyTop = yO < yC ? yO : yC;
        final pixelH = (yO - yC).abs().clamp(1.0, chartH);
        canvas.drawRect(
          Rect.fromLTWH(x - w / 2 + 1, bodyTop, w - 2, pixelH),
          p,
        );
      }
    } else {
      // 折线图：收盘价连线
      final linePaint = Paint()
        ..color = const Color(0xFF00D1A7)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      for (int i = 0; i < n; i++) {
        final cl = candles[i]['c']!;
        final x = pad + i * spacing + spacing / 2;
        final y = yFromPrice(cl);
        if (i == 0)
          path.moveTo(x, y);
        else
          path.lineTo(x, y);
      }
      canvas.drawPath(path, linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _SimpleKlinePainter oldDelegate) =>
      oldDelegate.isCandle != isCandle ||
      oldDelegate.candles != candles ||
      oldDelegate.priceMin != priceMin ||
      oldDelegate.priceMax != priceMax;
}
