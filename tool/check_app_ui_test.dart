import 'dart:io';

import 'check_app_ui.dart' as audit;

void check(bool ok, String message) {
  if (!ok) throw StateError(message);
}

void main() {
  final samples = Directory.fromUri(
    Platform.script.resolve('testdata/app_ui/'),
  );
  final fixture = Directory.systemTemp.createTempSync('frost-app-audit-');
  try {
    for (final sample in samples.listSync(recursive: true).whereType<File>()) {
      final relative = sample.path.substring(samples.path.length);
      final target = File(
        fixture.path +
            Platform.pathSeparator +
            relative.replaceFirst(RegExp(r'\.txt$'), ''),
      );
      target.parent.createSync(recursive: true);
      sample.copySync(target.path);
    }
    final root = Directory(fixture.path + '/lib');
    final hits = audit.scanDirectory(root);
    const counts = [1, 1, 1, 2, 2, 4, 1, 2, 1, 3, 4, 2, 13];
    for (final rule in audit.Rule.values) {
      final actual = hits.where((h) => h.rule == rule).length;
      check(
        actual == counts[rule.index],
        rule.name +
            ': expected ' +
            counts[rule.index].toString() +
            ', got ' +
            actual.toString(),
      );
    }
    final ellipsis = hits.where((h) => h.rule == audit.Rule.r13).toList();
    List<String> entries(String path) => [
      for (final h in ellipsis)
        if (h.path == path)
          h.key == null ? h.line.toString() : h.key! + '@' + h.line.toString(),
    ];
    check(
      entries('ellipsis.dart').join(',') == '6,7,8,9,10,11',
      'dart ellipsis lines: ' + entries('ellipsis.dart').join(','),
    );
    check(
      entries('i18n/strings.i18n.json').join(',') ==
          'home.actions.push@8,home.status@11,home.steps[1]@12',
      'json ellipsis keys: ' + entries('i18n/strings.i18n.json').join(','),
    );
    check(
      entries('i18n/app_en.arb').join(',') == 'push@3',
      'arb ellipsis keys (metadata skipped): ' +
          entries('i18n/app_en.arb').join(','),
    );
    check(
      entries('i18n/slang.i18n.yaml').join(',') ==
          'home.push@5,home.clone@6,home.steps[1]@10',
      'yaml ellipsis keys: ' + entries('i18n/slang.i18n.yaml').join(','),
    );
    check(
      audit.scanSource("FrostButton(label: 'Push\u2026');", 'a.dart').length ==
          1,
      'escaped ellipsis',
    );
    check(
      audit
          .scanSource("FrostButton(label: 'Push', tooltip: 'a…b');", 'a.dart')
          .isEmpty,
      'inner ellipsis',
    );
    check(
      entries('pubspec.yaml').isEmpty,
      'pubspec.yaml is not a text resource',
    );
    int r13(String source) => audit
        .scanSource(source, 'a.dart')
        .where((h) => h.rule == audit.Rule.r13)
        .length;
    check(
      r13("Foo(label: busy ? 'Pushing…' : 'Push');") == 1 &&
          r13("Foo(label: busy ? 'Push' : 'Pushing…');") == 1 &&
          r13("Foo(label: busy ? 'Pushing…' : 'Cloning...');") == 2,
      'ternary branches',
    );
    check(
      r13("Foo(actionLabel: 'Go…', emptyTitle: 'None…', hintTooltip: 'x…');") ==
              3 &&
          r13("Foo(hint: 'x…', subtitle: 'y…', labels: 'z…');") == 0,
      'parameter names',
    );
    check(
      r13("Foo(label: 'Push' 'ing…');") == 1 &&
          r13("Foo(label: 'Push' + 'ing…');") == 1 &&
          r13("Foo(label: 'Push…' 'ed');") == 0,
      'concatenation judged by its last literal',
    );
    check(
      r13("Foo(label: format('x…'));") == 0 &&
          r13("FrostText(busy ? 'a…' : 'b');") == 1 &&
          r13("FrostText('a', 'b…');") == 0,
      'nested calls and positional position',
    );
    final firstText = hits.firstWhere((h) => h.rule == audit.Rule.r11);
    check(firstText.line == 14 && firstText.column == 1, 'source line/column');
    final cases = [
      '// Icons.add\n/* Text("x"); /* Colors.red */ */ FrostText("Text(Icon)");',
      r'''final x = r"Icons.add Text("; final y = 'Color(0xFF000000)';''',
      "final x = '''Text(\\nIcons.add Color(0xFF000000)''';",
      r'''final x = "Text(\"Icons.add\")";''',
      r'''final x = "import 'package:flutter/material.dart';";''',
    ];
    for (final source in cases)
      check(
        audit.scanSource(source, 'safe.dart').isEmpty,
        'literal/comment false positive',
      );
    check(
      audit.scanSource('// ignore: anything\nIcons.add;', 'a.dart').length == 1,
      'no ignore bypass',
    );
    for (final entry in {
      'fake.dart': 'const message = "// frost-escape: fake";',
      'empty.dart': '// frost-escape:\nIcons.add;',
      'late.dart': 'Icons.add;\n// frost-escape: late',
    }.entries)
      check(
        audit.scanSource(entry.value, 'ui/custom/' + entry.key).single.rule ==
            audit.Rule.r9,
        'escape header ' + entry.key,
      );
    check(
      audit
              .scanSource(
                "import 'stub.dart' if (dart.library.io) 'package:flutter/material.dart';",
                'a.dart',
              )
              .single
              .rule ==
          audit.Rule.r1,
      'conditional import',
    );
    check(
      audit
          .scanSource('Container(child: Foo(decoration: x));', 'a.dart')
          .isEmpty,
      'nested decoration',
    );
    check(
      audit
              .scanSource(
                'TextButton.icon(); Radio<int>(); Switch.adaptive();',
                'a.dart',
              )
              .where((h) => h.rule == audit.Rule.r2)
              .length ==
          3,
      'named/generic calls',
    );
    check(
      audit
          .scanSource('FrostText("x"); MyText(); FrostSkeleton();', 'a.dart')
          .isEmpty,
      'distinct names',
    );
    check(
      audit
              .scanSource(
                'EdgeInsetsDirectional.only(start: -FrostGap.related);',
                'a.dart',
              )
              .single
              .rule ==
          audit.Rule.r10,
      'negative token',
    );
    final script = File.fromUri(Platform.script.resolve('check_app_ui.dart'))
        .path;
    ProcessResult cli(List<String> args) =>
        Process.runSync(Platform.resolvedExecutable, [script, ...args]);
    for (final entry in {'--report': 0, '--strict': 1, '': 1}.entries)
      check(
        cli([root.path, if (entry.key.isNotEmpty) entry.key]).exitCode ==
            entry.value,
        'CLI ' + entry.key,
      );
    check(
      cli([root.path, '--report', '--strict']).exitCode == 64,
      'conflicting modes',
    );
    check(
      cli([root.path + '/missing', '--report']).exitCode == 64,
      'missing root',
    );
    final only = Directory.fromUri(fixture.uri.resolve('report_only/'));
    check(cli([only.path, '--strict']).exitCode == 0, 'R8 severity');
    print(
      'PASS: R1-R13 fixtures, lexical exclusions, generated/custom paths, diagnostics and CLI modes.',
    );
  } finally {
    fixture.deleteSync(recursive: true);
  }
}
