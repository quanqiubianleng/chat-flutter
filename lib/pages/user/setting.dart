import 'package:flutter/material.dart';

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
            trailing: _RightArrow(),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          _SettingsItem(
            icon: Icons.security_rounded,
            title: '支付与安全',
            trailing: _RightArrow(),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          _SettingsItem(
            icon: Icons.tune_rounded,
            title: '偏好设置',
            trailing: _RightArrow(),
          ),

          const SizedBox(height: 24),

          // 第二组 - 隐私与反馈
          const _SettingsItem(
            icon: Icons.privacy_tip_outlined,
            title: '隐私',
            trailing: _RightArrow(),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          const _SettingsItem(
            icon: Icons.sentiment_dissatisfied_outlined,
            title: '问题反馈',
            trailing: _RightArrow(),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          const _SettingsItem(
            icon: Icons.help_outline_rounded,
            title: '使用指南',
            trailing: _RightArrow(),
          ),
          Divider(height: 1, color: Colors.grey[200], indent: 16, endIndent: 16),
          const _SettingsItem(
            icon: Icons.info_outline_rounded,
            title: '关于我们',
            trailing: _RightArrow(),
          ),

          const SizedBox(height: 24),

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
  final Widget trailing;

  const _SettingsItem({
    required this.icon,
    required this.title,
    required this.trailing,
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
        trailing: trailing,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        onTap: () {
          // 这里可以添加导航逻辑
        },
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