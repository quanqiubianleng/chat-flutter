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
    $core.String? type,
    $core.String? msgType,
    $fixnum.Int64? fromUser,
    $fixnum.Int64? toUser,
    $fixnum.Int64? groupId,
    $core.String? content,
    $core.String? mediaUrl,
    $core.List<$core.int>? extra,
    $fixnum.Int64? timestamp,
    $core.String? nodeId,
  }) {
    final result = create();
    if (type != null) result.type = type;
    if (msgType != null) result.msgType = msgType;
    if (fromUser != null) result.fromUser = fromUser;
    if (toUser != null) result.toUser = toUser;
    if (groupId != null) result.groupId = groupId;
    if (content != null) result.content = content;
    if (mediaUrl != null) result.mediaUrl = mediaUrl;
    if (extra != null) result.extra = extra;
    if (timestamp != null) result.timestamp = timestamp;
    if (nodeId != null) result.nodeId = nodeId;
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
    ..aOS(1, _omitFieldNames ? '' : 'type')
    ..aOS(2, _omitFieldNames ? '' : 'msgType')
    ..aInt64(3, _omitFieldNames ? '' : 'fromUser')
    ..aInt64(4, _omitFieldNames ? '' : 'toUser')
    ..aInt64(5, _omitFieldNames ? '' : 'groupId')
    ..aOS(6, _omitFieldNames ? '' : 'content')
    ..aOS(7, _omitFieldNames ? '' : 'mediaUrl')
    ..a<$core.List<$core.int>>(
        8, _omitFieldNames ? '' : 'extra', $pb.PbFieldType.OY)
    ..aInt64(9, _omitFieldNames ? '' : 'timestamp')
    ..aOS(10, _omitFieldNames ? '' : 'nodeId')
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

  @$pb.TagNumber(1)
  $core.String get type => $_getSZ(0);
  @$pb.TagNumber(1)
  set type($core.String value) => $_setString(0, value);
  @$pb.TagNumber(1)
  $core.bool hasType() => $_has(0);
  @$pb.TagNumber(1)
  void clearType() => $_clearField(1);

  @$pb.TagNumber(2)
  $core.String get msgType => $_getSZ(1);
  @$pb.TagNumber(2)
  set msgType($core.String value) => $_setString(1, value);
  @$pb.TagNumber(2)
  $core.bool hasMsgType() => $_has(1);
  @$pb.TagNumber(2)
  void clearMsgType() => $_clearField(2);

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

  @$pb.TagNumber(6)
  $core.String get content => $_getSZ(5);
  @$pb.TagNumber(6)
  set content($core.String value) => $_setString(5, value);
  @$pb.TagNumber(6)
  $core.bool hasContent() => $_has(5);
  @$pb.TagNumber(6)
  void clearContent() => $_clearField(6);

  @$pb.TagNumber(7)
  $core.String get mediaUrl => $_getSZ(6);
  @$pb.TagNumber(7)
  set mediaUrl($core.String value) => $_setString(6, value);
  @$pb.TagNumber(7)
  $core.bool hasMediaUrl() => $_has(6);
  @$pb.TagNumber(7)
  void clearMediaUrl() => $_clearField(7);

  @$pb.TagNumber(8)
  $core.List<$core.int> get extra => $_getN(7);
  @$pb.TagNumber(8)
  set extra($core.List<$core.int> value) => $_setBytes(7, value);
  @$pb.TagNumber(8)
  $core.bool hasExtra() => $_has(7);
  @$pb.TagNumber(8)
  void clearExtra() => $_clearField(8);

  @$pb.TagNumber(9)
  $fixnum.Int64 get timestamp => $_getI64(8);
  @$pb.TagNumber(9)
  set timestamp($fixnum.Int64 value) => $_setInt64(8, value);
  @$pb.TagNumber(9)
  $core.bool hasTimestamp() => $_has(8);
  @$pb.TagNumber(9)
  void clearTimestamp() => $_clearField(9);

  @$pb.TagNumber(10)
  $core.String get nodeId => $_getSZ(9);
  @$pb.TagNumber(10)
  set nodeId($core.String value) => $_setString(9, value);
  @$pb.TagNumber(10)
  $core.bool hasNodeId() => $_has(9);
  @$pb.TagNumber(10)
  void clearNodeId() => $_clearField(10);
}

const $core.bool _omitFieldNames =
    $core.bool.fromEnvironment('protobuf.omit_field_names');
const $core.bool _omitMessageNames =
    $core.bool.fromEnvironment('protobuf.omit_message_names');
