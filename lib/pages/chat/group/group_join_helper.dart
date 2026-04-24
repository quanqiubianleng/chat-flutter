import 'package:education/core/utils/conversation.dart';
import 'package:education/pages/chat/group/group_chat.dart';
import 'package:education/services/api_service.dart';
import 'package:education/services/group_service.dart';
import 'package:education/services/user_service.dart';
import 'package:flutter/material.dart';

/// 从资料页 / 搜索等入口统一处理入群逻辑（与 [SearchGroupPage] 行为对齐）
Future<void> runGroupJoinFlow(
  BuildContext context, {
  required int groupId,
  required int joinMode,
}) async {
  final api = GroupApi();
  final userApi = UserApi();

  Future<String?> loadWallet() async {
    try {
      final data = await userApi.getUserInfo();
      final w = (data['wallet_address'] ?? data['walletAddress'] ?? '').toString().trim();
      if (w.startsWith('0x') && w.length == 42) return w;
    } catch (_) {}
    return null;
  }

  int asInt(dynamic v, [int d = 0]) {
    if (v is int) return v;
    return int.tryParse(v?.toString() ?? '') ?? d;
  }

  String asString(dynamic v, [String d = '']) {
    final s = v?.toString() ?? '';
    return s.isEmpty ? d : s;
  }

  try {
    if (joinMode == 1) {
      final controller = TextEditingController();
      final reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('申请加入群组'),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: '请输入申请理由（可选）',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, controller.text.trim()),
              child: const Text('提交申请'),
            ),
          ],
        ),
      );
      if (reason == null || !context.mounted) return;
      final resp = await api.applyJoinGroup({'group_id': groupId, 'reason': reason});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(asString(resp['msg'], '申请已提交'))),
      );
      return;
    }

    if (joinMode == 2) {
      final wallet = await loadWallet();
      if (wallet == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('持仓校验需要钱包地址，请先在个人资料绑定钱包')),
          );
        }
        return;
      }
      final resp = await api.joinGroup({'group_id': groupId, 'wallet_address': wallet});
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(asString(resp['msg'], '已加入群组'))),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatPage(
            chatId: generateTempConversationId(userIdA: 0, userIdB: groupId, isGroup: true),
          ),
        ),
      );
      return;
    }

    if (joinMode == 3) {
      final codeCtrl = TextEditingController();
      final code = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('邀请制入群'),
          content: TextField(
            controller: codeCtrl,
            decoration: const InputDecoration(
              hintText: '请输入邀请码',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, codeCtrl.text.trim()),
              child: const Text('加入'),
            ),
          ],
        ),
      );
      if (code == null || code.isEmpty || !context.mounted) return;
      final wallet = await loadWallet();
      final resp = await api.joinGroup({
        'group_id': groupId,
        'invite_code': code,
        if (wallet != null) 'wallet_address': wallet,
      });
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(asString(resp['msg'], '已加入群组'))),
      );
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => GroupChatPage(
            chatId: generateTempConversationId(userIdA: 0, userIdB: groupId, isGroup: true),
          ),
        ),
      );
      return;
    }

    final resp = await api.joinGroup({'group_id': groupId});
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(asString(resp['msg'], '已加入群组'))),
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GroupChatPage(
          chatId: generateTempConversationId(userIdA: 0, userIdB: groupId, isGroup: true),
        ),
      ),
    );
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
