import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart';
import 'package:protobuf_generator/src/downloaders/googleapis_downloader.dart';
import 'package:protobuf_generator/src/downloaders/protoc_plugin_downloader.dart';
import 'package:protobuf_generator/src/extensions/map_extensions.dart';
import 'package:protobuf_generator/src/utils/process_utils.dart';
import 'package:yaml/yaml.dart';

import 'downloaders/protoc_downloader.dart';

class ProtobufGenerator implements Builder {
  ProtobufGenerator(this.options) {
    final config = options.config;
    protobufVersion = config.getOrNull<String>('protobuf_version') ?? kDefaultProtocVersion;
    protocPluginVersion = config.getOrNull<String>('protoc_plugin_version') ?? kDefaultProtocPluginVersion;
    rootDirectory = config.getOrNull<String>('proto_root_dir') ?? kDefaultProtoRootDirectory;
    protoPaths = (config.getOrNull<YamlList>('proto_paths'))?.nodes.map((e) => e.value as String).toList() ?? kDefaultProtoPaths;
    outputDirectory = config.getOrNull<String>('dart_out_dir') ?? kDefaultDartOutputDirectory;
    useInstalledProtoc = config.getOrNull<bool>('use_installed_protoc') ?? kDefaultUseInstalledProtoc;
    useInstalledProtocPlugin = config.getOrNull<bool>('use_installed_protoc_plugin') ?? kDefaultUseInstalledProtocPlugin;
    fetchGoogleApis = config.getOrNull<bool>('fetch_google_apis') ?? kDefaultUseInstalledProtoc;
    precompileProtocPlugin = config.getOrNull<bool>('precompile_protoc_plugin') ?? kDefaultPrecompileProtocPlugin;
    generateDescriptorFile = config.getOrNull<bool>('generate_descriptor_file') ?? kDefaultGenerateDescriptorFile;
  }

  final BuilderOptions options;
  late String protobufVersion;
  late String protocPluginVersion;
  late String rootDirectory;
  late List<String> protoPaths;
  late String outputDirectory;
  late bool useInstalledProtoc;
  late bool useInstalledProtocPlugin;
  late bool fetchGoogleApis;
  late bool precompileProtocPlugin;
  late bool generateDescriptorFile;

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final protoc = useInstalledProtoc ? File('protoc') : await ProtocDownloader.fetchProtoc(protobufVersion);
    final protocPlugin = useInstalledProtocPlugin ? null : await ProtocPluginDownloader.fetchProtocPlugin(protocPluginVersion, precompileProtocPlugin);
    if (fetchGoogleApis) protoPaths.add(await GoogleApisDownloader.fetchProtoGoogleApis("1.0"));

    final inputPath = normalize(buildStep.inputId.path);

    await buildStep.readAsString(buildStep.inputId);

    await Directory(outputDirectory).create(recursive: true);
    final args = await collectProtocArguments(protocPlugin, inputPath);
    await ProcessUtils.runSafely(
      protoc.path,
      args,
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

  /// Generates the necessary arguments for the protobuf compiler.
  ///
  /// If [generateDescriptorFile] is true, it includes the necessary arguments
  /// to generate a descriptor file with imports included.
  ///
  /// If [protocPlugin] has a valid path, it adds the plugin argument for the Dart
  /// protoc plugin.
  ///
  /// Adds the output directory for the Dart generated files.
  ///
  /// Adds the include paths for the proto files.
  ///
  /// Collects all `.proto` files from the specified [protoPaths], excluding those
  /// that contain 'googleapis' in their path, and adds them to the arguments.
  Future<List<String>> collectProtocArguments(File? protocPlugin, String inputPath) async {
    log.warning('Generating protobuf files for $inputPath');
    final args = <String>[];

    if (generateDescriptorFile) {
      args.addAll([
        '--include_imports',
        '--descriptor_set_out=$outputDirectory/descriptor.desc',
      ]);
    }

    if (protocPlugin != null) {
      args.add("--plugin=protoc-gen-dart=${protocPlugin.path}");
    }

    args.add("--dart_out=${join('.', outputDirectory)}");

    args.addAll(protoPaths.map((protoPath) => '-I=${join('.', protoPath)}'));

    final imports = await extractGoogleImports(inputPath);

    final protoFiles = protoPaths.expand((protoPath) {
      final dir = Directory(protoPath);
      return dir
          .listSync(recursive: true)
          .where((entity) => entity is File && entity.path.endsWith('.proto') && !entity.path.contains('googleapis'))
          .map((entity) => join('.', entity.path));
    }).toSet()
      ..addAll(imports);

    args.addAll(protoFiles);

    return args;
  }

  Future<List<String>> extractGoogleImports(String filePath) async {
    final file = File(filePath);
    final lines = await file.readAsLines();
    final imports = <String>[];
    for (var line in lines) {
      final match = RegExp(r'import\s+"([^"]+)"').firstMatch(line);
      if (match != null && (match.group(1)?.contains('google') ?? false)) {
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
  final kDefaultUseInstalledProtocPlugin = false;
  final kDefaultFetchGoogleApis = false;
  final kDefaultPrecompileProtocPlugin = true;
  final kDefaultGenerateDescriptorFile = false;
}
