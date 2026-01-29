import 'package:flutter/material.dart';
import 'package:education/widgets/common/image_upload_button.dart';

class GroupReportPage extends StatefulWidget {
  final int groupId;  // 传入的 groupId 参数

  const GroupReportPage({super.key, required this.groupId});

  @override
  State<GroupReportPage> createState() => _GroupReportPageState();
}

class _GroupReportPageState extends State<GroupReportPage> {
  String? _selectedReason;  // 当前选中的举报原因
  final TextEditingController _additionalInfoController = TextEditingController();  // 额外信息输入框
  final List<String> _reasons = [  // 举报选项列表
    '色情低俗',
    '血腥暴力',
    '虚假宣传链接',
    '恶意欺诈',
    '内容令人不适',
    '其他',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Text('举报'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100), // 给底部按钮留出足够空间
        child: Container(
          margin: EdgeInsets.only(top: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 10),
                child: Text(
                  '请选择举报内容',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 16),

              // 举报选项列表
              ..._reasons.map((reason) {
                final isSelected = _selectedReason == reason;
                return RadioListTile<String>(
                  tileColor: Colors.white,
                  title: Text(reason),
                  shape: const Border(
                    bottom: BorderSide(
                      color: Color(0xFFE0E0E0),     // 淡灰色 #E0E0E0
                      width: 1.0,
                    ),
                  ),
                  value: reason,
                  groupValue: _selectedReason,
                  onChanged: (value) {
                    setState(() {
                      _selectedReason = value;
                    });
                  },
                  activeColor: Colors.green,  // 选中颜色匹配截图的绿色
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  dense: true,
                );
              }),

              const SizedBox(height: 24),

              // 额外信息输入框
              const Padding(
                padding: EdgeInsets.only(left: 16, top: 10),
                child: Text(
                  '提供更多信息有助于举报快速处理～',
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                ),
                child: TextField(
                  controller: _additionalInfoController,
                  maxLines: 3,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  decoration: const InputDecoration(
                    hintText: '请输入更多细节...',
                    border: InputBorder.none,
                    hintStyle: const TextStyle(      // ← 这里专门控制 hintText 的样式
                      fontSize: 14,                  // 提示文字大小（通常比输入文字小一点）
                      color: Colors.grey,            // 提示文字颜色（默认浅灰）
                    ),
                    contentPadding: EdgeInsets.all(12),
                  ),
                ),
              ),
              // const SizedBox(height: 16),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 8),
                decoration: const BoxDecoration(
                  color: Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '上传相关截图（选填，最多3张）',
                      style: TextStyle(fontSize: 14, color: Colors.grey),
                    ),
                    const SizedBox(height: 12),

                    // 这里是重点：直接使用 ImageUploadButton，不限制它的宽度
                    ImageUploadButton(
                      size: 100,
                      maxImages: 3,                    // 可改成你想要的最大张数
                      onImagesChanged: (images) {
                        // images 就是当前选中的所有图片列表
                        // 你可以保存到 state 里，例如：
                        // setState(() { _reportImages = images; });
                        print('当前已选图片数量: ${images.length}');
                      },
                    ),
                  ],
                ),
              ),

            ],
          ),
        ),
      ),


      // 底部提交按钮
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _selectedReason == null
              ? null  // 未选择时禁用按钮
              : () {
                  // TODO: 提交举报逻辑
                  // 例如：调用 API 发送 groupId, _selectedReason, _additionalInfoController.text
                  // print('举报: groupId=${widget.groupId}, reason=$_selectedReason, info=${_additionalInfoController.text}');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('举报已提交')),
                  );
                  Navigator.pop(context);  // 提交后返回
                },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,  // 匹配截图的绿色
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text(
            '提交',
            style: TextStyle(fontSize: 12, color: Colors.white),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _additionalInfoController.dispose();
    super.dispose();
  }
}