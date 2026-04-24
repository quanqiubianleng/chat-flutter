import 'dart:math' as math;

import 'package:education/config/app_config.dart';
import 'package:education/config/known_tokens.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/pages/common/mini_program_webview_page.dart';
import 'package:education/services/api_service.dart';
import 'package:education/services/evm_transfer_service.dart';
import 'package:education/services/group_service.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/account/verify_password_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// 从群设置进入时的默认聚焦：扩容档位或 Club 升级
enum GroupUpgradeHighlight {
  capacity,
  club,
}

/// 群扩容 /升级 Club：套餐选择、上限与价格展示、协议确认后链上支付
class GroupUpgradePlansPage extends StatefulWidget {
  final int groupId;
  /// 0普通群 1 Club
  final int groupType;
  /// 2群主
  final int role;
  final int currentMaxMembers;
  final int currentMemberCount;
  final GroupUpgradeHighlight initialHighlight;

  const GroupUpgradePlansPage({
    super.key,
    required this.groupId,
    required this.groupType,
    required this.role,
    required this.currentMaxMembers,
    required this.currentMemberCount,
    this.initialHighlight = GroupUpgradeHighlight.capacity,
  });

  @override
  State<GroupUpgradePlansPage> createState() => _GroupUpgradePlansPageState();
}

class _TierView {
  final int addSlots;
  final String priceBbt;
  _TierView({required this.addSlots, required this.priceBbt});
}

class _GroupUpgradePlansPageState extends State<GroupUpgradePlansPage> {
  final GroupApi _api = GroupApi();
  final UserApi _userApi = UserApi();

  bool _loading = true;
  String? _error;
  List<_TierView> _tiers = [];
  String _upgradeClubBbt = '500';
  String _treasury = '';
  String _contract = '';
  String _chain = 'bnb-mainnet';
  String _agreementUrl = '';

  /// null = 未选；true = Club；false = 扩容且 [_selectedTierIndex] 有效
  bool? _selectClub;
  int _selectedTierIndex = 0;

  bool _agreed = false;
  bool _submitting = false;
  String _payStage = '';

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final opts = await _api.getGroupBbtPayOptions();
      final raw = (opts['tiers'] as List<dynamic>? ?? []);
      final tiers = <_TierView>[];
      for (final e in raw) {
        if (e is! Map<String, dynamic>) continue;
        final add = (e['add_slots'] as num?)?.toInt() ?? 0;
        final price = (e['price_bbt'] ?? '').toString();
        if (add > 0 && price.isNotEmpty) {
          tiers.add(_TierView(addSlots: add, priceBbt: price));
        }
      }
      final agreement =
          (opts['agreement_url'] ?? '').toString().trim();
      final fallbackAgree = AppConfig.agreeUrl.trim();
      if (!mounted) return;
      setState(() {
        _tiers = tiers;
        _upgradeClubBbt = (opts['upgrade_club_bbt'] ?? '500').toString();
        _treasury = (opts['treasury'] ?? '').toString().trim();
        _contract = (opts['contract'] ?? KnownTokens.bbtContract).toString();
        _chain = (opts['chain'] ?? 'bnb-mainnet').toString();
        _agreementUrl =
            agreement.isNotEmpty ? agreement : fallbackAgree;
        _loading = false;
        _applyInitialSelection();
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _applyInitialSelection() {
    if (widget.initialHighlight == GroupUpgradeHighlight.club) {
      _selectClub = true;
    } else {
      _selectClub = _tiers.isEmpty ? true : false;
      _selectedTierIndex = 0;
    }
  }

  BigInt _toWei(String bbt) {
    final value = double.tryParse(bbt.trim()) ?? 0;
    if (value <= 0) return BigInt.zero;
    return BigInt.from((value * math.pow(10, 18)).round());
  }

  Future<String?> _loadMyWalletAddress() async {
    try {
      final data = await _userApi.getUserInfo();
      final wallet = (data['wallet_address'] ?? data['walletAddress'] ?? '')
          .toString();
      if (wallet.startsWith('0x') && wallet.length == 42) return wallet;
    } catch (_) {}
    return null;
  }

  Future<void> _openAgreement() async {
    final url = _agreementUrl.trim();
    if (url.isEmpty) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('群增值服务说明'),
          content: SingleChildScrollView(
            child: Text(
              _defaultAgreementText,
              style: TextStyle(fontSize: 14, color: Colors.grey[800]),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('知道了'),
            ),
          ],
        ),
      );
      return;
    }
    if (!mounted) return;
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => MiniProgramWebViewPage(
          initialUrl: url,
          title: '群增值服务协议',
        ),
      ),
    );
  }

  Future<void> _onConfirmPay() async {
    if (widget.role != 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('仅群主可操作')),
      );
      return;
    }
    if (widget.groupType != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('当前群类型无需在此升级')),
      );
      return;
    }
    if (!_agreed) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先阅读并同意协议')),
      );
      return;
    }
    if (_treasury.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('未配置金库地址，请联系管理员')),
      );
      return;
    }
    final confirmed = await _showPayConfirmDialog();
    if (!mounted || !confirmed) return;
    if (_selectClub == true) {
      await _payClub();
    } else {
      if (_tiers.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('暂无扩容套餐')),
        );
        return;
      }
      await _payCapacity();
    }
  }

  Future<bool> _showPayConfirmDialog() async {
    final isClub = _selectClub == true;
    final amount = isClub
        ? _upgradeClubBbt
        : _tiers[_selectedTierIndex.clamp(0, _tiers.length - 1)].priceBbt;
    final planName = isClub
        ? '升级为 Club'
        : '扩容 +${_tiers[_selectedTierIndex.clamp(0, _tiers.length - 1)].addSlots} 人';
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认支付'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('您将支付 $amount BBT，用于$planName。'),
            const SizedBox(height: 10),
            Text(
              '链上交易会额外产生 Gas 手续费（由钱包余额支付，不包含在 BBT 金额内）。',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Text(
              '请确认收款地址、金额与网络无误后继续。',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('继续支付'),
          ),
        ],
      ),
    );
    return result == true;
  }

  void _setPayStage(String text) {
    if (!mounted) return;
    setState(() => _payStage = text);
  }

  Future<void> _showPaymentFailedDialog({
    required String reason,
    required Future<void> Function() onRetry,
  }) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('支付失败'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reason),
            const SizedBox(height: 10),
            Text(
              '建议检查：',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[800],
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '1) 钱包 BBT 与 Gas 余额是否充足\n'
              '2) 链网络是否选择正确\n'
              '3) 稍后重试或查看链上交易状态',
              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('我知道了'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              onRetry();
            },
            child: const Text('重试支付'),
          ),
        ],
      ),
    );
  }

  String _friendlyError(Object e) {
    final raw = e.toString();
    final lower = raw.toLowerCase();
    if (lower.contains('insufficient') ||
        lower.contains('余额不足') ||
        lower.contains('not enough')) {
      return '余额不足，请补充 BBT 或 Gas 后重试。';
    }
    if (lower.contains('rejected') ||
        lower.contains('denied') ||
        lower.contains('cancel')) {
      return '已取消支付，请确认后重新发起。';
    }
    if (lower.contains('timeout') || lower.contains('timed out')) {
      return '网络超时，请稍后重试。';
    }
    return raw;
  }

  String _explorerBaseForChain(String chain) {
    switch (chain) {
      case 'bnb-mainnet':
        return 'https://bscscan.com';
      case 'base-mainnet':
        return 'https://basescan.org';
      case 'eth-mainnet':
        return 'https://etherscan.io';
      case 'x-layer':
        return 'https://www.oklink.com/xlayer';
      default:
        return 'https://bscscan.com';
    }
  }

  Future<void> _showPaySuccessDialog({
    required String txHash,
    required String successText,
  }) async {
    if (!mounted) return;
    final normalized = txHash.startsWith('0x') ? txHash : '0x$txHash';
    final txUrl = '${_explorerBaseForChain(_chain)}/tx/$normalized';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(successText),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('交易已提交并同步成功，你可以在区块浏览器查看确认状态。'),
            const SizedBox(height: 10),
            Text(
              'TxHash',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            SelectableText(
              normalized,
              style: TextStyle(fontSize: 12, color: Colors.grey[800]),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: normalized));
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('txHash 已复制')),
              );
            },
            child: const Text('复制 txHash'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('完成'),
          ),
          FilledButton(
            onPressed: () async {
              final uri = Uri.parse(txUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('无法打开区块浏览器链接')),
                );
              }
            },
            child: const Text('查看交易'),
          ),
        ],
      ),
    );
  }

  Future<void> _payCapacity() async {
    final tier = _tiers[_selectedTierIndex.clamp(0, _tiers.length - 1)];
    final amountWei = _toWei(tier.priceBbt);
    if (amountWei <= BigInt.zero) return;

    _setPayStage('正在校验登录状态...');
    final did = await UserCache.getDid();
    if (did == null || did.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }
    final fromWallet = await _loadMyWalletAddress();
    if (fromWallet == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取钱包地址')),
      );
      return;
    }
    _setPayStage('请验证密码以继续支付...');
    if (!mounted) return;
    final pk = await VerifyPasswordDialog.showForPrivateKey(
      context,
      didId: did,
    );
    if (!mounted || pk == null) return;

    setState(() {
      _submitting = true;
      _payStage = '正在发起链上转账...';
    });
    try {
      final txHash = await EvmTransferService.sendErc20(
        fromAddress: fromWallet,
        toAddress: _treasury,
        contractAddress: _contract,
        amountWei: amountWei,
        privateKeyHex: pk,
        networkId: _chain,
      );
      _setPayStage('链上已提交，正在同步服务端...');
      await _api.purchaseGroupCapacity({
        'group_id': widget.groupId,
        'add_slots': tier.addSlots,
        'tx_hash': txHash,
      });
      _setPayStage('支付完成，正在返回...');
      if (!mounted) return;
      await _showPaySuccessDialog(
        txHash: txHash,
        successText: '扩容成功',
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      final reason = _friendlyError(e);
      await _showPaymentFailedDialog(
        reason: '扩容失败：$reason',
        onRetry: _payCapacity,
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _payStage = '';
        });
      }
    }
  }

  Future<void> _payClub() async {
    final amountWei = _toWei(_upgradeClubBbt);
    if (amountWei <= BigInt.zero) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('升级价格配置无效')),
      );
      return;
    }

    _setPayStage('正在校验登录状态...');
    final did = await UserCache.getDid();
    if (did == null || did.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先登录')),
      );
      return;
    }
    final fromWallet = await _loadMyWalletAddress();
    if (fromWallet == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('无法获取钱包地址')),
      );
      return;
    }
    _setPayStage('请验证密码以继续支付...');
    if (!mounted) return;
    final pk = await VerifyPasswordDialog.showForPrivateKey(
      context,
      didId: did,
    );
    if (!mounted || pk == null) return;

    setState(() {
      _submitting = true;
      _payStage = '正在发起链上转账...';
    });
    try {
      final txHash = await EvmTransferService.sendErc20(
        fromAddress: fromWallet,
        toAddress: _treasury,
        contractAddress: _contract,
        amountWei: amountWei,
        privateKeyHex: pk,
        networkId: _chain,
      );
      _setPayStage('链上已提交，正在同步服务端...');
      await _api.upgradeGroupToClub({
        'group_id': widget.groupId,
        'tx_hash': txHash,
      });
      _setPayStage('支付完成，正在返回...');
      if (!mounted) return;
      await _showPaySuccessDialog(
        txHash: txHash,
        successText: '升级成功',
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      final reason = _friendlyError(e);
      await _showPaymentFailedDialog(
        reason: '升级失败：$reason',
        onRetry: _payClub,
      );
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
          _payStage = '';
        });
      }
    }
  }

  Widget _tierCard(int index, _TierView tier) {
    final selected = _selectClub != true && _selectedTierIndex == index;
    final newCap = widget.currentMaxMembers + tier.addSlots;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            setState(() {
              _selectClub = false;
              _selectedTierIndex = index;
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  selected                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: selected ? Colors.blue : Colors.grey,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '扩容 +${tier.addSlots} 人',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '成员上限：${widget.currentMaxMembers} → $newCap',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${tier.priceBbt} BBT',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange.shade800,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _clubCard() {
    final selected = _selectClub == true;
    return Material(
      color: selected ? Colors.deepPurple.shade50 : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _selectClub = true),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                color: selected ? Colors.deepPurple : Colors.grey,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '升级为 Club 大群',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '更高成员规模与 Club 能力；成员上限以平台规则为准。',
                      style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                    ),
                  ],
                ),
              ),
              Text(
                '$_upgradeClubBbt BBT',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('群升级与扩容'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_error!, textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _loadOptions,
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '当前成员 ${widget.currentMemberCount} / 上限 ${widget.currentMaxMembers}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[800],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '请选择套餐并完成链上 BBT 支付；支付成功后自动生效。',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '提示：链上支付会产生 Gas 手续费，请确保钱包有足够主链代币。',
                        style: TextStyle(fontSize: 12, color: Colors.orange[800]),
                      ),
                      const SizedBox(height: 20),
                      if (_tiers.isNotEmpty) ...[
                        Text(
                          '扩容套餐',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 10),
                        ..._tiers.asMap().entries.map(
                          (e) => _tierCard(e.key, e.value),
                        ),
                        const SizedBox(height: 16),
                      ],
                      Text(
                        '升级 Club',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                      ),
                      const SizedBox(height: 10),
                      _clubCard(),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Checkbox(
                            value: _agreed,
                            onChanged: (v) =>
                                setState(() => _agreed = v ?? false),
                          ),
                          Expanded(
                            child: GestureDetector(
                              onTap: _openAgreement,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: RichText(
                                  text: TextSpan(
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey[800],
                                    ),
                                    children: [
                                      const TextSpan(text: '我已阅读并同意 '),
                                      TextSpan(
                                        text: '《群增值服务协议》',
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_submitting && _payStage.isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade100),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _payStage,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blueGrey[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed:
                            _submitting || !_agreed ? null : _onConfirmPay,
                        child: _submitting
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _selectClub == true
                                    ? '确认支付 $_upgradeClubBbt BBT 升级 Club'
                                    : _tiers.isEmpty
                                    ? '请选择套餐'
                                    : '确认支付 ${_tiers[_selectedTierIndex.clamp(0, _tiers.length - 1)].priceBbt} BBT 扩容',
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

const String _defaultAgreementText = '''
群增值服务（扩容 / 升级 Club）用户须知：

1. 您自愿通过区块链向平台指定地址转入 BBT，用于购买对应群权益；链上转账具有不可逆性，请确认金额与收款地址无误。

2. 平台在链上交易确认后，将为您开通所选套餐对应的成员上限或 Club 类型；具体校验规则以服务端为准。

3. 因网络拥堵、合约限制、钱包环境或您自身操作失误导致的损失，由您自行承担；如遇异常请通过官方渠道反馈。

4. 本说明未尽事宜，适用平台已公示的用户协议及隐私政策。
''';
