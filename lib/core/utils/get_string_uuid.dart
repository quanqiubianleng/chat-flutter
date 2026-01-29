import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// 生成转账ID：trans_ + 32位无横线UUID
String generateTransferId() {
  return 'trans_${_uuid.v4().replaceAll('-', '')}';
}

/// 生成红包ID：rp_ + 32位无横线UUID
String generateRedPacketId() {
  return 'rp_${_uuid.v4().replaceAll('-', '')}';
}

// 更灵活的版本，可以自定义前后显示的长度
String truncateString(String text, {int prefixLength = 7, int suffixLength = 7, String ellipsis = '...'}) {
  if (text.length <= prefixLength + suffixLength) {
    return text;
  }

  final start = text.substring(0, prefixLength);
  final end = text.substring(text.length - suffixLength);

  return '$start$ellipsis$end';
}