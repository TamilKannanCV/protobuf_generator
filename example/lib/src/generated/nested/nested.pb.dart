//
//  Generated code. Do not modify.
//  source: nested/nested.proto
//
// @dart = 2.12

// ignore_for_file: annotate_overrides, camel_case_types, comment_references
// ignore_for_file: constant_identifier_names, library_prefixes
// ignore_for_file: non_constant_identifier_names, prefer_final_fields
// ignore_for_file: unnecessary_import, unnecessary_this, unused_import

import 'dart:core' as $core;

import 'package:protobuf/protobuf.dart' as $pb;

import '../my_proto.pb.dart' as $0;

class MyNestedMessage extends $pb.GeneratedMessage {
  factory MyNestedMessage({
    $0.MyMessage? message,
  }) {
    final $result = create();
    if (message != null) {
      $result.message = message;
    }
    return $result;
  }
  MyNestedMessage._() : super();
  factory MyNestedMessage.fromBuffer($core.List<$core.int> i,
          [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromBuffer(i, r);
  factory MyNestedMessage.fromJson($core.String i, [$pb.ExtensionRegistry r = $pb.ExtensionRegistry.EMPTY]) =>
      create()..mergeFromJson(i, r);

  static final $pb.BuilderInfo _i = $pb.BuilderInfo(_omitMessageNames ? '' : 'MyNestedMessage',
      package: const $pb.PackageName(_omitMessageNames ? '' : 'nested'), createEmptyInstance: create)
    ..aOM<$0.MyMessage>(1, _omitFieldNames ? '' : 'message', subBuilder: $0.MyMessage.create)
    ..hasRequiredFields = false;

  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.deepCopy] instead. '
      'Will be removed in next major version')
  MyNestedMessage clone() => MyNestedMessage()..mergeFromMessage(this);
  @$core.Deprecated('Using this can add significant overhead to your binary. '
      'Use [GeneratedMessageGenericExtensions.rebuild] instead. '
      'Will be removed in next major version')
  MyNestedMessage copyWith(void Function(MyNestedMessage) updates) =>
      super.copyWith((message) => updates(message as MyNestedMessage)) as MyNestedMessage;

  $pb.BuilderInfo get info_ => _i;

  @$core.pragma('dart2js:noInline')
  static MyNestedMessage create() => MyNestedMessage._();
  MyNestedMessage createEmptyInstance() => create();
  static $pb.PbList<MyNestedMessage> createRepeated() => $pb.PbList<MyNestedMessage>();
  @$core.pragma('dart2js:noInline')
  static MyNestedMessage getDefault() =>
      _defaultInstance ??= $pb.GeneratedMessage.$_defaultFor<MyNestedMessage>(create);
  static MyNestedMessage? _defaultInstance;

  @$pb.TagNumber(1)
  $0.MyMessage get message => $_getN(0);
  @$pb.TagNumber(1)
  set message($0.MyMessage v) {
    setField(1, v);
  }

  @$pb.TagNumber(1)
  $core.bool hasMessage() => $_has(0);
  @$pb.TagNumber(1)
  void clearMessage() => clearField(1);
  @$pb.TagNumber(1)
  $0.MyMessage ensureMessage() => $_ensure(0);
}

const _omitFieldNames = $core.bool.fromEnvironment('protobuf.omit_field_names');
const _omitMessageNames = $core.bool.fromEnvironment('protobuf.omit_message_names');
