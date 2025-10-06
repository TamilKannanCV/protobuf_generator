import 'dart:async';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart';
import 'package:protobuf_generator/src/downloaders/github_repo_downloader.dart';
import 'package:protobuf_generator/src/downloaders/googleapis_downloader.dart';
import 'package:protobuf_generator/src/downloaders/protoc_plugin_downloader.dart';
import 'package:protobuf_generator/src/extensions/map_extensions.dart';
import 'package:protobuf_generator/src/utils/process_utils.dart';
import 'package:yaml/yaml.dart';

import 'downloaders/protoc_downloader.dart';

class ProtobufGenerator implements Builder {
  ProtobufGenerator(this.options) {
    final config = options.config;
    protobufVersion =
        config.getOrNull<String>('protobuf_version') ?? kDefaultProtocVersion;
    protocPluginVersion = config.getOrNull<String>('protoc_plugin_version') ??
        kDefaultProtocPluginVersion;
    rootDirectory = config.getOrNull<String>('proto_root_dir') ??
        kDefaultProtoRootDirectory;
    protoPaths = (config.getOrNull<YamlList>('proto_paths'))
            ?.nodes
            .map((e) => e.value as String)
            .toList() ??
        [];
    outputDirectory = config.getOrNull<String>('dart_path') ??
        config.getOrNull<String>('dart_out_dir') ??
        kDefaultDartOutputDirectory;
    useInstalledProtoc = config.getOrNull<bool>('use_installed_protoc') ??
        kDefaultUseInstalledProtoc;
    precompileProtocPlugin =
        config.getOrNull<bool>('precompile_protoc_plugin') ??
            kDefaultPrecompileProtocPlugin;
    generateDescriptorFile =
        config.getOrNull<bool>('generate_descriptor_file') ??
            kDefaultGenerateDescriptorFile;

    githubRepos = [];
    final githubReposConfig = config.getOrNull<YamlList>('github_repos');
    if (githubReposConfig != null) {
      for (final repoNode in githubReposConfig.nodes) {
        if (repoNode.value is YamlMap) {
          final repoMap = repoNode.value as YamlMap;
          githubRepos.add(GitHubRepoConfig(
            url: repoMap['url'] as String,
            branch: repoMap['branch'] as String? ?? 'main',
            subPath: repoMap['sub_path'] as String?,
          ));
        } else if (repoNode.value is String) {
          githubRepos.add(GitHubRepoConfig(url: repoNode.value as String));
        }
      }
    }
  }

  final BuilderOptions options;
  late String protobufVersion;
  late String protocPluginVersion;
  late String rootDirectory;
  late List<String> protoPaths;
  late String outputDirectory;
  late bool useInstalledProtoc;
  late bool precompileProtocPlugin;
  late bool generateDescriptorFile;
  late List<GitHubRepoConfig> githubRepos;

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final protoc = useInstalledProtoc
        ? File('protoc')
        : await ProtocDownloader.fetchProtoc(protobufVersion);
    final protocPlugin = useInstalledProtoc
        ? File('')
        : await ProtocPluginDownloader.fetchProtocPlugin(
            protocPluginVersion, precompileProtocPlugin);

    if (!protoPaths.contains(rootDirectory)) {
      protoPaths.insert(0, rootDirectory);
    }

    final googleApisPaths = await GoogleApisDownloader.fetchProtoGoogleApis();
    protoPaths.addAll(googleApisPaths);

    // Download and add GitHub repositories
    for (final repoConfig in githubRepos) {
      final repoPath = await GitHubRepoDownloader.fetchGitHubRepo(
        repoConfig.url,
        branch: repoConfig.branch,
        subPath: repoConfig.subPath,
      );

      // Add the proto subdirectory if it exists, otherwise add the repo root
      final protoSubDir = join(repoPath, 'proto');
      if (await Directory(protoSubDir).exists()) {
        protoPaths.add(protoSubDir);
      } else {
        protoPaths.add(repoPath);
      }
    }

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
  /// This method generates arguments to match the command:
  /// protoc -I proto/ --dart_out=generated/ $(find proto/ -name "*.proto")
  ///
  /// Google APIs proto files and Google protobuf types are automatically
  /// downloaded and included in the proto paths, so they follow the same pattern.
  /// This includes common types like google/type/decimal.proto, google/protobuf/timestamp.proto, etc.
  ///
  /// GitHub repositories specified in the configuration are also downloaded
  /// and included in the proto paths.
  ///
  /// The proto_paths configuration can be empty if you only want to use
  /// Google APIs and/or GitHub repositories without any local proto files.
  ///
  /// If [generateDescriptorFile] is true, it includes the necessary arguments
  /// to generate a descriptor file with imports included.
  ///
  /// If [protocPlugin] has a valid path, it adds the plugin argument for the Dart
  /// protoc plugin.
  Future<List<String>> collectProtocArguments(
      File protocPlugin, String inputPath) async {
    log.warning('Generating protobuf files for $inputPath');
    final args = <String>[];

    if (generateDescriptorFile) {
      args.addAll([
        '--include_imports',
        '--descriptor_set_out=$outputDirectory/descriptor.desc',
      ]);
    }

    // Add include paths for proto directories
    for (final protoPath in protoPaths) {
      args.add('-I$protoPath');
    }

    if (protocPlugin.path.isNotEmpty) {
      args.add("--plugin=protoc-gen-dart=${protocPlugin.path}");
    }

    args.add("--dart_out=$outputDirectory");

    final protoFiles = <String>[];

    for (final protoPath in protoPaths) {
      // Skip Google APIs directory and Google protobuf src directory - they're only for imports
      if (protoPath.contains('googleapis') ||
          protoPath.contains('protobuf/src') ||
          protoPath.contains('protobuf-main/src')) {
        continue;
      }

      final dir = Directory(protoPath);
      if (await dir.exists()) {
        final files = dir
            .listSync(recursive: true)
            .where((entity) => entity is File && entity.path.endsWith('.proto'))
            .where((entity) {
              // Filter out all files from google/protobuf directory
              final filePath = entity.path;
              return !filePath.contains('google/protobuf/');
            })
            .map((entity) => entity.path)
            .toList();
        protoFiles.addAll(files);
      }
    }

    // Add GitHub repo proto files (non-Google APIs)
    // Note: GitHub repos are already downloaded and added to protoPaths in the build method
    // We just need to get proto files from the paths that are not Google APIs

    // If no proto files found, use the input file (unless it's from google/protobuf)
    if (protoFiles.isEmpty && inputPath.endsWith('.proto')) {
      if (!inputPath.contains('google/protobuf/')) {
        protoFiles.add(inputPath);
      }
    }

    args.addAll(protoFiles);

    return args;
  }

  @override
  Map<String, List<String>> get buildExtensions {
    // If no local proto paths are configured, we still need some build extensions
    // to trigger the builder. Use the root directory as fallback.
    final effectiveRootDir =
        protoPaths.isNotEmpty ? protoPaths.first : rootDirectory;

    return {
      join(effectiveRootDir, '{{}}.proto'): [
        '$outputDirectory/{{}}.pb.dart',
        '$outputDirectory/{{}}.pbenum.dart',
        '$outputDirectory/{{}}.pbjson.dart',
        '$outputDirectory/{{}}.pbserver.dart',
      ],
    };
  }

  final kDefaultProtocVersion = '27.2';
  final kDefaultProtocPluginVersion = '21.1.2';
  final kDefaultProtoRootDirectory = 'proto/';
  final kDefaultDartOutputDirectory = 'lib/src/proto/';
  final kDefaultUseInstalledProtoc = false;
  final kDefaultPrecompileProtocPlugin = true;
  final kDefaultGenerateDescriptorFile = false;
}

class GitHubRepoConfig {
  const GitHubRepoConfig({
    required this.url,
    this.branch = 'main',
    this.subPath,
  });

  /// The GitHub repository URL.
  /// Supported formats:
  /// - https://github.com/owner/repo
  /// - https://github.com/owner/repo.git
  /// - git@github.com:owner/repo.git
  /// - https://custom.github.com/owner/repo (GitHub Enterprise)
  /// - git@custom.github.com:owner/repo.git (GitHub Enterprise)
  final String url;

  /// The branch or tag to clone (defaults to 'main').
  final String branch;

  /// Optional subdirectory within the repository to use as the proto root.
  /// If not specified, the repository root will be used.
  final String? subPath;
}
