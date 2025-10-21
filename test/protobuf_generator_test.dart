import 'package:build/build.dart';
import 'package:test/test.dart';
import 'package:protobuf_generator/protobuf_generator.dart';

void main() {
  group('ProtobufGenerator', () {
    test('should create a builder with default GRPC setting', () {
      final options = BuilderOptions({});
      final builder = getGenerator(options);
      expect(builder, isNotNull);
      expect(builder, isA<Builder>());
    });

    test('should create a builder with GRPC enabled', () {
      final options = BuilderOptions({'generate_grpc': true});
      final builder = getGenerator(options);
      expect(builder, isNotNull);
      expect(builder, isA<Builder>());
    });

    test('should create a builder with GRPC disabled', () {
      final options = BuilderOptions({'generate_grpc': false});
      final builder = getGenerator(options);
      expect(builder, isNotNull);
      expect(builder, isA<Builder>());
    });
  });
}
