import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class RedPacketPage extends StatefulWidget {
  final int? toUserId;       // 转账对象ID
  /// 点击“生成红包”时的回调函数
  /// 参数1: 红包数量（int）
  /// 参数2: 祝福语（String）
  final void Function(int count, int amount, String wish)? onGenerateRedPacket;

  const RedPacketPage({Key? key, required this.toUserId,this.onGenerateRedPacket,}) : super(key: key);

  @override
  State<RedPacketPage> createState() => _RedPacketPageState();
}

class _RedPacketPageState extends State<RedPacketPage> {
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _wishController = TextEditingController();
  final FocusNode _countFocusNode = FocusNode();
  final String _hintText = "财源滚滚，万事如意";
  int count = 1;

  @override
  void initState() {
    super.initState();
    // 页面加载后自动聚焦数量输入框
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _countFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _countController.dispose();
    _wishController.dispose();
    _countFocusNode.dispose();
    super.dispose();
  }

  // 处理生成红包按钮点击
  void _handleGenerate() {
    final countText = _countController.text.trim();
    if (countText.isEmpty) return;

    final amount = int.tryParse(countText) ?? 0;
    final wishText = _wishController.text.trim();
    final wish = wishText.isEmpty ? _hintText : wishText;
    if (amount > 0) {
      // 调用父页面传入的回调函数
      widget.onGenerateRedPacket?.call(count, amount, wish);

      // 可选：成功后关闭页面
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false, // 键盘弹出时自动调整
      appBar: AppBar(
        backgroundColor: Colors.red,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '红包',
          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_horiz, color: Colors.white),
            onPressed: () {
              // TODO: 红包记录
            },
          ),
        ],
      ),
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),

            // 总数量输入区域
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Text(
                    '总数量',
                    style: TextStyle(fontSize: 16),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _countController,
                      focusNode: _countFocusNode,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 16),
                      decoration: const InputDecoration(
                        hintText: '可用数量 0',
                        hintStyle: TextStyle(color: Colors.grey),
                        border: InputBorder.none,
                        suffixText: ' 个',
                        suffixStyle: TextStyle(color: Colors.black, fontSize: 16),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 获取更多 VBOX 和 去交易
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  '获取更多 VBOX',
                  style: TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    print('去交易');
                    // TODO: 跳转到交易页面
                  },
                  child: const Text(
                    '去交易',
                    style: TextStyle(color: Colors.green, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 50),

            // 祝福语输入框
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '祝福语',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _wishController,
                      decoration: InputDecoration(
                        hintText: _hintText,
                        hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.zero,
                      ),
                      style: const TextStyle(fontSize: 14),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 60),

            // 生成红包按钮（根据数量是否输入决定启用/禁用）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _countController.text.trim().isNotEmpty
                      ? () {
                    print('生成红包，数量: ${_countController.text}');
                    print('祝福语: ${_wishController.text}');
                    // TODO: 真实生成红包逻辑
                    _handleGenerate();
                  }
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _countController.text.trim().isNotEmpty
                        ? Colors.red
                        : Colors.grey[400],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    '生成红包',
                    style: TextStyle(fontSize: 18, color: Colors.white),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 底部提示
            const Text(
              '未领取的红包，24小时后自动退回',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),

            const SizedBox(height: 40), // 底部安全距离
          ],
        ),
      ),
    );
  }
}