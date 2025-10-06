import 'dart:convert';
import 'dart:io';

import 'package:build/build.dart';
import 'package:protobuf_generator/src/process_error.dart';

class ProcessUtils {
  static Future<void> addRunnableFlag(File file) async {
    if (!Platform.isWindows) {
      await runSafely('chmod', ['+x', file.absolute.path]);
    }
  }

  static Future<ProcessResult> runSafely(
      String executable, List<String> arguments,
      {String? workingDirectory,
      Map<String, String>? environment,
      bool includeParentEnvironment = true,
      bool runInShell = false,
      Encoding? stdoutEncoding = systemEncoding,
      Encoding? stderrEncoding = systemEncoding}) async {
    log.warning("\tRunning command: $executable ${arguments.join(' ')}");
    final result = await Process.run(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      includeParentEnvironment: includeParentEnvironment,
      runInShell: runInShell,
      stdoutEncoding: stdoutEncoding,
      stderrEncoding: stderrEncoding,
    );
    if (result.exitCode != 0) throw ProcessError(executable, arguments, result);
    return result;
  }
}
