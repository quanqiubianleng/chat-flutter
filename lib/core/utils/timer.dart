import 'package:fixnum/fixnum.dart';
class TimeUtils {
  /// 获取当前秒级时间戳（本地时区）
  static int get currentTimestamp => DateTime.now().millisecondsSinceEpoch ~/ 1000;

  /// 获取当前毫秒级时间戳
  static int get currentMillis => DateTime.now().millisecondsSinceEpoch;


}

// 秒级时间戳时间格式化
String timestampToDateManual(int timestamp) {
  if (timestamp == 0 || timestamp == null) return '未知时间';

  try {
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);

    // 获取年月日并补齐前导零
    final year = date.year.toString();
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year-$month-$day';
  } catch (e) {
    return '日期格式错误';
  }
}

String formatTimestamp(int? timestampSeconds) {
  if (timestampSeconds == null || timestampSeconds == 0) return '';
  final int timestampMs = timestampSeconds * 1000;
  final date = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  if (date.isAfter(today)) {
    return '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  } else if (date.isAfter(today.subtract(const Duration(days: 1)))) {
    return '昨天';
  } else if (date.year == now.year) {
    return '${date.month}/${date.day}';
  } else {
    return '${date.year}/${date.month}/${date.day}';
  }
}

DateTime parseTimestamp(Int64 ts) {
  final value = ts.toInt();
  final ms = value * (value < 10000000000 ? 1000 : 1);
  return DateTime.fromMillisecondsSinceEpoch(ms);
}