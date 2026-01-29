import 'dart:convert';

// 红包 Extra
class RedPacketExtra {
  final String redPacketId;
  final int amount;      // 单位：分
  final int count;       // 个数
  final String? wish;
  final String rpType;   // "lucky" | "fixed" 等
  final int status;       // 0:未领取，1：已领取
  final int expiredAt;  // 过期时间

  RedPacketExtra({
    required this.redPacketId,
    required this.amount,
    required this.count,
    this.wish,
    required this.rpType,
    required this.status,
    required this.expiredAt,
  });

  factory RedPacketExtra.fromJson(Map<String, dynamic> json) {
    return RedPacketExtra(
      redPacketId: json['red_packet_id'] as String,
      amount: json['amount'] as int,
      count: json['count'] as int,
      wish: json['wish'] as String?,
      rpType: json['rp_type'] as String,
      status: json['status'] as int,
      expiredAt: json['expired_at'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'red_packet_id': redPacketId,
      'amount': amount,
      'count': count,
      if (wish != null) 'wish': wish,
      'rp_type': rpType,
      'status': status,
      'expired_at': expiredAt,
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
  final int status;       // 0:未领取，1：已领取
  final String? icon;
  final int expiredAt; // 过期时间

  TransferExtra({
    required this.transferId,
    required this.amount,
    this.remark,
    required this.status,
    required this.icon,
    required this.expiredAt,
  });

  factory TransferExtra.fromJson(Map<String, dynamic> json) {
    return TransferExtra(
      transferId: json['transfer_id'] as String,
      amount: json['amount'] as int,
      remark: json['remark'] as String?,
      status: json['status'] as int,
      icon: json['icon'] as String?,
      expiredAt: json['expired_at'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'transfer_id': transferId,
      'amount': amount,
      if (remark != null) 'remark': remark,
      'status': status,
      'icon': icon,
      'expired_at': expiredAt,
    };
  }
}