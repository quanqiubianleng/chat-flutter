// 文件：lib/widgets/account/switch_account_button.dart

import 'package:flutter/material.dart';
import 'account_list_sheet.dart';

Widget switchAccountButton({
  required BuildContext context,
  required String text,
  required List<Map<String, dynamic>> accountList,
  required Future<void> Function(Map<String, dynamic>) onSwitchAccount,
}) {
  return InkWell(
    borderRadius: BorderRadius.circular(10),
    onTap: () => AccountListSheet.show(context, accountList, onSwitchAccount),
    child: Container(
      height: 36,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E5E7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.supervised_user_circle_outlined, size: 18, color: Color(0xFF8E8E93)),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text, style: const TextStyle(fontSize: 14, color: Color(0xFF1C1C1E)), overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 5),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 17, color: Color(0xFF8E8E93)),
        ],
      ),
    ),
  );
}