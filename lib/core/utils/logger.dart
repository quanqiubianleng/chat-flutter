import 'package:flutter/foundation.dart';

/// 统一日志：release 下仅保留 error，debug 下输出到 debugPrint。
/// 用法：AppLogger.d('msg'); AppLogger.d(obj);
class AppLogger {
  static void d(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[D] $message');
      if (error != null) debugPrint('  $error');
      if (stackTrace != null) debugPrint('  $stackTrace');
    }
  }

  static void i(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[I] $message');
      if (error != null) debugPrint('  $error');
      if (stackTrace != null) debugPrint('  $stackTrace');
    }
  }

  static void w(Object? message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[W] $message');
      if (error != null) debugPrint('  $error');
      if (stackTrace != null) debugPrint('  $stackTrace');
    }
  }

  static void e(Object? message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[E] $message');
    if (error != null) debugPrint('  $error');
    if (stackTrace != null) debugPrint('  $stackTrace');
  }
}
