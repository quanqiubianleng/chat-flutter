import 'package:education/config/app_config.dart';
import 'package:education/pages/common/mini_program_webview_page.dart';
import 'package:education/pages/user/update_log_page.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:url_launcher/url_launcher.dart';

/// 关于我们页面：应用信息 + 更新日志 / 用户协议 / 评价我们 / 联系我们 / 官方网站
class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  static const String _appVersion = '1.0.0';

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
          '关于我们',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          const SizedBox(height: 32),
          _buildLogoSection(context),
          const SizedBox(height: 40),
          _buildListSection(context),
        ],
      ),
    );
  }

  Widget _buildLogoSection(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: const Color(0xFF00D1A7),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00D1A7).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.chat_bubble_outline_rounded,
            size: 40,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppConfig.title,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '当前版本: $_appVersion',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildListSection(BuildContext context) {
    final listItems = [
      _ListItem(title: '更新日志', onTap: () => _openUpdateLog(context)),
      _ListItem(title: '用户协议', onTap: () => _openUserAgreement(context)),
      _ListItem(title: '评价我们', onTap: _rateUs),
      _ListItem(title: '联系我们', onTap: () => _openContact(context)),
      _ListItem(title: '官方网站', onTap: () => _openOfficialWebsite(context)),
    ];

    return Container(
      color: Colors.white,
      child: Column(
        children: [
          for (int i = 0; i < listItems.length; i++) ...[
            _ListTileItem(
              title: listItems[i].title,
              onTap: listItems[i].onTap,
            ),
            if (i < listItems.length - 1)
              Divider(
                height: 1,
                indent: 16,
                endIndent: 16,
                color: Colors.grey[200],
              ),
          ],
        ],
      ),
    );
  }

  void _openUpdateLog(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const UpdateLogPage(),
      ),
    );
  }

  void _openUserAgreement(BuildContext context) {
    final url = AppConfig.agreeUrl;
    if (url.isEmpty) {
      _showToast('暂无用户协议链接');
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MiniProgramWebViewPage(
          initialUrl: url,
          title: '用户协议',
        ),
      ),
    );
  }

  Future<void> _rateUs() async {
    // 可根据平台打开应用商店评分页
    const storeUrl = 'https://apps.apple.com/app/idXXXXXXXX'; // 替换为实际 App Store / 应用宝链接
    final uri = Uri.tryParse(storeUrl);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _showToast('暂未配置应用商店链接');
    }
  }

  /// 联系我们：在应用内 WebView 加载联系页
  void _openContact(BuildContext context) {
    const url = 'http://47.83.189.255/contact.html';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MiniProgramWebViewPage(
          initialUrl: url,
          title: '联系我们',
        ),
      ),
    );
  }

  /// 官方网站：与新手引导相同，在应用内 WebView 中加载
  void _openOfficialWebsite(BuildContext context) {
    const url = 'http://47.83.189.255/intro.html';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MiniProgramWebViewPage(
          initialUrl: url,
          title: '官方网站',
        ),
      ),
    );
  }

  void _showToast(String msg) {
    Fluttertoast.showToast(msg: msg, toastLength: Toast.LENGTH_SHORT);
  }
}

class _ListItem {
  final String title;
  final VoidCallback onTap;
  _ListItem({required this.title, required this.onTap});
}

class _ListTileItem extends StatelessWidget {
  final String title;
  final VoidCallback onTap;

  const _ListTileItem({required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          color: Colors.black87,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: Colors.grey,
        size: 24,
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    );
  }
}
