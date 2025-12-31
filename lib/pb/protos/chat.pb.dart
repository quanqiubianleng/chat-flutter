// This is a generated file - do not edit.
//
// Generated from protos/chat.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names

import 'dart:core' as $core;

import 'package:fixnum/fixnum.dart' as $fixnum;
import 'package:protobuf/protobuf.dart' as $pb;

export 'package:protobuf/protobuf.dart' show GeneratedMessageGenericExtensions;

class Event extends $pb.GeneratedMessage {
  factory Event({
    $core.String? delivery,
    $core.String? type,
    $fixnum.Int64? fromUser,
    $fixnum.Int64? toUser,
    $fixnum.Int64? groupId,
    $core.String? msgId,
    $core.String? clientMsgId,
    $core.String? mediaUrl,
    $core.String? content,
    $core.List<$core.int>? extra,
    $fixnum.Int64? timestamp,
    $fixnum.Int64? serverTs,
    $core.String? nodeId,
    $fixnum.Int64? seq,
    $core.String? status,
    $core.String? replyTo,
    $core.Iterable<$fixnum.Int64>? mention,
    $core.String? threadId,
    $core.String? senderNickname,
    $core.String? senderAvatar,
    $core.String? conversationId,
  }) {
    final result = create();
    if (delivery != null) result.delivery = delivery;
    if (type != null) result.type = type;
    if (fromUser != null) result.fromUser = fromUser;
    if (toUser != null) result.toUser = toUser;
    if (groupId != null) result.groupId = groupId;
    if (msgId != null) result.msgId = msgId;
    if (clientMsgId != null) result.clientMsgId = clientMsgId;
    if (mediaUrl != null) result.mediaUrl = mediaUrl;
    if (content != null) result.content = content;
    if (extra != null) result.extra = extra;
    if (timestamp != null) result.timestamp = timestamp;
    if (serverTs != null) result.serverTs = serverTs;
    if (nodeId != null) result.nodeId = nodeId;
    if (seq != null) result.seq = seq;
    if (status != null) result.status = status;
    if (replyTo != null) result.replyTo = replyTo;
    if (mention != null) result.mention.addAll(mention);
    if (threadId != null) result.threadId = threadId;
    if (senderNickname != null) result.senderNickname = senderNickname;
    if (senderAvatar != null) result.senderAvatar = senderAvatar;
    if (conversationId != null) result.conversationId = conversationId;
    return result;
  }

  Event._();

  factory Event.fromBuffer($core.List<$core.int> data,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(data, registry);
  factory Event.fromJson($core.String json,
          [$pb.ExtensionRegistry registry = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(json, registry);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(
      _omitMessageNames ? '' : 'Event',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'education'),
      createEmptyInstance: create)
    ..aOS(1, _omitFieldNames ? '' : 'delivery')
    ..aOS(2, _omitFieldNames ? '' : 'type')
    ..aInt64(3, _omitFieldNames ? '' : 'fromUser')
    ..aInt64(4, _omitFieldNames ? '' : 'toUser')
    ..aInt64(5, _omitFieldNames ? '' : 'groupId')
    ..aOS(6, _omitFieldNames ? '' : 'msgId')
    ..aOS(7, _omitFieldNames ? '' : 'clientMsgId')
    ..aOS(8, _omitFieldNames ? '' : 'mediaUrl')
    ..aOS(9, _omitFieldNames ? '' : 'content')
    ..a<$core.List<$core.int>>(
        10, _omitFieldNames ? '' : 'extra', $pb.PbFieldType.OY)
    ..aInt64(11, _omitFieldNames ? '' : 'timestamp')
    ..aInt64(12, _omitFieldNames ? '' : 'serverTs')
    ..aOS(13, _omitFieldNames ? '' : 'nodeId')
    ..aInt64(14, _omitFieldNames ? '' : 'seq')
    ..aOS(15, _omitFieldNames ? '' : 'status')
    ..aOS(16, _omitFieldNames ? '' : 'replyTo')
    ..p<$fixnum.Int64>(17, _omitFieldNames ? '' : 'mention', $pb.PbFieldType.K6)
    ..aOS(18, _omitFieldNames ? '' : 'threadId')
    ..aOS(19, _omitFieldNames ? '' : 'senderNickname')
    ..aOS(20, _omitFieldNames ? '' : 'senderAvatar')
    ..aOS(30, _omitFieldNames ? '' : 'conversationId')
    ..hasRequiredFields = false;

  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event clone() => deepCopy();
  @$core.Deprecated('See https://github.com/google/protobuf.dart/issues/998.')
  Event copyWith(void Function(Event) updates) =>
      super.copyWith((message) => updates(message as Event)) as Event;

  @$core.override
  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static Event create() => Event._();
  @$core.override
  Event createEmptyInstance() => create();
  @$core.pragma('dart2js:noInline')
  static Event getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<Event>(create);
  static Event? _defaultInstance;

  /// 路由相关
  @$pb.TagNumber(1)
  $core.String get delivery => $_getSZ(0);
  @$pb.TagNumber(1)
  set delivery($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasDelivery() => $_has(0);
  @$pb.TagNumber(1)
  void clearDelivery() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get type => $_getSZ(1);
  @$pb.TagNumber(2)
  set type($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasType() => $_has(1);
  @$pb.TagNumber(2)
  void clearType() => $_clearField(2);

  @$pb.TagNumber(3)
  $fixnum.Int64 get fromUser => $_getI64(2);
  @$pb.TagNumber(3)
  set fromUser($fixnum.Int64 value) => $_setInt64(2, value);
  @$pb.TagNumber(3)
  $core.bool hasFromUser() => $_has(2);
  @$pb.TagNumber(3)
  void clearFromUser() => $_clearField(3);

  @$pb.TagNumber(4)
  $fixnum.Int64 get toUser => $_getI64(3);
  @$pb.TagNumber(4)
  set toUser($fixnum.Int64 value) => $_setInt64(3, value);
  @$pb.TagNumber(4)
  $core.bool hasToUser() => $_has(3);
  @$pb.TagNumber(4)
  void clearToUser() => $_clearField(4);

  @$pb.TagNumber(5)
  $fixnum.Int64 get groupId => $_getI64(4);
  @$pb.TagNumber(5)
  set groupId($fixnum.Int64 value) => $_setInt64(4, value);
  @$pb.TagNumber(5)
  $core.bool hasGroupId() => $_has(4);
  @$pb.TagNumber(5)
  void clearGroupId() => $_clearField(5);

  /// 消息唯一标识
  @$pb.TagNumber(6)
  $core.String get msgId => $_getSZ(5);
  @$pb.TagNumber(6)
  set msgId($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasMsgId() => $_has(5);
  @$pb.TagNumber(6)
  void clearMsgId() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get clientMsgId => $_getSZ(6);
  @$pb.TagNumber(7)
  set clientMsgId($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasClientMsgId() => $_has(6);
  @$pb.TagNumber(7)
  void clearClientMsgId() => $_clearField(7);

  /// 内容
  @$pb.TagNumber(8)
  $core.String get mediaUrl => $_getSZ(7);
  @$pb.TagNumber(8)
  set mediaUrl($core.String value) => $_setString(7, value);
  @$pb.TagNumber(8)
  $core.bool hasMediaUrl() => $_has(7);
  @$pb.TagNumber(8)
  void clearMediaUrl() => $_clearField(8);

  @$pb.TagNumber(9)
  $core.String get content => $_getSZ(8);
  @$pb.TagNumber(9)
  set content($core.String value) => $_setString(8, value);
  @$pb.TagNumber(9)
  $core.bool hasContent() => $_has(8);
  @$pb.TagNumber(9)
  void clearContent() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.List<$core.int> get extra => $_getN(9);
  @$pb.TagNumber(10)
  set extra($core.List<$core.int> value) => $_setBytes(9, value);
  @$pb.TagNumber(10)
  $core.bool hasExtra() => $_has(9);
  @$pb.TagNumber(10)
  void clearExtra() => $_clearField(10);

  /// 时间
  @$pb.TagNumber(11)
  $fixnum.Int64 get timestamp => $_getI64(10);
  @$pb.TagNumber(11)
  set timestamp($fixnum.Int64 value) => $_setInt64(10, value);
  @$pb.TagNumber(11)
  $core.bool hasTimestamp() => $_has(10);
  @$pb.TagNumber(11)
  void clearTimestamp() => $_clearField(11);

  @$pb.TagNumber(12)
  $fixnum.Int64 get serverTs => $_getI64(11);
  @$pb.TagNumber(12)
  set serverTs($fixnum.Int64 value) => $_setInt64(11, value);
  @$pb.TagNumber(12)
  $core.bool hasServerTs() => $_has(11);
  @$pb.TagNumber(12)
  void clearServerTs() => $_clearField(12);

  @$pb.TagNumber(13)
  $core.String get nodeId => $_getSZ(12);
  @$pb.TagNumber(13)
  set nodeId($core.String value) => $_setString(12, value);
  @$pb.TagNumber(13)
  $core.bool hasNodeId() => $_has(12);
  @$pb.TagNumber(13)
  void clearNodeId() => $_clearField(13);

  /// 状态回执
  @$pb.TagNumber(14)
  $fixnum.Int64 get seq => $_getI64(13);
  @$pb.TagNumber(14)
  set seq($fixnum.Int64 value) => $_setInt64(13, value);
  @$pb.TagNumber(14)
  $core.bool hasSeq() => $_has(13);
  @$pb.TagNumber(14)
  void clearSeq() => $_clearField(14);

  @$pb.TagNumber(15)
  $core.String get status => $_getSZ(14);
  @$pb.TagNumber(15)
  set status($core.String value) => $_setString(14, value);
  @$pb.TagNumber(15)
  $core.bool hasStatus() => $_has(14);
  @$pb.TagNumber(15)
  void clearStatus() => $_clearField(15);

  /// 扩展
  @$pb.TagNumber(16)
  $core.String get replyTo => $_getSZ(15);
  @$pb.TagNumber(16)
  set replyTo($core.String value) => $_setString(15, value);
  @$pb.TagNumber(16)
  $core.bool hasReplyTo() => $_has(15);
  @$pb.TagNumber(16)
  void clearReplyTo() => $_clearField(16);

  @$pb.TagNumber(17)
  $pb.PbList<$fixnum.Int64> get mention => $_getList(16);

  @$pb.TagNumber(18)
  $core.String get threadId => $_getSZ(17);
  @$pb.TagNumber(18)
  set threadId($core.String value) => $_setString(17, value);
  @$pb.TagNumber(18)
  $core.bool hasThreadId() => $_has(17);
  @$pb.TagNumber(18)
  void clearThreadId() => $_clearField(18);

  /// 发送者信息
  @$pb.TagNumber(19)
  $core.String get senderNickname => $_getSZ(18);
  @$pb.TagNumber(19)
  set senderNickname($core.String value) => $_setString(18, value);
  @$pb.TagNumber(19)
  $core.bool hasSenderNickname() => $_has(18);
  @$pb.TagNumber(19)
  void clearSenderNickname() => $_clearField(19);

  @$pb.TagNumber(20)
  $core.String get senderAvatar => $_getSZ(19);
  @$pb.TagNumber(20)
  set senderAvatar($core.String value) => $_setString(19, value);
  @$pb.TagNumber(20)
  $core.bool hasSenderAvatar() => $_has(19);
  @$pb.TagNumber(20)
  void clearSenderAvatar() => $_clearField(20);

  /// 新增：会话ID（核心！所有消息必填）
  @$pb.TagNumber(30)
  $core.String get conversationId => $_getSZ(20);
  @$pb.TagNumber(30)
  set conversationId($core.String value) => $_setString(20, value);
  @$pb.TagNumber(30)
  $core.bool hasConversationId() => $_has(20);
  @$pb.TagNumber(30)
  void clearConversationId() => $_clearField(30);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
