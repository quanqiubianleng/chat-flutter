import 'package:education/config/known_tokens.dart';
import 'package:education/services/api_service.dart';
import 'package:education/services/group_service.dart';
import 'package:flutter/material.dart';

/// 配置持仓门控规则（服务端多条规则为 AND，须全部满足）
class GroupGateRulesPage extends StatefulWidget {
  final int groupId;
  final int role;

  const GroupGateRulesPage({
    super.key,
    required this.groupId,
    required this.role,
  });

  bool get canEdit => role > 0;

  @override
  State<GroupGateRulesPage> createState() => _GroupGateRulesPageState();
}

/// 与后端 [evmRpcForChain] 一致的链标识
const _kChains = <String, String>{
  'bsc': 'BNB Chain (BSC)',
  'ethereum': 'Ethereum',
  'base': 'Base',
  'polygon': 'Polygon',
  'arbitrum': 'Arbitrum One',
  'optimism': 'Optimism',
};

class _RuleRow {
  int id;
  String chain;
  String contract;
  int tokenType;
  String minAmount;
  String tokenId;
  int decimals;

  _RuleRow({
    this.id = 0,
    this.chain = 'bsc',
    this.contract = '',
    this.tokenType = 0,
    this.minAmount = '',
    this.tokenId = '0',
    this.decimals = 0,
  });
}

class _GroupGateRulesPageState extends State<GroupGateRulesPage> {
  final GroupApi _api = GroupApi();
  bool _loading = true;
  String? _error;
  final List<_RuleRow> _rows = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final resp = await _api.listGroupGateRules({'group_id': widget.groupId});
      final list = resp['rules'] as List<dynamic>? ?? [];
      final next = <_RuleRow>[];
      for (final e in list) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e);
        next.add(_RuleRow(
          id: (m['id'] as num?)?.toInt() ?? 0,
          chain: (m['chain'] ?? 'bsc').toString(),
          contract: (m['contract_address'] ?? '').toString(),
          tokenType: (m['token_type'] as num?)?.toInt() ?? 0,
          minAmount: (m['min_amount'] ?? '').toString(),
          tokenId: (m['token_id'] as num?)?.toInt().toString() ?? '0',
          decimals: (m['decimals'] as num?)?.toInt() ?? 0,
        ));
      }
      if (!mounted) return;
      setState(() {
        _rows.clear();
        _rows.addAll(next);
        _loading = false;
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

  Future<void> _save() async {
    if (!widget.canEdit) return;
    final rules = <Map<String, dynamic>>[];
    for (final r in _rows) {
      final isFungible = r.tokenType == 0 || r.tokenType == 3;
      rules.add({
        'id': r.id,
        'chain': r.chain.trim(),
        'contract_address': r.tokenType == 3 ? '' : r.contract.trim(),
        'token_type': r.tokenType,
        'min_amount': isFungible ? r.minAmount.trim() : '',
        'token_id': int.tryParse(r.tokenId.trim()) ?? 0,
        'decimals': isFungible ? r.decimals : 0,
      });
    }
    try {
      final resp = await _api.setGroupGateRules({
        'group_id': widget.groupId,
        'rules': rules,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(resp['msg']?.toString() ?? '已保存')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _applyBscPreset(_RuleRow r, {required bool nativeBnb}) {
    setState(() {
      r.chain = 'bsc';
      if (nativeBnb) {
        r.tokenType = 3;
        r.contract = '';
        r.decimals = 18;
      } else {
        r.tokenType = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F3F5),
      appBar: AppBar(
        title: const Text('持仓门控规则'),
        backgroundColor: const Color(0xFFF2F3F5),
        elevation: 0,
        actions: [
          if (widget.canEdit)
            TextButton(
              onPressed: _loading ? null : _save,
              child: const Text('保存'),
            ),
        ],
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
                        FilledButton(onPressed: _load, child: const Text('重试')),
                      ],
                    ),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    const Text(
                      '说明：多条规则须全部满足（AND）。数量请按「枚」填写，例如 1 USDT、1 BBT、1 BNB（不要使用 wei）。ERC20 的小数位填 0 表示由服务端按常见合约推断；自定义代币请填写正确 decimals。',
                      style: TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                    const SizedBox(height: 12),
                    ..._rows.asMap().entries.map((e) => _ruleCard(e.key, e.value)),
                    if (widget.canEdit)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _rows.add(_RuleRow())),
                          icon: const Icon(Icons.add),
                          label: const Text('添加规则'),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _ruleCard(int index, _RuleRow r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('规则 ${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const Spacer(),
              if (widget.canEdit)
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  onPressed: () => setState(() => _rows.removeAt(index)),
                ),
            ],
          ),
          DropdownButtonFormField<String>(
            value: _kChains.containsKey(r.chain) ? r.chain : 'bsc',
            decoration: const InputDecoration(labelText: '链'),
            items: _kChains.entries
                .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                .toList(),
            onChanged: widget.canEdit
                ? (v) {
                    if (v == null) return;
                    setState(() => r.chain = v);
                  }
                : null,
          ),
          DropdownButtonFormField<int>(
            value: r.tokenType,
            decoration: const InputDecoration(labelText: '资产类型'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('ERC20 代币')),
              DropdownMenuItem(value: 3, child: Text('主链原生币 (BNB/ETH 等)')),
              DropdownMenuItem(value: 1, child: Text('ERC721 NFT')),
              DropdownMenuItem(value: 2, child: Text('ERC1155 NFT')),
            ],
            onChanged: widget.canEdit
                ? (v) {
                    if (v == null) return;
                    setState(() {
                      r.tokenType = v;
                      if (v == 3) {
                        r.contract = '';
                        if (r.decimals <= 0) r.decimals = 18;
                      }
                    });
                  }
                : null,
          ),
          if (widget.canEdit && r.chain == 'bsc') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                TextButton(
                  onPressed: () => setState(() {
                    r.tokenType = 0;
                    r.contract = KnownTokens.bbtContract;
                    r.decimals = 18;
                  }),
                  child: const Text('填 BBT'),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    r.tokenType = 0;
                    r.contract = KnownTokens.usdtBsc;
                    r.decimals = 18;
                  }),
                  child: const Text('填 BSC USDT'),
                ),
                TextButton(
                  onPressed: () {
                    _applyBscPreset(r, nativeBnb: true);
                  },
                  child: const Text('原生 BNB'),
                ),
              ],
            ),
          ],
          if (r.tokenType != 3)
            TextFormField(
              enabled: widget.canEdit,
              initialValue: r.contract,
              decoration: const InputDecoration(
                labelText: '合约地址',
                hintText: 'ERC20 / NFT 合约',
              ),
              onChanged: (v) => r.contract = v,
            ),
          if (r.tokenType == 3)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                '主链原生资产（如 BNB / ETH），无需合约地址',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
              ),
            ),
          if (r.tokenType == 0 || r.tokenType == 3) ...[
            TextFormField(
              enabled: widget.canEdit,
              initialValue: r.minAmount,
              decoration: const InputDecoration(
                labelText: '最小持有数量',
                hintText: '例如 1 表示 1 枚',
              ),
              onChanged: (v) => r.minAmount = v,
            ),
            TextFormField(
              enabled: widget.canEdit,
              initialValue: r.decimals == 0 ? '' : r.decimals.toString(),
              decoration: InputDecoration(
                labelText: '小数位 decimals',
                hintText: r.tokenType == 3 ? '原生币一般为 18' : '填 0 表示自动推断（常见 USDT/BBT）',
              ),
              keyboardType: TextInputType.number,
              onChanged: (v) {
                final n = int.tryParse(v.trim());
                r.decimals = n ?? 0;
              },
            ),
          ],
          if (r.tokenType == 1 || r.tokenType == 2)
            TextFormField(
              enabled: widget.canEdit,
              initialValue: r.tokenId,
              decoration: const InputDecoration(
                labelText: 'NFT tokenId（0 表示任意一枚）',
              ),
              onChanged: (v) => r.tokenId = v,
            ),
        ],
      ),
    );
  }
}
