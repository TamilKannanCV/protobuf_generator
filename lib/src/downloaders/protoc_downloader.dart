import 'dart:async';
import 'dart:ffi';
import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart' as path;
import 'package:protobuf_generator/src/utils/file_utils.dart';
import 'package:protobuf_generator/src/utils/process_utils.dart';

import '../run_once_process.dart';

class ProtocDownloader {
  static final Directory _compilerDirectory = Directory(path.join(FileUtils.temporaryDirectory.path, 'compiler'));

  static Uri _protocUriFromVersion(String version) {
    String platformString;
    if (Platform.isWindows) {
      platformString = Abi.current() == Abi.windowsIA32 ? 'win32' : 'win64';
    } else if (Platform.isMacOS) {
      platformString = Abi.current() == Abi.macosArm64 ? 'osx-aarch_64' : 'osx-x86_64';
    } else if (Platform.isLinux) {
      platformString = Abi.current() == Abi.linuxArm64 ? 'linux-aarch_64' : 'linux-x86_64';
    } else {
      throw UnsupportedError('Build platform not supported.');
    }
    return Uri.parse(
        'https://github.com/protocolbuffers/protobuf/releases/download/v$version/protoc-$version-$platformString.zip');
  }

  static String _protocExecutableName() {
    return Platform.isWindows ? 'protoc.exe' : 'protoc';
  }

  static final RunOnceProcess _fetchProtoc = RunOnceProcess();

  static Future<File> fetchProtoc(String version) async {
    final versionDirectory = Directory(path.join(
      _compilerDirectory.path,
      'v${version.replaceAll('.', '_')}',
    ));
    final protoc = File(
      path.join(versionDirectory.path, 'bin', _protocExecutableName()),
    );
    await _fetchProtoc.executeOnce(() async {
      log.info("\nDownloading protobuf compiler (protoc) of version v$version");

      await FileUtils.unzipUri(_protocUriFromVersion(version), versionDirectory);

      await ProcessUtils.addRunnableFlag(protoc);
      return true;
    });
    return protoc;
  }
}
