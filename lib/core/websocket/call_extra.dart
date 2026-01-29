enum CallType {
  voice,    // 语音通话
  video,    // 视频通话
}

enum CallAction {
  invite,     // 发起通话邀请（携带 offer）
  answer,     // 接听（携带 answer）
  reject,     // 拒绝
  cancel,     // 主叫取消
  hangup,     // 挂断
  candidate,  // ICE candidate
  timeout,    // 超时未接听
  busy,       // 占线
}

class CallExtra {
  final String callId;              // 通话唯一ID，全局唯一
  final CallType callType;          // voice 或 video
  final CallAction action;          // 当前信令动作
  final String callerId;            // 主叫用户ID
  final List<String> calleeIds;     // 被叫用户ID列表（支持多人，1v1 时长度为1）
  final String? sdp;                // WebRTC SDP（invite/answer 时使用）
  final String? candidate;          // ICE candidate（candidate 时使用）
  final int? timestamp;             // 可选：服务器时间戳
  final Map<String, dynamic>? extra; // 预留扩展字段（如会议标题、群聊ID等）

  CallExtra({
    required this.callId,
    required this.callType,
    required this.action,
    required this.callerId,
    required this.calleeIds,
    this.sdp,
    this.candidate,
    this.timestamp,
    this.extra,
  });

  factory CallExtra.fromJson(Map<String, dynamic> json) {
    return CallExtra(
      callId: json['call_id'] as String,
      callType: CallType.values.firstWhere(
            (e) => e.name == json['call_type'],
      ),
      action: CallAction.values.firstWhere(
            (e) => e.name == json['action'],
      ),
      callerId: json['caller_id'] as String,
      calleeIds: List<String>.from(json['callee_ids'] as List),
      sdp: json['sdp'] as String?,
      candidate: json['candidate'] as String?,
      timestamp: json['timestamp'] as int?,
      extra: json['extra'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'call_id': callId,
      'call_type': callType.name,
      'action': action.name,
      'caller_id': callerId,
      'callee_ids': calleeIds,
      if (sdp != null) 'sdp': sdp,
      if (candidate != null) 'candidate': candidate,
      if (timestamp != null) 'timestamp': timestamp,
      if (extra != null) 'extra': extra,
    };
  }
}