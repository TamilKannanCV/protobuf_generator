library protobuf_generator;

import 'package:build/build.dart';
import 'package:protobuf_generator/src/protobuf_generator.dart';

Builder getGenerator(BuilderOptions options) => ProtobufGenerator(options);
