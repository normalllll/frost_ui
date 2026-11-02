import 'dart:convert';
import 'dart:io';

import 'model.dart';
import 'project.dart' show dataPrefix;

/// Runs `tool/check_tokens.dart --report` of the repository that holds this
/// tool, in [root], and turns each reported literal into a finding.
/// Returns null with a message in [error] when the audit cannot run.
Future<List<Finding>> scanTokens(String root, String toolRepository) async {
  final script = File('$toolRepository/tool/check_tokens.dart');
  if (!script.existsSync()) {
    throw StateError('missing ${script.path}');
  }
  final result = await Process.run(
    Platform.resolvedExecutable,
    [script.path, '--report'],
    workingDirectory: root,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'check_tokens.dart --report exited ${result.exitCode}: ${result.stderr}',
    );
  }
  final pattern =
      RegExp(r'^packages/(frost_ui|frost_data)/lib/src/(.+?):(\d+): (\w+): ');
  final findings = <Finding>[];
  for (final line in const LineSplitter().convert('${result.stdout}')) {
    final match = pattern.firstMatch(line.replaceAll('\\', '/'));
    if (match == null) continue;
    findings.add(
      Finding(
        'tokens',
        '${match.group(1) == 'frost_data' ? dataPrefix : ''}${match.group(2)!}',
        int.parse(match.group(3)!),
        '-',
        match.group(4)!,
      ),
    );
  }
  return findings;
}
