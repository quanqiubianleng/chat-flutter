import 'package:intl/intl.dart'; // 如果没装 intl，先加依赖

class ChatDateUtils {
  static bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  static bool isToday(DateTime dt) {
    final now = DateTime.now();
    return isSameDay(dt, now);
  }

  static bool isYesterday(DateTime dt) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return isSameDay(dt, yesterday);
  }

  // 微信风格的日期头
  static String formatDateHeader(DateTime dt) {
    if (isToday(dt)) return formatTimeOnly(dt);
    if (isYesterday(dt)) return "昨天${formatTimeOnly(dt)}";

    final now = DateTime.now();
    final format = dt.year == now.year
        ? DateFormat("M月d日 ${formatTimeOnly(dt)} EEEE", "zh_CN") // 10月15日 星期三
        : DateFormat("yyyy年M月d日 ${formatTimeOnly(dt)} EEEE", "zh_CN");

    return format.format(dt);
  }

  // 只显示时:分
  static String formatTimeOnly(DateTime dt) {
    return DateFormat("HH:mm").format(dt);
  }

  // 判断是否需要显示时间（间隔 ≥ 5分钟 或 第一条）
  static bool shouldShowTime(DateTime current, DateTime? previous) {
    if (previous == null) return true;
    final diff = current.difference(previous).inMinutes.abs();
    return diff >= 5;
  }
}