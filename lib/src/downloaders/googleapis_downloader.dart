import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart';

import '../run_once_process.dart';
import '../utils/file_utils.dart';

class GoogleApisDownloader {
  static final Directory _googleapisDirectory = Directory(join(FileUtils.temporaryDirectory.path, "googleapis"));
  static final Directory _protobufDirectory = Directory(join(FileUtils.temporaryDirectory.path, "protobuf"));
  static final Directory directory = _googleapisDirectory;

  static Uri _protobufProtoUriVersion() {
    return Uri.parse('https://github.com/protocolbuffers/protobuf/archive/refs/heads/main.zip');
  }

  static final RunOnceProcess _fetchGoogleApis = RunOnceProcess();
  static final RunOnceProcess _fetchProtobuf = RunOnceProcess();

  static Future<List<String>> fetchProtoGoogleApis() async {
    final paths = <String>[];

    await _fetchGoogleApis.executeOnce(() async {
      if (await _googleapisDirectory.exists()) {
        await _googleapisDirectory.delete(recursive: true);
      }

      await _googleapisDirectory.create(recursive: true);

      final result = await Process.run(
        'git',
        ['clone', '--depth', '1', '--branch', 'master', 'https://github.com/googleapis/googleapis.git', 'repo'],
        workingDirectory: _googleapisDirectory.path,
      );

      if (result.exitCode != 0) {
        throw Exception('Git clone failed: ${result.stderr}');
      }

      return true;
    });

    paths.add(join(_googleapisDirectory.path, "repo"));

    await _fetchProtobuf.executeOnce(() async {
      log.info("\nDownloading protobuf repository for Google types");
      await FileUtils.unzipUri(_protobufProtoUriVersion(), _protobufDirectory);
      return true;
    });
    paths.add(join(_protobufDirectory.path, "protobuf-main", "src"));

    return paths;
  }
}
