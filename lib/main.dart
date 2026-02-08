import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:education/config/app_config.dart';
import 'package:education/core/global.dart';
import 'package:education/core/sqlite/database_helper.dart';
import 'package:education/providers/user_provider.dart';
import 'package:education/widgets/user/user.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:education/core/cache/user_cache.dart';
import 'package:education/navigation/main_tab_scaffold.dart';
import 'package:education/services/api_service.dart';
import 'package:education/services/user_service.dart';
import 'package:education/core/utils/logger.dart';
import 'package:sqlite3_flutter_libs/sqlite3_flutter_libs.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 彻底关闭所有调试视觉提示
  debugPaintSizeEnabled = false;
  debugRepaintRainbowEnabled = false;
  debugPaintBaselinesEnabled = false;
  debugPaintLayerBordersEnabled = false;

  // 初始化连接地址
  await AppConfig.init();

  // 给 Android 强行换上带 FTS5、Porter Stemmer、JSON1 等全功能的 sqlite3
  if (Platform.isAndroid) {
    await applyWorkaroundToOpenSqlite3OnOldAndroidVersions();
  }
  databaseFactory = databaseFactoryFfi;

  // 初始化数据库
  final db = await DatabaseHelper.instance.database;
  Global.db = db;

  // ws链接
  await initGlobalServices();

  runApp(
    ProviderScope(
      child: const DeBoxApp(),
    ),
  );


}

class DeBoxApp extends ConsumerStatefulWidget {
  const DeBoxApp({super.key});

  @override
  ConsumerState<DeBoxApp> createState() => _DeBoxAppState();
}

class _DeBoxAppState extends ConsumerState<DeBoxApp> {
  bool _isLoading = true; // 添加加载状态

  @override
  void initState() {
    super.initState();
    _getAccount();
  }

  /// 获取账号信息。设备号：登录成功后从 userInfo 缓存；未登录时在「设置密码」页首次创建/导入时再获取并缓存。
  Future<void> _getAccount() async {
    final api = UserApi();

    try {
      final userInfo = await api.getUserInfo();
      final info = User.fromMap(userInfo);

      await UserCache.saveUserId(info.userId);
      await UserCache.saveDid(info.did);
      await UserCache.saveAvatar(info.avatarUrl);
      await UserCache.saveNickname(info.username);
      if (info.deviceNo.isNotEmpty) {
        await UserCache.saveDevice(info.deviceNo);
      }
      AppLogger.d("GET Response: $userInfo");


      // 刷新用户provider
      ref.refresh(userProvider);
      ref.refresh(myAvatarProvider);
      ref.refresh(myNicknameProvider);

    } on ApiException catch (e) {
      AppLogger.e('请求业务错误: ${e.message}');
    } on DioException catch (e) {
      AppLogger.e('请求出错: ${e.error}', e);
      if (e.response != null) {
        AppLogger.d('响应数据: ${e.response?.data}');
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    // 浅色模式状态栏设置
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    // 显示加载页面直到初始化完成
    if (_isLoading) {
      return MaterialApp(
        home: Scaffold(
          backgroundColor: Colors.white,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  color: const Color(0xFF00D29D),
                ),
                const SizedBox(height: 16),
                const Text(
                  '正在初始化...',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'BBT',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: Colors.white,
        primaryColor: const Color(0xFF00D29D),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
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
