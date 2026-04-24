// 文件：lib/pages/profile_page.dart
import 'package:education/core/cache/user_cache.dart';
import 'package:education/core/global.dart';
import 'package:education/services/user_service.dart';
import 'package:education/pages/profile/my_info_page.dart';
import 'package:education/pages/profile/set_password_page.dart';
import 'package:education/config/app_config.dart';
import 'package:education/pages/common/mini_program_webview_page.dart';
import 'package:education/pages/profile/bbt_center_page.dart';
import 'package:education/pages/profile/share_page.dart';
import 'package:education/widgets/account/create_wallet_sheet.dart';
import 'package:education/widgets/account/import_account_sheet.dart';
import 'package:education/widgets/asset/asset_grid.dart';
import 'package:education/widgets/asset/lab_grid.dart';
import 'package:education/widgets/common/gradient_banner.dart';
import 'package:education/widgets/common/settings_section.dart';
import 'package:education/widgets/profile/profile_header_card.dart';
import 'package:education/widgets/user/user.dart';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../../core/utils/logger.dart';
import '../../modules/chat/models/offline_message.dart';
import '../../providers/feed_refresh_provider.dart';
import '../../providers/user_provider.dart';
import '../user/setting.dart';
import '../user/user_info.dart';
import 'qr_scan_page.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  // 当前登录用户
  User currentUser = User(
    username: "未登录",
    walletAddress: "未登录",
    avatarUrl:
        "https://bbt-bucket-public.oss-cn-hongkong.aliyuncs.com/avatar_s/1.png",
    level: "Lv.122",
    userId: 0,
    did: "",
    deviceNo: "",
  );

  // 账号列表（用于切换账号弹窗）
  List<Map<String, dynamic>> accountList = [];

  // 加载状态
  bool isLoading = true;

  // API
  final api = UserApi();
  final userIdProvider = StateProvider<int?>((ref) => null);

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// 加载用户信息 + 模拟多账号列表
  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final userInfo = await api.getUserInfo();

      final info = User.fromMap(userInfo);
      AppLogger.d("用户信息：${info} ");
      AppLogger.d("设备号：（${info.deviceNo} ）");
      final accountLists = await api.getAccountDevice({
        "deviceNo": info.deviceNo,
      });
      // 模拟多账号（真实场景（等你有接口再删掉这块）
      await Future.delayed(const Duration(milliseconds: 400));

      final List<dynamic> rawList = accountLists['data'] ?? [];

      // 4. 转成你前端需要的格式，并标记哪个是当前账号
      final List<Map<String, dynamic>> accountList = rawList.map((item) {
        final map = item as Map<String, dynamic>;

        final wallet = map['wallet_address'] ?? '';
        final username = map['username'] ?? "匿名用户";
        final avatar = map['avatar_url'] ?? '';

        return {
          "username": username,
          "wallet_address": wallet,
          "avatar_url": avatar,
          "hasNotification": false, // 后端目前没返回这个字段，先写死
          "did_id": map['did_id'] ?? "",
          // 标记是否是当前登录的账号
          "isCurrent": wallet == info.walletAddress,
        };
      }).toList();

      // 如果接口一个都没返回，至少把自己加进去（防止空列表 UI 崩溃）
      if (accountList.isEmpty) {
        accountList.add({
          "username": info.username,
          "wallet_address": info.walletAddress,
          "avatar_url": info.avatarUrl,
          "hasNotification": false,
          "did_id": info.did,
          "isCurrent": true,
        });
      }

      if (!mounted) return;

      await UserCache.saveToken(userInfo['token']);
      final rt = userInfo['refresh_token']?.toString();
      if (rt != null && rt.isNotEmpty) await UserCache.saveRefreshToken(rt);
      await UserCache.saveUserId(userInfo['userId']);
      await UserCache.saveDid(userInfo['did_id']);
      await UserCache.saveAvatar(userInfo['avatar_url']);
      setState(() {
        currentUser = User.fromMap(userInfo);
        this.accountList = accountList;
        isLoading = false;
      });
      ref.refresh(userProvider);
    } catch (e) {
      AppLogger.d("加载用户信息失败1: $e");
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("加载失败，下拉重试")));
      }
    }
  }

  /// 切换账号
  Future<void> _switchAccount(Map<String, dynamic> account) async {
    try {
      final changeUser = await api.changeAccount({"did": account['did_id']});
      await UserCache.saveToken(changeUser['token']);
      final crt = changeUser['refresh_token']?.toString();
      if (crt != null && crt.isNotEmpty) await UserCache.saveRefreshToken(crt);
      await UserCache.saveUserId(changeUser['userId']);
      await UserCache.saveDid(changeUser['did_id']);
      await UserCache.saveAvatar(changeUser['avatar_url']);
      await UserCache.saveNickname(changeUser['username']);

      ref.refresh(userProvider);
      ref.refresh(myAvatarProvider);
      ref.refresh(myNicknameProvider);
      ref.read(feedRefreshTriggerProvider.notifier).state++; // 切换用户时刷新动态列表

      setState(() {
        currentUser = User.fromMap(account);

        accountList = accountList.map((e) {
          e["isCurrent"] = e["wallet_address"] == account["wallet_address"];
          return e;
        }).toList();
      });

      // ws切换账号
      ws.switchAccount();

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已切换到 ${account["username"] ?? "新账号"}')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('切换失败')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayName =
        currentUser.username.isNotEmpty && currentUser.username != "null"
        ? currentUser.username
        : (currentUser.walletAddress.length > 10
              ? "User#${currentUser.walletAddress.substring(2, 8).toUpperCase()}"
              : "匿名用户");

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F8FA),
        surfaceTintColor: Colors.transparent, // 避免Material3折射影响
        shadowColor: Colors.transparent, // 避免阴影
        elevation: 0,
        automaticallyImplyLeading: false, // 关键：关闭默认 leading
        //leading: switchAccountButton(context: context),
        title: Padding(
          padding: const EdgeInsets.only(left: 1),
          child: switchAccountButton(
            context: context,
            text: displayName, // ← 加上这句！动态显示用户名
          ),
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.document_scanner_outlined,
              color: Colors.black87,
            ),
            visualDensity: const VisualDensity(
              horizontal: -2,
              vertical: -4,
            ), // ← 关键：压缩密度
            padding: EdgeInsets.zero, // 去除按钮内边距
            constraints: const BoxConstraints(), // 去除最小48dp限制
            onPressed: _openScanAndJump,
          ),
          IconButton(
            icon: const Icon(Icons.qr_code_2_outlined, color: Colors.black87),
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SharePage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            visualDensity: const VisualDensity(
              horizontal: -0,
              vertical: -4,
            ), // ← 关键：压缩密度
            padding: EdgeInsets.zero, // 去除按钮内边距
            constraints: const BoxConstraints(), // 去除最小48dp限制
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          ProfileHeaderCard(
            user: currentUser,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => MyInfoPage(initialUser: currentUser),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // 绿色横幅
          GradientBanner(
            text: "成为BBT生态合伙人", // 必传，主文案
            buttonText: "去开通", // 可选，默认就是“去开通”
            onTap: () {
              // TODO: 跳转开通页面
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text("跳转开通奖励中心返佣")));
            },
          ),
          const SizedBox(height: 20),

          // 资产模块（Token/NFT 使用 Alchemy，需传入钱包地址）
          AssetGrid(walletAddress: currentUser.walletAddress),
          const SizedBox(height: 20),

          // 实验室模块
          LabGrid(walletAddress: currentUser.walletAddress),
          const SizedBox(height: 20),

          // 奖励中心等列表
          SettingsSection(
            items: [
              (
                icon: Icons.monetization_on,
                title: "奖励中心",
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => BbtCenterPage(
                        walletAddress: currentUser.walletAddress,
                      ),
                    ),
                  );
                },
              ),
              (icon: Icons.trending_up, title: "成长等级", onTap: () {}),
              (icon: Icons.emoji_events, title: "我的成就", onTap: () {}),
              (
                icon: Icons.lightbulb_outline,
                title: "新手引导",
                onTap: () {
                  final url = AppConfig.newbieGuideUrl;
                  if (url.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('暂未配置新手引导地址，请在全局配置中设置 NEWBIE_GUIDE_URL'),
                      ),
                    );
                    return;
                  }
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MiniProgramWebViewPage(
                        initialUrl: url,
                        title: '新手引导',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _openScanAndJump() async { 
    final scanned = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const QrScanPage()));
    if (!mounted || scanned == null || scanned.trim().isEmpty) return;
    final userId = _parseUserIdFromQr(scanned.trim());
    if (userId == null || userId <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('未识别到用户二维码')));
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => UserInfo(userId: userId)),
    );
  }

  int? _parseUserIdFromQr(String raw) {
    final lower = raw.toLowerCase();
    if (RegExp(r'^\d+$').hasMatch(raw)) {
      return int.tryParse(raw);
    }

    final jsonUserId = _tryParseUserIdFromJson(raw);
    if (jsonUserId != null) return jsonUserId;

    final uriUserId = _tryParseUserIdFromUri(raw);
    if (uriUserId != null) return uriUserId;

    final directPatterns = [
      RegExp(r'user[_-]?id[:=](\d+)', caseSensitive: false),
      RegExp(r'uid[:=](\d+)', caseSensitive: false),
      RegExp(r'target[_-]?user[_-]?id[:=](\d+)', caseSensitive: false),
      RegExp(r'bbt://user/(\d+)', caseSensitive: false),
      RegExp(r'user/(\d+)', caseSensitive: false),
    ];
    for (final reg in directPatterns) {
      final match = reg.firstMatch(lower);
      if (match != null) {
        final value = int.tryParse(match.group(1) ?? '');
        if (value != null && value > 0) return value;
      }
    }
    return null;
  }

  int? _tryParseUserIdFromJson(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final keys = ['userId', 'user_id', 'uid', 'target_user_id'];
        for (final key in keys) {
          final value = decoded[key];
          final uid = int.tryParse('${value ?? ''}');
          if (uid != null && uid > 0) return uid;
        }
      }
    } catch (_) {}
    return null;
  }

  int? _tryParseUserIdFromUri(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;

    const keys = ['userId', 'user_id', 'uid', 'target_user_id'];
    for (final key in keys) {
      final uid = int.tryParse(uri.queryParameters[key] ?? '');
      if (uid != null && uid > 0) return uid;
    }

    for (var i = uri.pathSegments.length - 1; i >= 0; i--) {
      final uid = int.tryParse(uri.pathSegments[i]);
      if (uid != null && uid > 0) return uid;
    }
    return null;
  }

  /// 切换账号按钮。未登录时点击直接进入设置密码页，设置完后返回并弹出创建钱包弹窗。
  Widget switchAccountButton({
    required BuildContext context,
    String text = '切换账号',
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () async {
        if (accountList.isEmpty) {
          // 未登录：直接进入设置密码页
          final password = await Navigator.push<String>(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const SetPasswordPage(mode: SetPasswordMode.create),
            ),
          );
          if (password != null && context.mounted) {
            CreateWalletSheet.show(
              context,
              password: password,
              onSuccess: () => _loadUserData(),
            );
          }
        } else {
          // 已登录：弹出账号列表
          AccountListSheet.show(
            context,
            accountList,
            _switchAccount,
            onImportSuccess: () {
              _loadUserData();
              ref
                  .read(feedRefreshTriggerProvider.notifier)
                  .state++; // 导入新账号后刷新动态列表
            },
          );
        }
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 10), // 左右稍小一点
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFE5E5E7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.supervised_user_circle_outlined,
              size: 18,
              color: Color(0xFF8E8E93),
            ),
            const SizedBox(width: 5),
            // 关键：用 Flexible + FittedBox 让文字自动缩放/截断，永不溢出！
            Flexible(
              child: Text(
                text,
                style: const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E)),
                overflow: TextOverflow.ellipsis, // 超长显示...
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 5),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 17,
              color: Color(0xFF8E8E93),
            ),
          ],
        ),
      ),
    );
  }
}

class AccountListSheet {
  static void show(
    BuildContext context,
    List<Map<String, dynamic>> accounts,
    Future<void> Function(Map<String, dynamic>) onSwitchAccount, {
    VoidCallback? onImportSuccess, // 新增：导入成功后的回调
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountListContent(
        accounts: accounts,
        onSwitchAccount: onSwitchAccount,
        onImportSuccess: onImportSuccess, // 传进去
      ),
    );
  }
}

/// 直接复制下面整个文件或片段即可使用
class _AccountListContent extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final Future<void> Function(Map<String, dynamic>) onSwitchAccount;
  final VoidCallback? onImportSuccess; // 新增

  const _AccountListContent({
    required this.accounts,
    required this.onSwitchAccount,
    this.onImportSuccess, // 新增
  });

  String formatAddress(String? address) {
    if (address == null || address.isEmpty || address.length < 12) {
      return address ?? "暂无地址";
    }
    return "${address.substring(0, 6)}...${address.substring(address.length - 6)}";
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        '账号',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, size: 26),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: accounts.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 80),
                itemBuilder: (_, i) {
                  final acc = accounts[i];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8), // 小圆角，可调整
                      child: Container(
                        width: 48, // 正方形边长
                        height: 48,
                        color: acc["isCurrent"] == true
                            ? Colors.purple.shade100
                            : Colors.pink.shade100,
                        child:
                            (acc["avatar_url"] as String?)?.isNotEmpty == true
                            ? Image.network(
                                acc["avatar_url"],
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Icon(
                                  Icons.person,
                                  size: 28,
                                  color: acc["isCurrent"] == true
                                      ? Colors.purple.shade700
                                      : Colors.pink.shade700,
                                ),
                              )
                            : Icon(
                                Icons.person,
                                size: 28,
                                color: acc["isCurrent"] == true
                                    ? Colors.purple.shade700
                                    : Colors.pink.shade700,
                              ),
                      ),
                    ),
                    title: Text(
                      acc["username"]?.toString().isNotEmpty == true
                          ? acc["username"]
                          : "User#${(acc["wallet_address"]?.toString() ?? "").substring(2, 8).toUpperCase()}",
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Text(
                          formatAddress(acc["wallet_address"]?.toString()),
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 13,
                          ),
                        ),

                        const SizedBox(width: 10),
                        // 复制按钮
                        InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () async {
                            await Clipboard.setData(
                              ClipboardData(text: acc["wallet_address"]),
                            );
                            Fluttertoast.showToast(
                              msg: "已复制钱包地址",
                              toastLength: Toast.LENGTH_SHORT,
                              gravity: ToastGravity.BOTTOM,
                              backgroundColor: Colors.black87,
                              textColor: Colors.white,
                              fontSize: 15,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(4), // 内边距
                            child: const Icon(
                              Icons.copy,
                              size: 16, // 更小的图标
                              color: Color(0xFF999999),
                            ),
                          ),
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (acc["isCurrent"] == true) ...[
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.check,
                            color: Colors.green,
                            size: 22,
                          ),
                        ],
                      ],
                    ),
                    onTap: () => onSwitchAccount(acc),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context); // 先关掉账号列表
                    ImportAccountSheet.show(
                      context,
                      onImportSuccess: onImportSuccess, // 直接传给导入页！
                    ); // 再打开导入/创建弹窗
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D1A7),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add, size: 22),
                      SizedBox(width: 6),
                      Text(
                        '添加',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
