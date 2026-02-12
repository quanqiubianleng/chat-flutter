import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:education/pages/profile/transfer_contact_sheet.dart';
import 'package:education/pages/profile/transfer_token_sheet.dart';
import 'package:education/pages/profile/qr_scan_page.dart';

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: SingleChildScrollView(
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
                          onSelect: (networkId, networkName, tokenSymbol) {
                            setState(() {
                              _selectedNetworkId = networkId;
                              _selectedNetworkName = networkName;
                              _selectedTokenSymbol = tokenSymbol;
                            });
                          },
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('$_selectedNetworkName', style: const TextStyle(color: Colors.black87, fontSize: 15)),
                          Icon(Icons.chevron_right, color: Colors.grey[600], size: 22),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  // 转账数量
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
                                decoration: const InputDecoration(
                                  hintText: '0.00',
                                  hintStyle: TextStyle(fontSize: 28, color: Colors.grey),
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: (_) => setState(() {}),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('余额: 0', style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () {
                                    _amountController.text = '0';
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
          // 底部转账按钮
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              child: SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('转账功能开发中')));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  child: const Text('转账', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
