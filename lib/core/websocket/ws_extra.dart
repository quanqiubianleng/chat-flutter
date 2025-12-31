import 'dart:convert';

// 红包 Extra
class RedPacketExtra {
  final String redPacketId;
  final int amount;      // 单位：分
  final int count;       // 个数
  final String? wish;
  final String rpType;   // "lucky" | "fixed" 等

  RedPacketExtra({
    required this.redPacketId,
    required this.amount,
    required this.count,
    this.wish,
    required this.rpType,
  });

  factory RedPacketExtra.fromJson(Map<String, dynamic> json) {
    return RedPacketExtra(
      redPacketId: json['red_packet_id'] as String,
      amount: json['amount'] as int,
      count: json['count'] as int,
      wish: json['wish'] as String?,
      rpType: json['rp_type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'red_packet_id': redPacketId,
      'amount': amount,
      'count': count,
      if (wish != null) 'wish': wish,
      'rp_type': rpType,
    };
  }
}

// 语音 Extra
class VoiceExtra {
  final String url;
  final int duration;    // 秒
  final int? size;

  VoiceExtra({
    required this.url,
    required this.duration,
    this.size,
  });

  factory VoiceExtra.fromJson(Map<String, dynamic> json) {
    return VoiceExtra(
      url: json['url'] as String,
      duration: json['duration'] as int,
      size: json['size'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'duration': duration,
      if (size != null) 'size': size,
    };
  }
}

// 转账 Extra
class TransferExtra {
  final String transferId;
  final int amount;      // 单位：分
  final String? remark;

  TransferExtra({
    required this.transferId,
    required this.amount,
    this.remark,
  });

  factory TransferExtra.fromJson(Map<String, dynamic> json) {
    return TransferExtra(
      transferId: json['transfer_id'] as String,
      amount: json['amount'] as int,
      remark: json['remark'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transfer_id': transferId,
      'amount': amount,
      if (remark != null) 'remark': remark,
    };
  }
}