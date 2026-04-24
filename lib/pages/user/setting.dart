import 'package:education/config/app_config.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/pages/profile/account_management_page.dart';
import 'package:education/services/api_service.dart';
import 'package:education/services/group_service.dart';
import 'package:education/pages/user/about_us_page.dart';
import 'package:education/pages/user/feedback_page.dart';
import 'package:education/pages/user/payment_security_page.dart';
import 'package:education/pages/user/privacy_page.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

/// 仅该用户可在设置里看到「初始化 BBT 官方群」
const int _kOfficialGroupInitVisibleUserId = 151;

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '设置',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: ListView(
        children: [
          // 第一组 - 账号相关
          const SizedBox(height: 24),
          _SettingsItem(
            icon: Icons.person_outline_rounded,
            title: '账号管理',
            trailing: const _RightArrow(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AccountManagementPage(),
                ),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          _SettingsItem(
            icon: Icons.security_rounded,
            title: '支付与安全',
            trailing: const _RightArrow(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PaymentSecurityPage(),
                ),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          _SettingsItem(
            icon: Icons.tune_rounded,
            title: '偏好设置',
            trailing: const _RightArrow(),
          ),

          const SizedBox(height: 24),

          // 第二组 - 隐私与反馈
          _SettingsItem(
            icon: Icons.privacy_tip_outlined,
            title: '隐私',
            trailing: const _RightArrow(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PrivacyPage()),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          _SettingsItem(
            icon: Icons.sentiment_dissatisfied_outlined,
            title: '问题反馈',
            trailing: const _RightArrow(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FeedbackPage(),
                ),
              );
            },
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          const _SettingsItem(
            icon: Icons.help_outline_rounded,
            title: '使用指南',
            trailing: _RightArrow(),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          _SettingsItem(
            icon: Icons.info_outline_rounded,
            title: '关于我们',
            trailing: const _RightArrow(),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AboutUsPage(),
                ),
              );
            },
          ),

          const SizedBox(height: 24),

          // 【调试】模拟 Token 过期，用于测试静默续登
          if (AppConfig.isDebug) ...[
            _SettingsItem(
              icon: Icons.bug_report_outlined,
              title: '【调试】模拟 Token 过期',
              trailing: const _RightArrow(),
              onTap: () async {
                await UserCache.clearTokenOnly();
                if (context.mounted) {
                  Navigator.pop(context);
                  Fluttertoast.showToast(
                    msg: '已清除 access token，请点击「切换账号」或做任意会请求接口的操作，观察是否静默续登',
                    toastLength: Toast.LENGTH_LONG,
                  );
                }
              },
            ),
            Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          ],

          // 运维：仅 userId=151 可见（调用 POST /v1/group/initOfficial）
          FutureBuilder<int?>(
            future: UserCache.getUserId(),
            builder: (context, snapshot) {
              if (snapshot.data != _kOfficialGroupInitVisibleUserId) {
                return const SizedBox.shrink();
              }
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _SettingsItem(
                    icon: Icons.group_rounded,
                    title: '初始化 BBT 官方群',
                    subtitle: '需已登录；网关需配置 OfficialGroupOwnerUserId',
                    trailing: const _RightArrow(),
                    onTap: () => _onInitOfficialGroupTap(context),
                  ),
                  Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
                ],
              );
            },
          ),

          // 清除缓存（独立一项）
          const _SettingsItem(
            icon: Icons.delete_sweep_outlined,
            title: '清除缓存',
            trailing: _CacheTrailing(size: '56.7 MB'),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

Future<void> _onInitOfficialGroupTap(BuildContext context) async {
  final uid = await UserCache.getUserId();
  if (uid != _kOfficialGroupInitVisibleUserId) {
    Fluttertoast.showToast(msg: '无权限执行此操作');
    return;
  }

  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('初始化 BBT 官方群'),
      content: const Text(
        '将请求网关接口 POST /v1/group/initOfficial。\n\n'
        '请确认网关 yaml 已配置 OfficialGroupOwnerUserId，且 OfficialGroupId 为 0（未创建过）。\n\n'
        '成功后请把返回的 group_id 写入网关 OfficialGroupId 并重启网关。',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('确定')),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final map = await GroupApi().initOfficialGroup();
    if (context.mounted) Navigator.of(context).pop();

    final code = map['code'];
    final msg = map['msg']?.toString() ?? '';
    final groupId = map['group_id'];
    final convId = map['conversation_id']?.toString() ?? '';
    final exists = map['already_exists'] == true;

    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(code == 200 ? '成功' : '提示'),
        content: SingleChildScrollView(
          child: Text(
            '$msg\n\n'
            '${groupId != null ? 'group_id: $groupId\n' : ''}'
            '${convId.isNotEmpty ? 'conversation_id: $convId\n' : ''}'
            '${exists ? '\n（已配置过官方群，未重复创建）' : ''}',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('知道了')),
        ],
      ),
    );
  } on ApiException catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) {
      Fluttertoast.showToast(msg: e.message, toastLength: Toast.LENGTH_LONG);
    }
  } catch (e) {
    if (context.mounted) Navigator.of(context).pop();
    if (context.mounted) {
      Fluttertoast.showToast(msg: '请求失败: $e', toastLength: Toast.LENGTH_LONG);
    }
  }
}

/// 组标题（虽然截图里没有很明显的标题，但为了分组可读性保留）
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color.fromARGB(137, 24, 23, 23),
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// 普通设置项
class _SettingsItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget trailing;
  final VoidCallback? onTap;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.trailing,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(
          icon,
          color: const Color.fromARGB(179, 29, 28, 28),
          size: 26,
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: Color.fromARGB(255, 37, 37, 37),
            fontSize: 16,
          ),
        ),
        subtitle: subtitle == null || subtitle!.isEmpty
            ? null
            : Text(
                subtitle!,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
              ),
        trailing: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: onTap,
      ),
    );
  }
}

/// 右箭头
class _RightArrow extends StatelessWidget {
  const _RightArrow();

  @override
  Widget build(BuildContext context) {
    return const Icon(
      Icons.chevron_right_rounded,
      color: Color.fromARGB(97, 43, 42, 42),
      size: 24,
    );
  }
}

/// 带缓存大小的 trailing
class _CacheTrailing extends StatelessWidget {
  final String size;

  const _CacheTrailing({required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          size,
          style: const TextStyle(
            color: Color.fromARGB(137, 37, 36, 36),
            fontSize: 14,
          ),
        ),
        const Icon(
          Icons.chevron_right_rounded,
          color: Color.fromARGB(97, 48, 46, 46),
          size: 24,
        ),
      ],
    );
  }
}