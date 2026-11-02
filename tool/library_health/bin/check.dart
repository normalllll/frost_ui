import 'dart:io';

import 'package:frost_library_health/src/cli.dart';

Future<void> main(List<String> arguments) async {
  // tool/library_health/bin/check.dart -> the repository that holds the tool.
  final script = File.fromUri(Platform.script).absolute;
  final repository =
      script.parent.parent.parent.parent.path.replaceAll('\\', '/');
  exitCode = await run(arguments, toolRepository: repository);
}
