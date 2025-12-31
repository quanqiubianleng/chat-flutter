import 'package:education/pages/search/search_user.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class SearchType extends StatelessWidget {
  const SearchType({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F0F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF0F0F0),
        elevation: 0,
        title: Text("搜索", style: TextStyle(fontSize: 16),),
        // actions: [
        //   TextButton(
        //     onPressed: () => Navigator.pop,
        //     child: const Text('取消', style: TextStyle(color: Colors.black)),
        //   ),
        //   const SizedBox(width: 8),
        // ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(top: 12),
        children: [
          // 标题
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              '搜索指定内容',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),

          // 四个入口（横向均分）
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            
            child: Row(
              children: [
                _buildGridItem('用户', Icons.person_outline, context),
                _buildGridItem('群组', Icons.group, context),
                _buildGridItem('聊天记录', Icons.chat_bubble_outline, context),
                _buildGridItem('浏览器', Icons.language, context),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // 搜索历史
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(Icons.access_time, color: Colors.grey[600], size: 20),
                const SizedBox(width: 12),
                const Text(
                  '搜索历史',
                  style: TextStyle(fontSize: 16),
                ),
                const Spacer(),
                Text(
                  '清除',
                  style: TextStyle(color: Colors.green[600]),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildGridItem(String title, IconData icon, BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: () {
          if (title == "用户"){
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchUser()),
            );
          }
        },
        child: SizedBox(
          height: 50,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon(icon, color: Color(0xFF07C160), size: 28),
              // const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Color(0xFF07C160)),
              ),
            ],
          ),
        ),
      ),
    );
  }

}