import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'navigation/main_tab_scaffold.dart'; // 引入导航页

void main() {
  runApp(const DeBoxApp());
}

class DeBoxApp extends StatelessWidget {
  const DeBoxApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 浅色模式状态栏设置
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return MaterialApp(
      title: 'DeBox Clone',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFF00D29D), // DeBox 标志性绿色
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        
        // AppBar 全局样式
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          iconTheme: IconThemeData(color: Colors.black),
        ),
        
        // 底部导航栏全局样式
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF00D29D),
          unselectedItemColor: Color(0xFF999999),
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: TextStyle(fontSize: 0), 
          unselectedLabelStyle: TextStyle(fontSize: 0),
          elevation: 10,
        ),
        useMaterial3: true,
      ),
      home: const MainTabScaffold(),
    );
  }
}