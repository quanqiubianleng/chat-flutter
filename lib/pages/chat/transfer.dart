import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_config.dart';

class TransferPage extends StatefulWidget {
  // 接收人信息
  final String toUserNickname;   // 昵称，如 "53ead682"
  final String toUserAddress;    // 完整钱包地址
  final String? avatarUrl;       // 头像 URL，可为空
  final int? toUserId;       // 转账对象ID
  final void Function(int amount, String remark, String icon)? onGenerateTransfer;

  const TransferPage({
    Key? key,
    required this.toUserNickname,
    required this.toUserAddress,
    required this.toUserId,
    this.avatarUrl,
    this.onGenerateTransfer,
  }) : super(key: key);

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final FocusNode _amountFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // 页面加载完成后自动聚焦金额输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _amountFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    super.dispose();
  }

  // 格式化地址显示（前10 + ... + 后8）
  String _formatAddress(String address) {
    if (address.length < 18) return address;
    return '${address.substring(0, 10)}...${address.substring(address.length - 8)}';
  }

  // 处理生成红包按钮点击
  void _handleGenerate() {
    final countText = _amountController.text.trim();
    if (countText.isEmpty) return;

    final amount = int.tryParse(countText) ?? 0;
    final noteText = _noteController.text.trim();
    final note = noteText.isEmpty ? '' : noteText;
    if (amount > 0) {
      // 调用父页面传入的回调函数
      widget.onGenerateTransfer?.call(amount, note, AppConfig.title);

      // 可选：成功后关闭页面
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true, // 键盘弹出时调整布局
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '好友转账',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      backgroundColor: Colors.grey[100],
      body: SingleChildScrollView(
        physics: AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          children: [
            // 接收人信息卡片
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  // 头像
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: widget.avatarUrl != null && widget.avatarUrl!.isNotEmpty
                        ? Image.network(
                      widget.avatarUrl!,
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return _defaultAvatar();
                      },
                    )
                        : _defaultAvatar(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.toUserNickname,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatAddress(widget.toUserAddress),
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 转账代币与网络
            ListTile(
              title: const Text('转账代币与网络'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text('转账代币与网络', style: TextStyle(color: Colors.grey)),
                  Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
              onTap: () {
                // TODO: 打开代币选择页面
              },
            ),

            const Divider(height: 1),

            // 转账数量 & 余额
            ListTile(
              title: const Text('转账数量'),
              subtitle: const Text('可用: 0', style: TextStyle(color: Colors.grey)),
              trailing: const Text('全部', style: TextStyle(color: Colors.green)),
              onTap: () {
                // TODO: 填充全部余额
              },
            ),

            // 金额输入框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              child: TextField(
                controller: _amountController,
                focusNode: _amountFocusNode,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: '0.000',
                  hintStyle: TextStyle(fontSize: 48, color: Colors.grey),
                  border: InputBorder.none,
                ),
                // 可选：光标颜色也改成绿色，更协调
                cursorColor: Colors.green,
                onChanged: (_) => setState(() {}),
              ),
            ),

            const SizedBox(height: 30),

            // 备注输入框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _noteController,
                decoration: InputDecoration(
                  hintText: '您最多可备注 24 个字',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  // 焦点时的边框 → 关键：绿色高亮
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.green), // 绿色 + 加粗一点
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
                maxLength: 24,
                // 可选：光标颜色也改成绿色，更协调
                cursorColor: Colors.green,
              ),
            ),

            const SizedBox(height: 40),

            // 转账按钮
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _amountController.text.trim().isEmpty
                      ? null
                      : () {
                    // TODO: 执行转账逻辑
                    print('转账给: ${widget.toUserNickname}');
                    print('地址: ${widget.toUserAddress}');
                    print('金额: ${_amountController.text}');
                    print('备注: ${_noteController.text}');
                    _handleGenerate();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    disabledBackgroundColor: Colors.red[200],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    '转账',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ),
            ),

            //const SizedBox(height: 30), // 底部安全距离
          ],
        ),
      ),
    );
  }

  // 默认头像
  Widget _defaultAvatar() {
    return Container(
      width: 60,
      height: 60,
      color: Colors.amber[100],
      child: const Icon(Icons.account_balance_wallet, size: 40, color: Colors.amber),
    );
  }
}