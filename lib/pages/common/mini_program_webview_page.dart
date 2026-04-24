import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// 统一的小程序风格网页加载页，支持：
/// 刷新、复制链接、浏览器打开、分享、清除缓存
class MiniProgramWebViewPage extends StatefulWidget {
  /// 初始加载的 URL
  final String initialUrl;
  /// 标题（可选，默认取网页 title 或 URL）
  final String? title;

  const MiniProgramWebViewPage({
    super.key,
    required this.initialUrl,
    this.title,
  });

  @override
  State<MiniProgramWebViewPage> createState() => _MiniProgramWebViewPageState();
}

class _MiniProgramWebViewPageState extends State<MiniProgramWebViewPage> {
  late final InAppWebViewController _webViewController;
  String _currentUrl = '';
  String _currentTitle = '';
  bool _isLoading = true;

  String get _displayTitle =>
      widget.title ?? (_currentTitle.isNotEmpty ? _currentTitle : _currentUrl);

  Future<void> _refresh() async {
    await _webViewController.reload();
    _toast('已刷新');
  }

  Future<void> _copyLink() async {
    final url = _currentUrl.isNotEmpty ? _currentUrl : widget.initialUrl;
    await Clipboard.setData(ClipboardData(text: url));
    _toast('链接已复制');
  }

  Future<void> _openInBrowser() async {
    final url = _currentUrl.isNotEmpty ? _currentUrl : widget.initialUrl;
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _toast('链接无效');
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      _toast('无法打开浏览器');
    }
  }

  Future<void> _sharePage() async {
    final url = _currentUrl.isNotEmpty ? _currentUrl : widget.initialUrl;
    try {
      await Share.share(url, subject: _displayTitle);
    } catch (e) {
      _toast('分享失败');
    }
  }

  Future<void> _clearCache() async {
    await WebStorageManager.instance().deleteAllData();
    await CookieManager.instance().deleteAllCookies();
    _toast('缓存已清除');
    await _webViewController.reload();
  }

  void _toast(String msg) {
    Fluttertoast.showToast(
      msg: msg,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  /// 右上角三点点击：弹出底部操作弹窗
  void _showActionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MiniProgramActionsSheet(
        title: _displayTitle,
        onRefresh: _refresh,
        onCopyLink: _copyLink,
        onOpenInBrowser: _openInBrowser,
        onShare: _sharePage,
        onClearCache: _clearCache,
        onUnfavorite: () => _toast('已取消收藏'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _displayTitle,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () => Navigator.maybePop(context),
        ),
        actions: [
          // 两个图标放在一个有边框圆角的长方形里，中间竖线隔开，无图标背景色
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE0E0E0)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: IntrinsicHeight(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _showActionsBottomSheet,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            child: const Icon(Icons.more_horiz, size: 22, color: Colors.black87),
                          ),
                        ),
                      ),
                      Container(
                        width: 1,
                        height: 20,
                        color: const Color(0xFFE0E0E0),
                      ),
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.maybePop(context),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                            child: const Icon(Icons.close, size: 20, color: Colors.black87),
                          ),
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
      body: Stack(
        children: [
          InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri(widget.initialUrl)),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              cacheEnabled: true,
              useHybridComposition: true,
            ),
            onWebViewCreated: (controller) {
              _webViewController = controller;
              _currentUrl = widget.initialUrl;
            },
            onLoadStart: (controller, url) {
              setState(() {
                _isLoading = true;
                if (url != null) _currentUrl = url.toString();
              });
            },
            onLoadStop: (controller, url) async {
              final title = await controller.getTitle();
              setState(() {
                _isLoading = false;
                if (url != null) _currentUrl = url.toString();
                _currentTitle = title ?? '';
              });
            },
            onReceivedError: (controller, request, error) {
              setState(() => _isLoading = false);
            },
          ),
          if (_isLoading)
            const Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0,
              child: Center(
                child: CircularProgressIndicator(color: Color(0xFF00D29D)),
              ),
            ),
        ],
      ),
    );
  }
}

/// 小程序更多操作底部弹窗：标题 + 一行四个图标（正方形圆角浅色底）+ 第二行两个 + 取消按钮
class _MiniProgramActionsSheet extends StatelessWidget {
  final String title;
  final VoidCallback onRefresh;
  final VoidCallback onCopyLink;
  final VoidCallback onOpenInBrowser;
  final VoidCallback onShare;
  final VoidCallback onClearCache;
  final VoidCallback onUnfavorite;

  const _MiniProgramActionsSheet({
    required this.title,
    required this.onRefresh,
    required this.onCopyLink,
    required this.onOpenInBrowser,
    required this.onShare,
    required this.onClearCache,
    required this.onUnfavorite,
  });

  static const Color _iconBg = Color(0xFFF2F2F7);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00D29D).withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.language, color: Color(0xFF00D29D), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // 第一行：四个图标，每个带正方形圆角浅色背景
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionItem(icon: Icons.refresh, label: '刷新', onTap: () => _closeAnd(context, onRefresh), bgColor: _iconBg),
                  ),
                  Expanded(
                    child: _ActionItem(icon: Icons.link, label: '复制链接', onTap: () => _closeAnd(context, onCopyLink), bgColor: _iconBg),
                  ),
                  Expanded(
                    child: _ActionItem(icon: Icons.open_in_browser, label: '浏览器打开', onTap: () => _closeAnd(context, onOpenInBrowser), bgColor: _iconBg),
                  ),
                  Expanded(
                    child: _ActionItem(icon: Icons.share, label: '分享', onTap: () => _closeAnd(context, onShare), bgColor: _iconBg),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // 第二行：两个图标（与第一行同一 4 列网格，仅前两格有内容）
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionItem(icon: Icons.delete_sweep, label: '清除缓存', onTap: () => _closeAnd(context, onClearCache), bgColor: _iconBg),
                  ),
                  Expanded(
                    child: _ActionItem(icon: Icons.star_border, label: '取消收藏', onTap: () => _closeAnd(context, onUnfavorite), bgColor: _iconBg),
                  ),
                  const Expanded(child: SizedBox()),
                  const Expanded(child: SizedBox()),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.black54,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('取消'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _closeAnd(BuildContext context, VoidCallback action) {
    Navigator.pop(context);
    action();
  }
}

/// 每个图标：正方形圆角浅色背景 + 图标 + 文案
class _ActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color bgColor;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.bgColor,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: Colors.black87),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
