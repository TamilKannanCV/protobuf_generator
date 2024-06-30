import 'dart:io';

class ProcessError extends Error {
  final String executable;
  final List<String> arguments;
  final ProcessResult result;

  ProcessError(this.executable, this.arguments, this.result);

  @override
  String toString() {
    return '''
Process finished with exit code ${result.exitCode}:
${result.stderr}
''';
  }
}
