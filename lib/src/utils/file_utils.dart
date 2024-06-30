import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;

class FileUtils {
  static final Directory temporaryDirectory = Directory(join('.dart_tool', 'build', 'protobuf_generator'));

  static Future<void> unzipUri(Uri uri, Directory target, [bool Function(ArchiveFile file)? test]) async {
    final archive = ZipDecoder().decodeBytes(await http.readBytes(uri));
    for (final file in archive) {
      final filename = file.name;
      if (file.isFile && (test == null || test(file))) {
        final fileHandle = File(join(target.path, filename));
        await fileHandle.create(recursive: true);
        await fileHandle.writeAsBytes(file.content as List<int>);
      }
    }
  }
}
