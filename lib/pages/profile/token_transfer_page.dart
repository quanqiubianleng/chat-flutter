import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/wallet_repository.dart';
import 'package:education/pages/profile/transfer_contact_sheet.dart';
import 'package:education/pages/profile/transfer_token_sheet.dart';
import 'package:education/pages/profile/qr_scan_page.dart';
import 'package:education/services/evm_transfer_service.dart';
import 'package:education/widgets/account/verify_password_dialog.dart';

/// Token 页点击「转账」进入的页面，按参考图布局
class TokenTransferPage extends StatefulWidget {
  final String walletAddress;

  const TokenTransferPage({super.key, this.walletAddress = ''});

  @override
  State<TokenTransferPage> createState() => _TokenTransferPageState();
}

class _TokenTransferPageState extends State<TokenTransferPage> {
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  static const Color _green = Color(0xFF00D1A7);
  String _selectedNetworkId = 'bnb-mainnet';
  String _selectedNetworkName = 'BNB Chain';
  String _selectedTokenSymbol = 'BNB';
  /// 选中代币的余额 wei 字符串（用于校验与「全部」）
  String _selectedBalanceWeiStr = '0';
  int _selectedDecimals = 18;
  String? _selectedContractAddress;
  String _formattedBalance = '0';
  String _formattedUsd = '\$0';
  bool _transferring = false;

  bool get _isAddressValid {
    final s = _addressController.text.trim();
    if (!s.startsWith('0x') || s.length != 42) return false;
    final hex = s.substring(2);
    if (hex.length != 40) return false;
    return RegExp(r'^[0-9a-fA-F]+$').hasMatch(hex);
  }

  bool get _isAmountValid {
    final s = _amountController.text.trim();
    if (s.isEmpty) return false;
    final amount = double.tryParse(s);
    return amount != null && amount > 0;
  }

  bool get _isAmountWithinBalance {
    final s = _amountController.text.trim();
    if (s.isEmpty) return false;
    final amount = double.tryParse(s);
    if (amount == null || amount <= 0) return false;
    final balanceWei = BigInt.tryParse(_selectedBalanceWeiStr) ?? BigInt.zero;
    final amountWei = BigInt.from((amount * math.pow(10, _selectedDecimals)).round());
    return amountWei <= balanceWei;
  }

  bool get _canTransfer =>
      !_transferring && _isAddressValid && _isAmountValid && _isAmountWithinBalance;

  @override
  void dispose() {
    _addressController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '转账',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 接收地址
                  _sectionLabel('接收地址'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _addressController,
                            decoration: InputDecoration(
                              hintText: '请输入接收地址',
                              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 15),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.person_outline, color: Colors.grey[700]),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => TransferContactSheet(
                                onSelect: (address, _) {
                                  _addressController.text = address;
                                  setState(() {});
                                },
                              ),
                            );
                          },
                        ),
                        Container(width: 1, height: 20, color: Colors.grey[300]),
                        IconButton(
                          icon: Icon(Icons.qr_code_scanner_outlined, color: Colors.grey[700]),
                          onPressed: () async {
                            final result = await Navigator.of(context).push<String>(
                              MaterialPageRoute(builder: (_) => const QrScanPage()),
                            );
                            if (result != null && mounted) {
                              _addressController.text = result;
                              setState(() {});
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // 转账代币与网络
                  _sectionLabel('转账代币与网络'),
                  InkWell(
                    onTap: () {
                      final currentNetworkId = _selectedNetworkId;
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => TransferTokenSheet(
                          key: ValueKey('token_sheet_$currentNetworkId'),
                          walletAddress: widget.walletAddress,
                          initialNetworkId: currentNetworkId,
                          onSelect: (networkId, networkName, tokenSymbol, balanceWeiStr, decimals, contractAddress, formattedBalance, formattedUsd) {
                            setState(() {
                              _selectedNetworkId = networkId;
                              _selectedNetworkName = networkName;
                              _selectedTokenSymbol = tokenSymbol;
                              _selectedBalanceWeiStr = balanceWeiStr;
                              _selectedDecimals = decimals;
                              _selectedContractAddress = contractAddress;
                              _formattedBalance = formattedBalance;
                              _formattedUsd = formattedUsd;
                              _amountController.text = '';
                            });
                          },
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('$_selectedNetworkName · $_selectedTokenSymbol', style: const TextStyle(color: Colors.black87, fontSize: 15, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                Text('余额: $_formattedBalance $_selectedTokenSymbol', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(_formattedUsd, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                              const SizedBox(height: 4),
                              Icon(Icons.chevron_right, color: Colors.grey[600], size: 22),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // 转账数量（余额与「全部」与选中代币一致）
                  _sectionLabel('转账数量'),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _amountController,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                                ],
                                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
                                decoration: InputDecoration(
                                  hintText: '0.00',
                                  hintStyle: TextStyle(fontSize: 28, color: Colors.grey[400]),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                  suffixText: _selectedTokenSymbol,
                                  suffixStyle: TextStyle(fontSize: 16, color: Colors.grey[600]),
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('余额: $_formattedBalance', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    _amountController.text = _formattedBalance;
                                    setState(() {});
                                  },
                                  child: const Text('全部', style: TextStyle(fontSize: 14, color: Color(0xFF00D1A7), fontWeight: FontWeight.w500)),
                                ),
                              ],
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
          // 底部转账按钮（地址、数量合法且不超过余额时可点）
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _canTransfer ? _doTransfer : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    disabledBackgroundColor: Colors.grey[300],
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey[600],
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  child: _transferring
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('转账', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  Future<void> _doTransfer() async {
    final didId = await UserCache.getDid();
    if (didId == null || didId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先登录')),
        );
      }
      return;
    }
    final privateKey = await VerifyPasswordDialog.showForPrivateKey(context, didId: didId);
    if (privateKey == null || !mounted) return;

    final toAddress = _addressController.text.trim();
    final amountStr = _amountController.text.trim();
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return;
    final amountWei = BigInt.from((amount * math.pow(10, _selectedDecimals)).round());
    final balanceWei = BigInt.tryParse(_selectedBalanceWeiStr) ?? BigInt.zero;
    if (amountWei > balanceWei) return;

    setState(() => _transferring = true);
    try {
      final fromAddress = widget.walletAddress;
      if (fromAddress.isEmpty || !fromAddress.startsWith('0x')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('当前钱包地址无效')),
          );
        }
        return;
      }

      String txHash;
      if (_selectedContractAddress == null || _selectedContractAddress!.isEmpty) {
        txHash = await EvmTransferService.sendNative(
          fromAddress: fromAddress,
          toAddress: toAddress,
          amountWei: amountWei,
          balanceWei: balanceWei,
          privateKeyHex: privateKey,
          networkId: _selectedNetworkId,
        );
      } else {
        txHash = await EvmTransferService.sendErc20(
          fromAddress: fromAddress,
          toAddress: toAddress,
          contractAddress: _selectedContractAddress!,
          amountWei: amountWei,
          privateKeyHex: privateKey,
          networkId: _selectedNetworkId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('转账已提交\n交易哈希: ${txHash.substring(0, 10)}...')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        final msg = e.toString();
        final friendly = msg.contains('insufficient') || msg.contains('余额')
            ? '余额不足或网络费用不足'
            : (msg.length > 80 ? '${msg.substring(0, 80)}...' : msg);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('转账失败: $friendly'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _transferring = false);
    }
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.grey[800],
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
