import 'package:flutter/material.dart';

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

class _AccountListContent extends StatelessWidget {
  final List<Map<String, dynamic>> accounts;
  final Future<void> Function(Map<String, dynamic>) onSwitchAccount;

  const _AccountListContent({required this.accounts, required this.onSwitchAccount});

  String _formatAddress(String? address) {
    if (address == null || address.isEmpty || address.length < 12) return "暂无地址";
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
                  Container(width: 36, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(3))),
                  const Expanded(child: Center(child: Text('账号', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)))),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 26)),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView.separated(
                controller: controller,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: accounts.length,
                separatorBuilder: (_, __) => const Divider(height: 1, indent: 80),
                itemBuilder: (_, i) {
                  final acc = accounts[i];
                  final String? avatar = acc["avatar_url"];
                  final bool isCurrent = acc["isCurrent"] == true;

                  return ListTile(
                    leading: CircleAvatar(
                      radius: 24,
                      backgroundImage: avatar?.isNotEmpty == true ? NetworkImage(avatar!) : null,
                      backgroundColor: isCurrent ? Colors.purple.shade100 : Colors.pink.shade100,
                      child: avatar?.isEmpty ?? true
                          ? Icon(Icons.person, size: 28, color: isCurrent ? Colors.purple.shade700 : Colors.pink.shade700)
                          : null,
                    ),
                    title: Text(
                      acc["username"]?.toString().isNotEmpty == true
                          ? acc["username"]
                          : "User#${(acc["wallet_address"]?.toString() ?? "").length > 8 ? (acc["wallet_address"].substring(2, 8).toUpperCase()) : "0000"}",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    ),
                    subtitle: Text(_formatAddress(acc["wallet_address"]?.toString()), style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    trailing: isCurrent
                        ? const Icon(Icons.check, color: Colors.green, size: 22)
                        : null,
                    onTap: () => onSwitchAccount(acc),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 16),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.add, size: 22),
                  label: const Text('添加', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00D1A7), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}