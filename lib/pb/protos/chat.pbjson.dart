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
    {'1': 'type', '3': 1, '4': 1, '5': 9, '10': 'type'},
    {'1': 'msg_type', '3': 2, '4': 1, '5': 9, '10': 'msgType'},
    {'1': 'from_user', '3': 3, '4': 1, '5': 3, '10': 'fromUser'},
    {'1': 'to_user', '3': 4, '4': 1, '5': 3, '10': 'toUser'},
    {'1': 'group_id', '3': 5, '4': 1, '5': 3, '10': 'groupId'},
    {'1': 'content', '3': 6, '4': 1, '5': 9, '10': 'content'},
    {'1': 'media_url', '3': 7, '4': 1, '5': 9, '10': 'mediaUrl'},
    {'1': 'extra', '3': 8, '4': 1, '5': 12, '10': 'extra'},
    {'1': 'timestamp', '3': 9, '4': 1, '5': 3, '10': 'timestamp'},
    {'1': 'node_id', '3': 10, '4': 1, '5': 9, '10': 'nodeId'},
  ],
};

/// Descriptor for `Event`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List eventDescriptor = $convert.base64Decode(
    'CgVFdmVudBISCgR0eXBlGAEgASgJUgR0eXBlEhkKCG1zZ190eXBlGAIgASgJUgdtc2dUeXBlEh'
    'sKCWZyb21fdXNlchgDIAEoA1IIZnJvbVVzZXISFwoHdG9fdXNlchgEIAEoA1IGdG9Vc2VyEhkK'
    'CGdyb3VwX2lkGAUgASgDUgdncm91cElkEhgKB2NvbnRlbnQYBiABKAlSB2NvbnRlbnQSGwoJbW'
    'VkaWFfdXJsGAcgASgJUghtZWRpYVVybBIUCgVleHRyYRgIIAEoDFIFZXh0cmESHAoJdGltZXN0'
    'YW1wGAkgASgDUgl0aW1lc3RhbXASFwoHbm9kZV9pZBgKIAEoCVIGbm9kZUlk');
