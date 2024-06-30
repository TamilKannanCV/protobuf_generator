import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart';
import 'package:protobuf_generator/src/downloaders/googleapis_downloader.dart';
import 'package:protobuf_generator/src/downloaders/protoc_plugin_downloader.dart';
import 'package:protobuf_generator/src/utils/process_utils.dart';
import 'package:yaml/yaml.dart';

import 'downloaders/protoc_downloader.dart';

class ProtobufGenerator implements Builder {
  ProtobufGenerator(this.options) {
    final config = options.config;
    protobufVersion = config['protobuf_version'] as String? ?? kDefaultProtocVersion;
    protocPluginVersion = config['protoc_plugin_version'] as String? ?? kDefaultProtocPluginVersion;
    rootDirectory = config['proto_root_dir'] as String? ?? kDefaultProtoRootDirectory;
    protoPaths =
        (config['proto_paths'] as YamlList?)?.nodes.map((e) => e.value as String).toList() ?? kDefaultProtoPaths;
    outputDirectory = normalize(config['dart_path'] as String? ?? kDefaultDartOutputDirectory);
    useInstalledProtoc = config['use_installed_protoc'] as bool? ?? kDefaultUseInstalledProtoc;
    precompileProtocPlugin = config['precompile_protoc_plugin'] as bool? ?? kDefaultPrecompileProtocPlugin;
  }

  final BuilderOptions options;
  late String protobufVersion;
  late String protocPluginVersion;
  late String rootDirectory;
  late List<String> protoPaths;
  late String outputDirectory;
  late bool useInstalledProtoc;
  late bool precompileProtocPlugin;

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final protoc = useInstalledProtoc ? File('protoc') : await ProtocDownloader.fetchProtoc(protobufVersion);
    final protocPlugin = useInstalledProtoc
        ? File('')
        : await ProtocPluginDownloader.fetchProtocPlugin(protocPluginVersion, precompileProtocPlugin);
    protoPaths.add(await GoogleApisDownloader.fetchProtoGoogleApis("1.0"));

    final inputPath = normalize(buildStep.inputId.path);

    await buildStep.readAsString(buildStep.inputId);

    await Directory(outputDirectory).create(recursive: true);
    final imports = await extractImports(inputPath);
    await ProcessUtils.runSafely(
      protoc.path,
      collectProtocArguments(protocPlugin, inputPath)..addAll(imports),
    );

    await Future.wait(buildStep.allowedOutputs.map((AssetId out) async {
      var file = loadOutputFile(out);

      if (file.path.endsWith('.pbgrpc.dart') && !await file.exists()) {
        return;
      }
      await buildStep.writeAsBytes(out, file.readAsBytes());
    }));
  }

  File loadOutputFile(AssetId out) => File(out.path);

  List<String> collectProtocArguments(File protocPlugin, String inputPath) {
    return <String>[
      if (protocPlugin.path.isNotEmpty) "--plugin=protoc-gen-dart=${protocPlugin.path}",
      "--dart_out=${join('.', outputDirectory)}",
      ...protoPaths.map((protoPath) => '-I=${join('.', protoPath)}'),
      join('.', inputPath),
    ];
  }

  Future<List<String>> extractImports(String filePath) async {
    final file = File(filePath);
    final lines = await file.readAsLines();
    final imports = <String>[];
    for (var line in lines) {
      final match = RegExp(r'import\s+"([^"]+)"').firstMatch(line);
      if (match != null) {
        imports.add(match.group(1)!);
      }
    }
    return imports;
  }

  @override
  Map<String, List<String>> get buildExtensions => {
        join(rootDirectory, '{{}}.proto'): [
          '$outputDirectory/{{}}.pb.dart',
          '$outputDirectory/{{}}.pbenum.dart',
          '$outputDirectory/{{}}.pbjson.dart',
          '$outputDirectory/{{}}.pbserver.dart',
        ],
      };

  final kDefaultProtocVersion = '27.2';
  final kDefaultProtocPluginVersion = '21.1.2';
  final kDefaultProtoRootDirectory = 'proto/';
  final kDefaultProtoPaths = ['proto/'];
  final kDefaultDartOutputDirectory = 'lib/src/proto/';
  final kDefaultUseInstalledProtoc = false;
  final kDefaultPrecompileProtocPlugin = true;
}
