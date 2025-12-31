// This is a generated file - do not edit.
//
// Generated from protos/chat.proto.

// @dart = 3.3

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names
// ignore_for_file: curly_braces_in_flow_control_structures
// ignore_for_file: deprecated_member_use_from_same_package, library_prefixes
// ignore_for_file: non_constant_identifier_names, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use eventDescriptor instead')
const Event$json = {
  '1': 'Event',
  '2': [
    {'1': 'delivery', '3': 1, '4': 1, '5': 9, '10': 'delivery'},
    {'1': 'type', '3': 2, '4': 1, '5': 9, '10': 'type'},
    {'1': 'from_user', '3': 3, '4': 1, '5': 3, '10': 'fromUser'},
    {'1': 'to_user', '3': 4, '4': 1, '5': 3, '10': 'toUser'},
    {'1': 'group_id', '3': 5, '4': 1, '5': 3, '10': 'groupId'},
    {'1': 'msg_id', '3': 6, '4': 1, '5': 9, '10': 'msgId'},
    {'1': 'client_msg_id', '3': 7, '4': 1, '5': 9, '10': 'clientMsgId'},
    {'1': 'media_url', '3': 8, '4': 1, '5': 9, '10': 'mediaUrl'},
    {'1': 'content', '3': 9, '4': 1, '5': 9, '10': 'content'},
    {'1': 'extra', '3': 10, '4': 1, '5': 12, '10': 'extra'},
    {'1': 'timestamp', '3': 11, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'server_ts', '3': 12, '4': 1, '5': 3, '10': 'serverTs'},
    {'1': 'node_id', '3': 13, '4': 1, '5': 9, '10': 'nodeId'},
    {'1': 'seq', '3': 14, '4': 1, '5': 3, '10': 'seq'},
    {'1': 'status', '3': 15, '4': 1, '5': 9, '10': 'status'},
    {'1': 'reply_to', '3': 16, '4': 1, '5': 9, '10': 'replyTo'},
    {'1': 'mention', '3': 17, '4': 3, '5': 3, '10': 'mention'},
    {'1': 'thread_id', '3': 18, '4': 1, '5': 9, '10': 'threadId'},
    {'1': 'sender_nickname', '3': 19, '4': 1, '5': 9, '10': 'senderNickname'},
    {'1': 'sender_avatar', '3': 20, '4': 1, '5': 9, '10': 'senderAvatar'},
    {'1': 'conversation_id', '3': 30, '4': 1, '5': 9, '10': 'conversationId'},
  ],
};

/// Descriptor for `Event`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventDescriptor = $convert.base64Decode(
    'CgVFdmVudBIaCghkZWxpdmVyeRgBIAEoCVIIZGVsaXZlcnkSEgoEdHlwZRgCIAEoCVIEdHlwZR'
    'IbCglmcm9tX3VzZXIYAyABKANSCGZyb21Vc2VyEhcKB3RvX3VzZXIYBCABKANSBnRvVXNlchIZ'
    'Cghncm91cF9pZBgFIAEoA1IHZ3JvdXBJZBIVCgZtc2dfaWQYBiABKAlSBW1zZ0lkEiIKDWNsaW'
    'VudF9tc2dfaWQYByABKAlSC2NsaWVudE1zZ0lkEhsKCW1lZGlhX3VybBgIIAEoCVIIbWVkaWFV'
    'cmwSGAoHY29udGVudBgJIAEoCVIHY29udGVudBIUCgVleHRyYRgKIAEoDFIFZXh0cmESHAoJdG'
    'ltZXN0YW1wGAsgASgDUgl0aW1lc3RhbXASGwoJc2VydmVyX3RzGAwgASgDUghzZXJ2ZXJUcxIX'
    'Cgdub2RlX2lkGA0gASgJUgZub2RlSWQSEAoDc2VxGA4gASgDUgNzZXESFgoGc3RhdHVzGA8gAS'
    'gJUgZzdGF0dXMSGQoIcmVwbHlfdG8YECABKAlSB3JlcGx5VG8SGAoHbWVudGlvbhgRIAMoA1IH'
    'bWVudGlvbhIbCgl0aHJlYWRfaWQYEiABKAlSCHRocmVhZElkEicKD3NlbmRlcl9uaWNrbmFtZR'
    'gTIAEoCVIOc2VuZGVyTmlja25hbWUSIwoNc2VuZGVyX2F2YXRhchgUIAEoCVIMc2VuZGVyQXZh'
    'dGFyEicKD2NvbnZlcnNhdGlvbl9pZBgeIAEoCVIOY29udmVyc2F0aW9uSWQ=');
