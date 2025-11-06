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

/// A build_runner builder that generates Dart code from Protocol Buffer definitions.
///
/// This builder integrates with the Dart build system to automatically generate
/// `.pb.dart`, `.pbenum.dart`, `.pbjson.dart`, and `.pbserver.dart` files from
/// `.proto` files. It handles downloading necessary tools (protoc compiler and
/// Dart plugin) and manages proto file dependencies including Google APIs and
/// GitHub repositories.
class ProtobufGenerator implements Builder {
  ProtobufGenerator(this.options) {
    final config = options.config;
    protobufVersion = config.getOrNull<String>('protobuf_version') ?? kDefaultProtocVersion;
    protocPluginVersion = config.getOrNull<String>('protoc_plugin_version') ?? kDefaultProtocPluginVersion;
    rootDirectory = config.getOrNull<String>('proto_root_dir') ?? kDefaultProtoRootDirectory;
    protoPaths = (config.getOrNull<YamlList>('proto_paths'))?.nodes.map((e) => e.value as String).toList() ?? [];
    outputDirectory = config.getOrNull<String>('dart_path') ??
        config.getOrNull<String>('dart_out_dir') ??
        kDefaultDartOutputDirectory;
    useInstalledProtoc = config.getOrNull<bool>('use_installed_protoc') ?? kDefaultUseInstalledProtoc;
    precompileProtocPlugin = config.getOrNull<bool>('precompile_protoc_plugin') ?? kDefaultPrecompileProtocPlugin;
    generateDescriptorFile = config.getOrNull<bool>('generate_descriptor_file') ?? kDefaultGenerateDescriptorFile;
    generateGrpc = config.getOrNull<bool>('generate_grpc') ?? kDefaultGenerateGrpc;

    githubRepos = [];
    final githubReposConfig = config.getOrNull<YamlList>('github_repos');
    if (githubReposConfig != null) {
      for (final repoNode in githubReposConfig.nodes) {
        if (repoNode.value is YamlMap) {
          final repoMap = repoNode.value as YamlMap;

          List<String>? paths;
          if (repoMap.containsKey('paths')) {
            final pathsValue = repoMap['paths'];
            if (pathsValue is YamlList) {
              paths = pathsValue.nodes.map((e) => e.value as String).toList();
            }
          }

          githubRepos.add(GitHubRepoConfig(
            url: repoMap['url'] as String,
            branch: repoMap['branch'] as String? ?? 'main',
            paths: paths,
          ));
        } else if (repoNode.value is String) {
          githubRepos.add(GitHubRepoConfig(url: repoNode.value as String));
        }
      }
    }
  }

  final BuilderOptions options;

  /// Version of the protoc compiler to download and use.
  late String protobufVersion;

  /// Version of the Dart protoc plugin to download and use.
  late String protocPluginVersion;

  /// Root directory containing proto files (defaults to 'proto/').
  late String rootDirectory;

  /// Base paths used for both proto file discovery and include paths (-I flags).
  late List<String> protoPaths;

  /// Paths added only as include directories for protoc (-I flags).
  /// Files in these paths are not automatically generated unless imported.
  final List<String> includeOnlyPaths = [];

  /// Paths used only for discovering proto files to generate.
  /// These paths are not added as -I flags to avoid duplicate resolution.
  final List<String> generationOnlyPaths = [];

  /// Output directory for generated Dart files.
  late String outputDirectory;

  /// Whether to use system-installed protoc instead of downloading.
  late bool useInstalledProtoc;

  /// Whether to precompile the protoc plugin for faster execution.
  late bool precompileProtocPlugin;

  /// Whether to generate descriptor files with import information.
  late bool generateDescriptorFile;

  /// Whether to generate gRPC service stubs.
  late bool generateGrpc;

  /// GitHub repositories to clone and include in proto paths.
  late List<GitHubRepoConfig> githubRepos;

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    // Fetch or use system protoc compiler
    final protoc = useInstalledProtoc ? File('protoc') : await ProtocDownloader.fetchProtoc(protobufVersion);
    final protocPlugin = useInstalledProtoc
        ? File('')
        : await ProtocPluginDownloader.fetchProtocPlugin(protocPluginVersion, precompileProtocPlugin);

    // Ensure root directory is in proto paths
    if (!protoPaths.contains(rootDirectory)) {
      protoPaths.insert(0, rootDirectory);
    }

    // Download and add Google APIs proto files
    final googleApisPaths = await GoogleApisDownloader.fetchProtoGoogleApis();
    protoPaths.addAll(googleApisPaths);

    // Process GitHub repository configurations
    for (final repoConfig in githubRepos) {
      final repoRootPath = await GitHubRepoDownloader.fetchGitHubRepo(
        repoConfig.url,
        branch: repoConfig.branch,
      );

      // Add proto/ subdirectory as include-only path to resolve imports
      // without generating all files in the repository
      final protoSubDir = join(repoRootPath, 'proto');
      if (await Directory(protoSubDir).exists()) {
        includeOnlyPaths.add(protoSubDir);
      } else {
        includeOnlyPaths.add(repoRootPath);
      }

      // Add specific subdirectories for proto file generation if configured
      if (repoConfig.paths != null && repoConfig.paths!.isNotEmpty) {
        for (final path in repoConfig.paths!) {
          final fullPath = join(repoRootPath, path);
          if (await Directory(fullPath).exists()) {
            generationOnlyPaths.add(fullPath);
          }
        }
      }
    }

    final inputPath = normalize(buildStep.inputId.path);

    await buildStep.readAsString(buildStep.inputId);

    // Ensure output directory exists
    await Directory(outputDirectory).create(recursive: true);

    // Generate protoc arguments and execute compilation
    final args = await collectProtocArguments(protocPlugin, inputPath);
    await ProcessUtils.runSafely(
      protoc.path,
      args,
    );

    // Write generated files to build outputs
    await Future.wait(buildStep.allowedOutputs.map((AssetId out) async {
      var file = loadOutputFile(out);

      // Skip optional gRPC files if they don't exist
      if (file.path.endsWith('.pbgrpc.dart') && !await file.exists()) {
        return;
      }
      await buildStep.writeAsBytes(out, file.readAsBytes());
    }));
  }

  /// Loads the generated output file from the file system.
  File loadOutputFile(AssetId out) => File(out.path);

  /// Constructs command-line arguments for the protoc compiler.
  ///
  /// Generates arguments equivalent to:
  /// ```
  /// protoc -I proto/ --dart_out=generated/ $(find proto/ -name "*.proto")
  /// ```
  ///
  /// This method:
  /// - Adds all include paths (-I flags) from protoPaths and includeOnlyPaths
  /// - Configures output directory and plugin settings
  /// - Discovers all proto files to compile
  /// - Recursively resolves imported dependencies (Google APIs, cross-directory imports)
  /// - Handles descriptor file generation if enabled
  /// - Supports gRPC service generation if enabled
  Future<List<String>> collectProtocArguments(File protocPlugin, String inputPath) async {
    log.warning('Generating protobuf files for $inputPath');
    final args = <String>[];

    if (generateDescriptorFile) {
      args.addAll([
        '--include_imports',
        '--descriptor_set_out=$outputDirectory/descriptor.desc',
      ]);
    }

    // Merge and deduplicate all include paths for -I flags
    final allIncludePaths = {...protoPaths, ...includeOnlyPaths};
    for (final includePath in allIncludePaths) {
      args.add('-I$includePath');
    }

    // Add Dart protoc plugin if available
    if (protocPlugin.path.isNotEmpty) {
      args.add("--plugin=protoc-gen-dart=${protocPlugin.path}");
    }

    // Configure output format with optional gRPC support
    final dartOutOptions = <String>[];
    if (generateGrpc) {
      dartOutOptions.add('grpc');
    }

    final dartOut = dartOutOptions.isNotEmpty
        ? '--dart_out=${dartOutOptions.join(',')}:$outputDirectory'
        : '--dart_out=$outputDirectory';
    args.add(dartOut);

    final protoFiles = <String>{};

    // Discover proto files from all generation paths
    final allGenerationPaths = {...protoPaths.toSet(), ...generationOnlyPaths};

    for (final protoPath in allGenerationPaths) {
      // Skip Google directories; specific imported files will be added by dependency scanner
      if (protoPath.contains('googleapis') ||
          protoPath.contains('protobuf/protobuf-main') ||
          protoPath.contains('protobuf-main/src')) {
        continue;
      }

      final dir = Directory(protoPath);
      if (await dir.exists()) {
        final files = dir
            .listSync(recursive: true)
            .where((entity) => entity is File && entity.path.endsWith('.proto'))
            .map((entity) => entity.path)
            .toList();
        protoFiles.addAll(files);
      }
    }

    // Recursively resolve all imported dependencies
    await _addGoogleProtoImports(protoFiles, allIncludePaths);

    // Fallback to input file if no proto files were discovered
    if (protoFiles.isEmpty && inputPath.endsWith('.proto') && !inputPath.contains('google/protobuf/')) {
      protoFiles.add(inputPath);
    }

    args.addAll(protoFiles);

    return args;
  }

  /// Recursively scans proto files for import statements and resolves dependencies.
  ///
  /// This method ensures all imported proto files are included in generation,
  /// even if they're not in the specified generation paths. This handles:
  /// - Google proto types (google/protobuf/struct.proto, google/type/money.proto, etc.)
  /// - Cross-directory imports within repositories (payments/poa/v1/poa_response.proto)
  /// - Transitive dependencies (imports of imports)
  ///
  /// Uses an import cache to minimize file system operations for frequently
  /// imported files.
  ///
  /// [protoFiles] is modified in-place to add discovered dependencies.
  /// [includePaths] specifies directories to search for imported files.
  Future<void> _addGoogleProtoImports(
    Set<String> protoFiles,
    Set<String> includePaths,
  ) async {
    final processedFiles = <String>{};
    final filesToProcess = protoFiles.toList();
    final importPattern = RegExp(r'import\s+"([^"]+)"');

    // Cache resolved import paths to avoid repeated file existence checks
    final importCache = <String, String>{};

    while (filesToProcess.isNotEmpty) {
      final protoFile = filesToProcess.removeLast();

      // Skip already processed files to avoid infinite loops
      if (processedFiles.contains(protoFile)) {
        continue;
      }
      processedFiles.add(protoFile);

      try {
        final file = File(protoFile);
        if (!await file.exists()) {
          continue;
        }

        // Extract import statements from proto file content
        final content = await file.readAsString();
        final matches = importPattern.allMatches(content);

        for (final match in matches) {
          final importPath = match.group(1);
          if (importPath == null) continue;

          // Skip if already collected
          if (protoFiles.any((f) => f.endsWith(importPath))) {
            continue;
          }

          // Try cache first for performance
          String? fullProtoPath = importCache[importPath];

          if (fullProtoPath == null) {
            // Resolve import by searching through include paths
            for (final includePath in includePaths) {
              fullProtoPath = join(includePath, importPath);
              if (await File(fullProtoPath).exists()) {
                importCache[importPath] = fullProtoPath;
                break;
              }
              fullProtoPath = null;
            }
          }

          // Add to generation list and queue for recursive processing
          if (fullProtoPath != null) {
            protoFiles.add(fullProtoPath);
            filesToProcess.add(fullProtoPath);
          }
        }
      } catch (e) {
        // Silently skip files that can't be read
        continue;
      }
    }
  }

  @override
  Map<String, List<String>> get buildExtensions {
    final effectiveRootDir = protoPaths.isNotEmpty ? protoPaths.first : rootDirectory;

    final extensions = [
      '$outputDirectory/{{}}.pb.dart',
      '$outputDirectory/{{}}.pbenum.dart',
      '$outputDirectory/{{}}.pbjson.dart',
      '$outputDirectory/{{}}.pbserver.dart',
    ];

    if (generateGrpc) {
      extensions.add('$outputDirectory/{{}}.pbgrpc.dart');
    }

    return {
      join(effectiveRootDir, '{{}}.proto'): extensions,
    };
  }

  // Default configuration values
  final kDefaultProtocVersion = '27.2';
  final kDefaultProtocPluginVersion = '21.1.2';
  final kDefaultProtoRootDirectory = 'proto/';
  final kDefaultDartOutputDirectory = 'lib/src/proto/';
  final kDefaultUseInstalledProtoc = false;
  final kDefaultPrecompileProtocPlugin = true;
  final kDefaultGenerateDescriptorFile = false;
  final kDefaultGenerateGrpc = false;
}

/// Configuration for a GitHub repository containing proto files.
class GitHubRepoConfig {
  const GitHubRepoConfig({
    required this.url,
    this.branch = 'main',
    this.paths,
  });

  /// The GitHub repository URL.
  ///
  /// Supported formats:
  /// - `https://github.com/owner/repo`
  /// - `https://github.com/owner/repo.git`
  /// - `git@github.com:owner/repo.git`
  /// - `https://custom.github.com/owner/repo` (GitHub Enterprise)
  /// - `git@custom.github.com:owner/repo.git` (GitHub Enterprise)
  final String url;

  /// The branch or tag to clone. Defaults to 'main'.
  final String branch;

  /// Optional subdirectories within the repository to generate proto files from.
  ///
  /// If `null` or empty, the entire repository will be scanned.
  /// If specified, only proto files in these subdirectories will be generated,
  /// while the repository root is still available for import resolution.
  final List<String>? paths;
}
