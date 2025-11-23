import 'package:flutter/material.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('朋友 (1)'),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              children: [
                Icon(Icons.search, color: Colors.grey, size: 20),
                SizedBox(width: 8),
                Text('1个朋友', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
          _buildMenuItem(Icons.person_add_alt_1, '新增关注', Colors.orange),
          _buildMenuItem(Icons.person_outline, '关注 (9)', const Color(0xFF00D29D)),
          
          Container(
            width: double.infinity,
            color: const Color(0xFFF9F9F9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: const Text('#', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.pink[100],
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            title: const Text('04704323', style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const Text('0xee...323', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color color) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
      title: Text(title),
      trailing: const SizedBox(width: 16),
      dense: true,
    );
  }
}