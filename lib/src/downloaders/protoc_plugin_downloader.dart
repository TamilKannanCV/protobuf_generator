import 'dart:io';
import 'package:build/build.dart';
import 'package:path/path.dart' as path;
import 'package:protobuf_generator/src/utils/file_utils.dart';
import 'package:protobuf_generator/src/utils/process_utils.dart';

import '../run_once_process.dart';

class ProtocPluginDownloader {
  static final Directory _pluginDirectory = Directory(path.join(FileUtils.temporaryDirectory.path, 'plugin'));

  static Uri _protocPluginUriFromVersion(String? version) {
    return Uri.parse('https://github.com/google/protobuf.dart/archive/refs/tags/protoc_plugin-v$version.zip');
  }

  static String _protoPluginName() {
    return Platform.isWindows ? 'protoc-gen-dart.bat' : 'protoc-gen-dart';
  }

  static final RunOnceProcess _unpack = RunOnceProcess();
  static final RunOnceProcess _precompile = RunOnceProcess();

  static Future<File> fetchProtocPlugin(String version, bool precompileProtocPlugin) async {
    const packages = ['protoc_plugin', 'protobuf'];

    final versionDirectory = Directory(path.join(_pluginDirectory.path, 'v${version.replaceAll('.', '_')}'));
    final protocPluginPackageDirectory = Directory(path.join(
      versionDirectory.path,
      'protobuf.dart-protoc_plugin-v$version',
    ));

    final protocPluginDirectory = Directory(
      path.join(
        protocPluginPackageDirectory.path,
        'protoc_plugin',
      ),
    );

    final protocPlugin = File(
      path.join(
        protocPluginDirectory.path,
        'bin',
        _protoPluginName(),
      ),
    );

    await _unpack.executeOnce(() async {
      try {
        if (!await versionDirectory.exists()) {
          await FileUtils.unzipUri(
            _protocPluginUriFromVersion(version),
            versionDirectory,
            (file) => packages.contains(path.split(file.name)[1]),
          );

          await Future.wait(
            packages.map(
              (pkg) => ProcessUtils.runSafely(
                'dart',
                ['pub', 'get'],
                workingDirectory: path.join(protocPluginPackageDirectory.path, pkg),
              ),
            ),
          );

          await ProcessUtils.addRunnableFlag(protocPlugin);
        }
        return true;
      } catch (ex) {
        log.severe("Failed to unpack protoc plugin with $ex.");
        return false;
      }
    });

    if (precompileProtocPlugin) {
      const precompiledName = "precompiled.exe";
      final precompiledProtocPlugin = File(
        path.join(
          protocPluginDirectory.path,
          precompiledName,
        ),
      );
      await _precompile.executeOnce(() async {
        if (!await precompiledProtocPlugin.exists()) {
          await ProcessUtils.runSafely(
            'dart',
            [
              'compile',
              'exe',
              'bin/protoc_plugin.dart',
              '-o',
              precompiledName,
            ],
            workingDirectory: protocPluginDirectory.path,
          );

          await ProcessUtils.addRunnableFlag(precompiledProtocPlugin);
        }
        return true;
      });
      return precompiledProtocPlugin;
    } else {
      return protocPlugin;
    }
  }
}
