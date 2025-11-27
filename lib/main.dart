import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'core/cache/user_cache.dart';
import 'navigation/main_tab_scaffold.dart'; // 引入导航页
import 'services/api_service.dart';
import 'services/user_service.dart';

void main() {
  // 关键：这一行要最先执行！
  WidgetsFlutterBinding.ensureInitialized();

  // 彻底关闭所有调试视觉提示（红字、黄黑条、彩虹边框全都没了）
  debugPaintSizeEnabled = false;           // 关闭 overflow 红字
  debugRepaintRainbowEnabled = false;      // 关闭彩虹重绘边框
  debugPaintBaselinesEnabled = false;      // 关闭文本基线
  debugPaintLayerBordersEnabled = false;   // 关闭层边界
  //debugPaintPointersEnabled = false;       // 关闭点击指针

  runApp(const DeBoxApp());
  httpsf();
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


void httpsf() async {
  // 初始化 ApiClient，传入 baseUrl（可以为空或者接口前缀）
  final api = UserApi();

  try {
    // POST 请求示例
    final postResponse = await api.importWallet({
      "did_id": "21342",
      "password": "dfsgfsd",
      "mnemonic": "waste source draw buddy kitchen super stage trumpet three tongue assume ring",
      "deviceNo": "gfdgfdhgfdh",
    });

    print("POST Response: ${postResponse}");
    await UserCache.saveToken(postResponse['token']);
    print(jsonEncode(postResponse));

    // GET 请求示例
    final getResponse = await api.getUserInfo();

    print("GET Response: ${getResponse}");
  } on DioError catch (e) {
    print("请求出错: ${e.error}");
    if (e.response != null) {
      print("响应数据: ${e.response?.data}");
    }
  }
}