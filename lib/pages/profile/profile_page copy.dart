// 文件：lib/pages/profile_page.dart
import 'package:education/core/cache/user_cache.dart';
import 'package:education/services/user_service.dart';
import 'package:education/widgets/user/user.dart';
import 'package:flutter/material.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 当前登录用户
  User currentUser = User(
    username: "加载中...",
    walletAddress: "加载中...",
    avatarUrl: "https://bbt-bucket-public.oss-cn-hongkong.aliyuncs.com/avatar_s/1.png",
    level: "Lv.122",
    userId: 0,
    did: "",
    deviceNo: ""
  );

  // 账号列表（用于切换账号弹窗）
  List<Map<String, dynamic>> accountList = [];

  // 加载状态
  bool isLoading = true;

  // API
  final api = UserApi();

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
      final accountLists = await api.getAccountDevice({"deviceNo": userInfo['deviceNo']});

      print(accountLists);

      // 模拟多账号（真实场景（等你有接口再删掉这块）
      await Future.delayed(const Duration(milliseconds: 400));

      final List<Map<String, dynamic>> tempList = [
        {
          "username": userInfo['username'] ?? "匿名用户",
          "wallet_address": userInfo['wallet_address'] ?? "0x0000...0000",
          "avatar_url": userInfo['avatar_url'] ?? "",
          "hasNotification": false,
        },
        {
          "username": "备用账号",
          "wallet_address": "0x80875f3d8e6b2f481fD9",
          "avatar_url": "https://bbt-bucket-public.oss-cn-hongkong.aliyuncs.com/avatar_s/1.png",
          "hasNotification": true,
        },
        {
          "username": "测试账号3",
          "wallet_address": "0x9F1a2b3c4d5e6f789012",
          "avatar_url": "",
          "hasNotification": false,
        },
      ];

      if (!mounted) return;
      print("userInfo");
      print(userInfo);
      // await UserCache.saveToken(userInfo['token']);
      await UserCache.saveUserId(userInfo['userId']);
      await UserCache.saveDid(userInfo['did_id']);
      setState(() {
        currentUser = User.fromMap(userInfo);

        accountList = tempList.map((e) {
          e["isCurrent"] = e["wallet_address"] == currentUser.walletAddress;
          return e;
        }).toList();

        isLoading = false;
      });
    } catch (e) {
      print("加载用户信息失败1: $e");
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
      setState(() {
        currentUser = User.fromMap(account);

        accountList = accountList.map((e) {
          e["isCurrent"] = e["wallet_address"] == account["wallet_address"];
          return e;
        }).toList();
      });

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

    // 先解构 Map，避免 build 里直接访问 JS proxy
    final displayName =
        currentUser.username.isNotEmpty && currentUser.username != "null"
        ? currentUser.username
        : (currentUser.walletAddress.length > 10
              ? "User#${currentUser.walletAddress.substring(2, 8).toUpperCase()}"
              : "匿名用户1");

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
            icon: const Icon(Icons.qr_code_scanner, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.subtitles_outlined, color: Colors.black87),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.black87),
            onPressed: () {},
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: [
          // 个人信息卡片
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: currentUser.avatarUrl.isNotEmpty
                      ? Image.network(
                          currentUser.avatarUrl,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 60,
                            height: 60,
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.person,
                              size: 36,
                              color: Colors.white,
                            ),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.purple.shade100,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.person,
                            size: 36,
                            color: Colors.purple,
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(width: 8),
                          Chip(
                            backgroundColor: Color(0xFFE8F5E8),
                            padding: EdgeInsets.zero,
                            labelPadding: EdgeInsets.symmetric(horizontal: 6),
                            label: Text(
                              currentUser.level,
                              style: TextStyle(
                                color: Color(0xFF00C853),
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentUser.walletAddress.length > 10
                            ? "${currentUser.walletAddress.substring(0, 6)}...${currentUser.walletAddress.substring(currentUser.walletAddress.length - 4)}"
                            : currentUser.walletAddress,
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 绿色横幅
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF69F0AE), Color(0xFF00C853)],
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.celebration, color: Colors.white, size: 26),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    "成为BBT生态合伙人免费开通 Shares 返佣！",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    "去开通",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 资产模块
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    "资产",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85, // 改小一点，增加单元格高度
                  ),
                  itemCount: 4,
                  itemBuilder: (_, i) {
                    final list = [
                      {
                        "i": Icons.token,
                        "t": "Token",
                        "c": const Color(0xFF00C853),
                      },
                      {
                        "i": Icons.image,
                        "t": "NFT",
                        "c": const Color(0xFFFF8F00),
                      },
                      {
                        "i": Icons.card_giftcard,
                        "t": "vBOX",
                        "c": const Color(0xFF8E24AA),
                      },
                      {
                        "i": Icons.vpn_key,
                        "t": "Key",
                        "c": const Color(0xFF5C6BC0),
                      },
                    ];
                    final e = list[i];
                    return _buildAssetItem(
                      e["i"] as IconData,
                      e["t"] as String,
                      e["c"] as Color,
                    );
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // 实验室模块
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Text(
                    "实验室",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                GridView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 16,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: 5,
                  itemBuilder: (_, i) {
                    final list = [
                      {"i": Icons.explore, "t": "发现"},
                      {"i": Icons.wallet, "t": "口令红包"},
                      {"i": Icons.smart_toy, "t": "AI Bot"},
                      {"i": Icons.groups, "t": "社区"},
                      {"i": Icons.favorite_border, "t": "收藏"},
                    ];
                    final e = list[i];
                    return _buildLabItem(e["i"] as IconData, e["t"] as String);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Shares 等列表
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Column(
              children: [
                _buildListItem(Icons.monetization_on, "Shares"),
                const Divider(height: 1, indent: 56, endIndent: 20),
                _buildListItem(Icons.trending_up, "成长等级"),
                const Divider(height: 1, indent: 56, endIndent: 20),
                _buildListItem(Icons.emoji_events, "我的成就"),
              ],
            ),
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildAssetItem(IconData icon, String label, Color color) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, size: 28, color: color),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildLabItem(IconData icon, String label) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, size: 26, color: Colors.black87),
        ),
        const SizedBox(height: 4),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: Colors.black87),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(IconData icon, String title) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 15), // 调整左右间距
      leading: Icon(icon, color: Colors.black87, size: 26),
      title: Text(title, style: const TextStyle(fontSize: 16)),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () {},
    );
  }

  /// 一行代码调用，超干净版（推荐直接扔进你的工具类）
  /// 一、切换账号按钮（已优化，和你截图一模一样）
  Widget switchAccountButton({
    required BuildContext context,
    String text = '切换账号',
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () => AccountListSheet.show(
        context,
        accountList, // ← 传你的真实账号列表
        _switchAccount, // ← 传切换方法
      ),
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
    Future<void> Function(Map<String, dynamic>) onSwitchAccount,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AccountListContent(
        accounts: accounts,
        onSwitchAccount: onSwitchAccount,
      ),
    );
  }
}

/// 直接复制下面整个文件或片段即可使用
class _AccountListContent extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final Future<void> Function(Map<String, dynamic>) onSwitchAccount;

  const _AccountListContent({
    required this.accounts,
    required this.onSwitchAccount,
  });

  String formatAddress(String? address) {
    if (address == null || address.isEmpty || address.length < 12) {
      return address ?? "暂无地址";
    }
    return "${address.substring(0, 6)}...${address.substring(address.length - 4)}";
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
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage:
                          (acc["avatar_url"] as String?)?.isNotEmpty == true
                          ? NetworkImage(acc["avatar_url"])
                          : null,
                      backgroundColor: acc["isCurrent"] == true
                          ? Colors.purple.shade100
                          : Colors.pink.shade100,
                      child: (acc["avatar_url"] as String?)?.isEmpty ?? true
                          ? Icon(
                              Icons.person,
                              size: 28,
                              color: acc["isCurrent"]
                                  ? Colors.purple.shade700
                                  : Colors.pink.shade700,
                            )
                          : null,
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
                    subtitle: Text(
                      formatAddress(acc["wallet_address"]?.toString()),
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // if (acc["hasNotification"] == true)
                        //   Container(
                        //     width: 10,
                        //     height: 10,
                        //     decoration: const BoxDecoration(
                        //       color: Colors.red,
                        //       shape: BoxShape.circle,
                        //     ),
                        //   ),
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
                  onPressed: () => Navigator.pop(context),
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
