import 'package:flutter/material.dart';

class ContactsPage extends StatelessWidget {
  const ContactsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('朋友 (1)')),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(
              top: 2,
              left: 16,
              right: 16,
              bottom: 16,
            ),
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
          _buildMenuItem(
            Icons.person_outline,
            '关注 (9)',
            const Color(0xFF00D29D),
          ),

          Container(
            width: double.infinity,
            color: const Color(0xFFF9F9F9),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: const Text(
              '#',
              style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
            ),
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
            title: const Text(
              '04704323',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: const Text(
              '0xee...323',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(IconData icon, String title, Color color) {
  return Column( // Use Column to stack ListTile and the separator line
    mainAxisSize: MainAxisSize.min,
    children: [
      ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
        // Remove the Column and the line from the title widget
        title: Text(title), 
        // Remove the SizedBox that was acting as the trailing widget
        trailing: null, 
        dense: true,
        visualDensity: const VisualDensity(vertical: 0),
      ),
      // Separator line placed outside the ListTile
      Padding(
        // Set the padding on the left to align with the text, 
        // and remove padding on the right to reach the edge.
        padding: const EdgeInsets.only(left: 72, right: 20), 
        child: Container(
          width: double.infinity,
          height: 1,
          color: Colors.grey[200],
        ),
      ),
    ],
  );
}


}
