import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 谁可以私信我：任何人、我关注的人、我的朋友
class WhoCanPmPage extends StatefulWidget {
  const WhoCanPmPage({super.key});

  @override
  State<WhoCanPmPage> createState() => _WhoCanPmPageState();
}

class _WhoCanPmPageState extends State<WhoCanPmPage> {
  final UserApi _api = UserApi();
  static const options = [
    ('everyone', '任何人'),
    ('following', '我关注的人'),
    ('friends', '我的朋友'),
  ];
  String _value = 'everyone';
  bool _loading = true;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await _api.getPrivacySettings();
      if (mounted) {
        final v = data['can_pm']?.toString() ?? 'everyone';
        setState(() {
          _value = options.any((e) => e.$1 == v) ? v : 'everyone';
          _loading = false;
          _loadFailed = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadFailed = true;
        });
      }
    }
  }

  Future<void> _select(String value) async {
    if (_value == value) return;
    final previous = _value;
    setState(() => _value = value);
    try {
      await _api.updatePrivacySettings({'can_pm': value});
      if (mounted) Fluttertoast.showToast(msg: '已更新');
    } catch (e) {
      if (mounted) {
        setState(() => _value = previous);
        Fluttertoast.showToast(msg: '更新失败');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          '谁可以私信我',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadFailed
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('加载失败，请重试'),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('重试')),
                ],
              ),
            )
          : ListView(
              children: [
                for (final opt in options)
                  InkWell(
                    onTap: () => _select(opt.$1),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade200),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              opt.$2,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF252525),
                              ),
                            ),
                          ),
                          if (_value == opt.$1)
                            const Icon(
                              Icons.check,
                              color: Color(0xFF00D1A7),
                              size: 24,
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
