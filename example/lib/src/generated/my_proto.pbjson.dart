//
//  Generated code. Do not modify.
//  source: my_proto.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:convert' as $convert;
import 'dart:core' as $core;
import 'dart:typed_data' as $typed_data;

@$core.Deprecated('Use myMessageDescriptor instead')
const MyMessage$json = {
  '1': 'MyMessage',
  '2': [
    {'1': 'value', '3': 1, '4': 1, '5': 5, '10': 'value'},
  ],
};

/// Descriptor for `MyMessage`. Decode as a `google.protobuf.DescriptorProto`.
final $typed_data.Uint8List myMessageDescriptor = $convert.base64Decode(
    'CglNeU1lc3NhZ2USFAoFdmFsdWUYASABKAVSBXZhbHVl');

const $core.Map<$core.String, $core.dynamic> MyServiceBase$json = {
  '1': 'MyService',
  '2': [
    {'1': 'MyMethod', '2': '.MyMessage', '3': '.MyMessage'},
  ],
};

@$core.Deprecated('Use myServiceDescriptor instead')
const $core.Map<$core.String, $core.Map<$core.String, $core.dynamic>> MyServiceBase$messageJson = {
  '.MyMessage': MyMessage$json,
};

/// Descriptor for `MyService`. Decode as a `google.protobuf.ServiceDescriptorProto`.
final $typed_data.Uint8List myServiceDescriptor = $convert.base64Decode(
    'CglNeVNlcnZpY2USIgoITXlNZXRob2QSCi5NeU1lc3NhZ2UaCi5NeU1lc3NhZ2U=');

