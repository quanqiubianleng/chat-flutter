import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:education/config/app_config.dart';
import 'package:education/config/app_env.dart';
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
  final envRaw = kRawEnv.isEmpty ? '<unset>' : kRawEnv;
  AppLogger.i('[APP_BOOT] envRaw=$envRaw, env=$kAppEnv, reqUrl=${AppConfig.reqUrl}');

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
      child: const BBTApp(),
    ),
  );


}

class BBTApp extends ConsumerStatefulWidget {
  const BBTApp({super.key});

  @override
  ConsumerState<BBTApp> createState() => _BBTAppState();
}

class _BBTAppState extends ConsumerState<BBTApp> {
  bool _isLoading = true;
  bool _pendingExpiredPrompt = false;

  @override
  void initState() {
    super.initState();
    _getAccount();
  }

  /// 获取账号信息。token 过期时拦截器会自动用 refresh_token 换新 token 并重试，用户无感知。
  Future<void> _getAccount() async {
    final api = UserApi();
    final hadToken = await UserCache.getToken() != null;
    try {
      final userInfo = await api.getUserInfo();
      final info = User.fromMap(userInfo);
      await UserCache.saveUserId(info.userId);
      await UserCache.saveDid(info.did);
      await UserCache.saveAvatar(info.avatarUrl);
      await UserCache.saveNickname(info.username);
      final rt = userInfo['refresh_token']?.toString();
      if (rt != null && rt.isNotEmpty) await UserCache.saveRefreshToken(rt);
      if (info.deviceNo.isNotEmpty) {
        await UserCache.saveDevice(info.deviceNo);
      }
      AppLogger.d("GET Response: $userInfo");
      ref.refresh(userProvider);
      ref.refresh(myAvatarProvider);
      ref.refresh(myNicknameProvider);
    } on ApiException catch (e) {
      if (e.message.contains('登录已过期')) {
        AppLogger.d('登录已过期，请到个人中心重新验证或切换账号后重试');
        if (hadToken) _pendingExpiredPrompt = true;
      } else {
        AppLogger.e('请求业务错误: ${e.message}');
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        AppLogger.d('Token 已过期，请到个人中心重新验证');
        if (hadToken) _pendingExpiredPrompt = true;
      } else {
        AppLogger.e('请求出错: ${e.error}', e);
        if (e.response != null) AppLogger.d('响应数据: ${e.response?.data}');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        if (_pendingExpiredPrompt) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('登录已过期，请到「我的」重新验证或切换账号'),
                duration: Duration(seconds: 4),
              ),
            );
            setState(() => _pendingExpiredPrompt = false);
          });
        }
      }
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
        // 全项目 Switch 无边框（去掉外圈/overlay 边框）
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const Color(0xFF00D1A7);
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return const Color(0xFF00D1A7).withOpacity(0.5);
            return Colors.grey.withOpacity(0.3);
          }),
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
        ),
      ),
      home: const MainTabScaffold(),
    );
  }
}
