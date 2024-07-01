import 'dart:io';

import 'package:build/build.dart';
import 'package:path/path.dart';

import '../run_once_process.dart';
import '../utils/file_utils.dart';

class GoogleApisDownloader {
  static final Directory _googleapisDirectory =
      Directory(join(FileUtils.temporaryDirectory.path, "googleapis"));

  static Uri _googleapisProtoUriVersion() {
    return Uri.parse(
        'https://github.com/googleapis/api-common-protos/archive/refs/heads/main.zip');
  }

  static final RunOnceProcess _fetchProtoc = RunOnceProcess();

  static Future<String> fetchProtoGoogleApis(String version) async {
    await _fetchProtoc.executeOnce(() async {
      log.info("\nDownloading googleapis for protobuf of version v$version");

      await FileUtils.unzipUri(
          _googleapisProtoUriVersion(), _googleapisDirectory);

      return true;
    });
    return join(_googleapisDirectory.path, "api-common-protos-main");
  }
}
