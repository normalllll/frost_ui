import 'dart:io';

void main() {
  final script = File.fromUri(Platform.script.resolve('check_tokens.dart'))
      .path;
  final temp = Directory.systemTemp.createTempSync('frost-token-test-');
  try {
    final source = File(temp.path + '/packages/frost_ui/lib/src/fixture.dart')
      ..createSync(recursive: true);
    final cases = <String, List<int>>{
      'EdgeInsets.symmetric(horizontal: 9, vertical: 5)': [0, 0, 2, 0, 0],
      'SizedBox(width: free / 2 + 8, height: 12 * scale, child: SizedBox(width: 18, child: Border.all(width: 2)))':
          [0, 0, 2, 0, 0],
      'EdgeInsetsDirectional.fromSTEB(inset, 4, math.max(0, inset - 8), gap / 2)':
          [0, 0, 2, 0, 0],
      'EdgeInsets.only(left: flag ? 12 : 8, right: 4 / scale)': [0, 0, 2, 0, 0],
      'EdgeInsets.all(math.max(64, 8 + 30 + 4 + labelHeight + 8))': [
        0,
        0,
        4,
        0,
        0,
      ],
      '// EdgeInsets.all(8)\nText("SizedBox(width: 20)")': [0, 0, 0, 0, 0],
      'BorderRadius.circular(16); Radius.circular(8); Colors.red; Color(0xFFFFFFFF);':
          [2, 2, 0, 0, 0],
      'TextStyle(fontSize: 14, fontWeight: enabled ? FontWeight.w500 : FontWeight.w400);':
          [0, 0, 0, 3, 0],
      'CircularProgressIndicator.adaptive(); LinearProgressIndicator(value: .5);':
          [0, 0, 0, 0, 2],
      'MyCircularProgressIndicator(); FrostProgressBar(value: .5); Colors.transparent;':
          [0, 0, 0, 0, 0],
      '/* nested /* Color(0xFF000000) */ TextStyle(fontSize: 18) */': [
        0,
        0,
        0,
        0,
        0,
      ],
    };
    for (final sample in cases.entries) {
      source.writeAsStringSync(sample.key);
      ProcessResult run(List<String> args) => Process.runSync(
        Platform.resolvedExecutable,
        [script, ...args],
        workingDirectory: temp.path,
      );
      final result = run(['--report']);
      final actual = [
        for (final name in ['radius', 'color', 'spacing', 'text', 'progress'])
          int.parse(
            RegExp(
              '^' + name + r': (\d+)$',
              multiLine: true,
            ).firstMatch(result.stdout as String)!.group(1)!,
          ),
      ];
      if (actual.join(',') != sample.value.join(',') || result.exitCode != 0)
        throw StateError(
          sample.key +
              ': ' +
              result.stdout.toString() +
              result.stderr.toString(),
        );
      final expected = actual.any((n) => n > 0) ? 1 : 0;
      if (run([]).exitCode != expected ||
          run(['--strict']).exitCode != expected)
        throw StateError('CLI mode ' + sample.key);
    }
    print('PASS: 11 real scanner fixtures and report/default/strict exits.');
  } finally {
    temp.deleteSync(recursive: true);
  }
}
