import 'dart:io';

import 'affected_tests.dart' as tool;

void check(bool ok, String message) {
  if (!ok) throw StateError(message);
}

void write(Directory root, String path, String text) {
  File('${root.path}/$path')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(text);
}

String git(Directory root, List<String> arguments) {
  final result = Process.runSync('git', ['-C', root.path, ...arguments]);
  check(result.exitCode == 0, 'git ${arguments.join(' ')}: ${result.stderr}');
  return (result.stdout as String).trim();
}

/// A library repository and a consumer app; the base is a tree object, so the
/// fixture needs no commit.
(Directory, Directory, String) fixture() {
  final root = Directory.systemTemp.createTempSync('frost-affected-');
  final repository = Directory('${root.path}/repo')..createSync();
  write(repository, 'packages/kit/pubspec.yaml', 'name: kit\n');
  write(
    repository,
    'packages/kit/lib/kit.dart',
    "export 'src/avatar.dart';\nexport 'src/picker.dart';\nexport 'src/row.dart';\n",
  );
  write(repository, 'packages/kit/lib/src/_slot.dart', 'class KitSlot {}\n');
  write(
    repository,
    'packages/kit/lib/src/avatar.dart',
    "import '_slot.dart';\n\nclass KitAvatar {}\n",
  );
  write(
    repository,
    'packages/kit/lib/src/picker.dart',
    "part '_picker_menu.dart';\n\nclass KitPicker {}\n\nvoid showKitPicker() {}\n",
  );
  write(
    repository,
    'packages/kit/lib/src/_picker_menu.dart',
    "part of 'picker.dart';\n\nclass _Menu {}\n",
  );
  write(
    repository,
    'packages/kit/lib/src/row.dart',
    "import 'avatar.dart';\n\nclass KitRow {}\n",
  );
  write(
    repository,
    'packages/kit/lib/src/unrelated.dart',
    'class KitUnrelated {}\n',
  );
  write(
    repository,
    'packages/kit/test/avatar_test.dart',
    "import 'package:kit/kit.dart';\n\nvoid main() => KitAvatar();\n",
  );
  write(
    repository,
    'packages/kit/test/row_test.dart',
    "import 'package:kit/kit.dart';\n\nvoid main() => KitRow();\n",
  );
  write(
    repository,
    'packages/kit/test/picker_test.dart',
    "import 'package:kit/kit.dart';\n\nvoid main() => showKitPicker();\n",
  );
  write(
    repository,
    'packages/kit/test/unrelated_test.dart',
    "import 'package:kit/kit.dart';\n\nvoid main() => KitUnrelated();\n",
  );
  write(repository, 'tool/audit.dart', 'void main() {}\n');
  write(repository, 'tool/audit_test.dart', 'void main() {}\n');
  write(repository, 'docs/notes.md', 'notes\n');
  git(repository, ['init', '--quiet']);
  git(repository, ['add', '-A']);
  final base = git(repository, ['write-tree']);

  final app = Directory('${root.path}/app')..createSync();
  write(
    app,
    'pubspec.yaml',
    'name: app\ndependencies:\n  kit:\n    path: ../repo/packages/kit\n',
  );
  write(app, 'lib/accounts.dart', 'final row = KitRow();\n');
  write(app, 'lib/settings.dart', 'final other = KitUnrelated();\n');
  write(app, 'test/accounts_test.dart', 'void main() => KitAvatar();\n');
  write(app, 'test/settings_test.dart', 'void main() => KitUnrelated();\n');
  return (repository, app, base);
}

Future<void> main() async {
  final (repository, app, base) = fixture();
  try {
    // A private library is tested through its importer; that importer's own
    // importers are analyzed, and tested only with dependents.
    write(
      repository,
      'packages/kit/lib/src/_slot.dart',
      'class KitSlot {}\n\nconst slotSize = 16.0;\n',
    );
    var selection = tool.select(repository.path, base, consumers: [app.path]);
    var kit = selection.packages.single;
    check(
      kit.changedLibraries.single == 'lib/src/_slot.dart',
      'changed libraries: ${kit.changedLibraries}',
    );
    check(
      kit.affectedLibraries.length == 3 &&
          kit.analyze.contains('lib/src/row.dart'),
      'analyzed: ${kit.analyze}',
    );
    check(
      kit.tests.single == 'test/avatar_test.dart',
      'private library tests: ${kit.tests}',
    );
    check(
      kit.totalTests == 4 && !kit.broad,
      'total ${kit.totalTests}, broad ${kit.broad}',
    );
    var consumer = selection.consumers.single;
    check(
      consumer.tests.single == 'test/accounts_test.dart',
      'consumer tests: ${consumer.tests}',
    );
    check(consumer.sources.isEmpty, 'consumer sources: ${consumer.sources}');

    selection = tool.select(
      repository.path,
      base,
      consumers: [app.path],
      dependents: true,
    );
    kit = selection.packages.single;
    check(
      kit.tests.length == 2 && kit.tests.contains('test/row_test.dart'),
      'dependent tests: ${kit.tests}',
    );
    consumer = selection.consumers.single;
    check(
      consumer.sources.single == 'lib/accounts.dart',
      'dependent consumer sources: ${consumer.sources}',
    );

    // A consumer's part file that uses the API is analyzed through its library.
    write(app, 'lib/strings.g.dart', "part 'strings_en_US.g.dart';\n");
    write(
      app,
      'lib/strings_en_US.g.dart',
      "part of 'strings.g.dart';\n\nfinal row = KitRow();\n",
    );
    selection = tool.select(
      repository.path,
      base,
      consumers: [app.path],
      dependents: true,
    );
    consumer = selection.consumers.single;
    check(
      consumer.sources.contains('lib/strings.g.dart') &&
          !consumer.sources.contains('lib/strings_en_US.g.dart'),
      'consumer part sources: ${consumer.sources}',
    );
    File('${app.path}/lib/strings.g.dart').deleteSync();
    File('${app.path}/lib/strings_en_US.g.dart').deleteSync();

    // A part file selects its library; top-level functions count as names.
    write(repository, 'packages/kit/lib/src/_slot.dart', 'class KitSlot {}\n');
    write(
      repository,
      'packages/kit/lib/src/_picker_menu.dart',
      "part of 'picker.dart';\n\nclass _Menu {\n  int get size => 1;\n}\n",
    );
    selection = tool.select(repository.path, base);
    kit = selection.packages.single;
    check(
      kit.affectedLibraries.single == 'lib/src/picker.dart',
      'part library: ${kit.affectedLibraries}',
    );
    check(
      kit.tests.single == 'test/picker_test.dart',
      'part tests: ${kit.tests}',
    );

    // Tool changes select the tool's script test; documents need no checks.
    write(
      repository,
      'packages/kit/lib/src/_picker_menu.dart',
      "part of 'picker.dart';\n\nclass _Menu {}\n",
    );
    write(repository, 'tool/audit.dart', 'void main() {\n  print(1);\n}\n');
    write(repository, 'docs/notes.md', 'more notes\n');
    selection = tool.select(repository.path, base);
    check(
      selection.packages.isEmpty,
      'no package selected: ${selection.packages.map((p) => p.package.name)}',
    );
    check(
      selection.scripts.single == 'tool/audit_test.dart',
      'scripts: ${selection.scripts}',
    );
    check(
      selection.unchecked.single == 'docs/notes.md',
      'unchecked: ${selection.unchecked}',
    );
    write(repository, 'tool/audit.dart', 'void main() {}\n');
    write(repository, 'docs/notes.md', 'notes\n');

    // A changed entry selects the tests of the names whose export changed,
    // not every test that imports it; the entry itself is analyzed.
    write(
      repository,
      'packages/kit/lib/kit.dart',
      "export 'src/avatar.dart';\nexport 'src/picker.dart' show KitPicker;\nexport 'src/row.dart';\n",
    );
    selection = tool.select(repository.path, base);
    kit = selection.packages.single;
    check(
      kit.tests.single == 'test/picker_test.dart',
      'entry export tests: ${kit.tests}',
    );
    check(
      kit.analyze.contains('lib/kit.dart') &&
          !kit.affectedLibraries.contains('lib/kit.dart'),
      'entry analyzed: ${kit.analyze}',
    );
    write(
      repository,
      'packages/kit/lib/kit.dart',
      "export 'src/avatar.dart';\nexport 'src/picker.dart' show KitPicker, showKitPicker;\nexport 'src/row.dart';\n",
    );
    selection = tool.select(repository.path, base);
    check(
      selection.packages.single.tests.single == 'test/picker_test.dart',
      'show list tests: ${selection.packages.single.tests}',
    );
    write(
      repository,
      'packages/kit/lib/kit.dart',
      "export 'src/avatar.dart';\nexport 'src/picker.dart';\nexport 'src/row.dart';\n",
    );

    // Extension members count as names; a consumer's tool scripts are
    // analyzed, never run.
    write(
      repository,
      'packages/kit/lib/src/unrelated.dart',
      'class KitUnrelated {}\n\nextension KitNumber on int {\n  int kitDouble() => this * 2;\n}\n',
    );
    write(app, 'test/number_test.dart', 'void main() => 1.kitDouble();\n');
    write(app, 'tool/preview.dart', 'final preview = KitUnrelated();\n');
    write(app, 'tool/preview_test.dart', 'void main() => KitUnrelated();\n');
    selection = tool.select(repository.path, base, consumers: [app.path]);
    consumer = selection.consumers.single;
    check(
      consumer.tests.containsAll([
            'test/number_test.dart',
            'test/settings_test.dart',
          ]) &&
          !consumer.tests.any((t) => t.startsWith('tool/')),
      'extension consumer tests: ${consumer.tests}',
    );
    check(
      consumer.sources.containsAll([
        'tool/preview.dart',
        'tool/preview_test.dart',
      ]),
      'consumer tool sources: ${consumer.sources}',
    );
    write(
      repository,
      'packages/kit/lib/src/unrelated.dart',
      'class KitUnrelated {}\n',
    );
    File('${app.path}/test/number_test.dart').deleteSync();
    File('${app.path}/tool/preview.dart').deleteSync();
    File('${app.path}/tool/preview_test.dart').deleteSync();

    // The health gate package is not a Flutter package; its code selects its
    // test script, while its lists and notes select nothing.
    write(
      repository,
      'tool/check_library_health_test.dart',
      'void main() {}\n',
    );
    git(repository, ['add', '-A']);
    final healthBase = git(repository, ['write-tree']);
    write(repository, 'tool/library_health/pubspec.yaml', 'name: health\n');
    write(repository, 'tool/library_health/lib/a.dart', 'void a() {}\n');
    check(
      !tool.findPackages(repository.path).any((p) => p.name == 'health'),
      'library_health is skipped as a package',
    );
    selection = tool.select(repository.path, healthBase);
    check(
      selection.scripts.contains('tool/check_library_health_test.dart') &&
          selection.packages.isEmpty,
      'health scripts: ${selection.scripts} ${selection.packages}',
    );
    File('${repository.path}/tool/library_health/lib/a.dart').deleteSync();
    File('${repository.path}/tool/library_health/pubspec.yaml').deleteSync();
    write(repository, 'tool/library_health/allowlist.txt', '# list\n');
    selection = tool.select(repository.path, healthBase);
    check(
      !selection.scripts.contains('tool/check_library_health_test.dart') &&
          !selection.unchecked.contains('tool/library_health/allowlist.txt'),
      'a list change selects nothing: ${selection.scripts} ${selection.unchecked}',
    );
    File('${repository.path}/tool/library_health/allowlist.txt').deleteSync();
    File('${repository.path}/tool/check_library_health_test.dart').deleteSync();

    // The run step: a repository with the gate runs it first, with the base;
    // one without it (an app) is not affected.
    write(
      repository,
      'tool/check_library_health.dart',
      "import 'dart:io';\nvoid main(List<String> a) {\n  File('gate.args').writeAsStringSync(a.join(' '));\n  exitCode = 1;\n}\n",
    );
    selection = tool.select(repository.path, base);
    final status = await tool.run(selection);
    check(status == 1, 'a failing gate fails the run: $status');
    check(
      File('${repository.path}/gate.args').readAsStringSync() == '--base $base',
      'gate arguments: ${File('${repository.path}/gate.args').readAsStringSync()}',
    );
    // Deleting the gate fails a run whose base still has it.
    final indexTree = git(repository, ['write-tree']);
    git(repository, ['add', '-A']);
    final gateBase = git(repository, ['write-tree']);
    File('${repository.path}/tool/check_library_health.dart').deleteSync();
    File('${repository.path}/gate.args').deleteSync();
    selection = tool.select(repository.path, gateBase);
    check(
      await tool.run(selection) == 1,
      'a base with the gate and a tree without it fails the run',
    );
    git(repository, ['read-tree', indexTree]);
    selection = tool.select(repository.path, base);
    check(
      await tool.run(selection) == 0,
      'without the gate file nothing extra runs',
    );

    // Touching most of the tests is broad.
    write(repository, 'tool/audit.dart', 'void main() {}\n');
    write(repository, 'docs/notes.md', 'notes\n');
    write(
      repository,
      'packages/kit/lib/src/avatar.dart',
      "import '_slot.dart';\n\nclass KitAvatar {}\n\nclass KitBadge {}\n",
    );
    write(
      repository,
      'packages/kit/lib/src/unrelated.dart',
      'class KitUnrelated {}\n\nclass KitOther {}\n',
    );
    write(
      repository,
      'packages/kit/lib/src/picker.dart',
      "part '_picker_menu.dart';\n\nclass KitPicker {}\n\nvoid showKitPicker() {}\n\nclass KitMenu {}\n",
    );
    selection = tool.select(repository.path, base);
    kit = selection.packages.single;
    check(
      kit.tests.length == 3 && kit.broad && selection.broad,
      'broad: ${kit.tests}',
    );

    // A removed declaration still selects the tests that used it.
    write(
      repository,
      'packages/kit/lib/src/avatar.dart',
      "import '_slot.dart';\n\nclass KitAvatar {}\n",
    );
    write(
      repository,
      'packages/kit/lib/src/unrelated.dart',
      'class KitUnrelated {}\n',
    );
    write(
      repository,
      'packages/kit/lib/src/picker.dart',
      "part '_picker_menu.dart';\n\nclass KitPicker {}\n",
    );
    selection = tool.select(repository.path, base);
    check(
      selection.packages.single.tests.single == 'test/picker_test.dart',
      'removed name: ${selection.packages.single.tests}',
    );

    // --all selects every package test, the whole package analysis and every
    // tool test, whatever changed.
    final full = tool.selectAll(repository.path);
    kit = full.packages.single;
    check(
      full.full && kit.analyzeAll && kit.tests.length == 4,
      'full run: ${kit.tests}',
    );
    check(
      full.scripts.single == 'tool/audit_test.dart',
      'full run scripts: ${full.scripts}',
    );

    // The JSON report gives the counts; a hidden entry counts only when it
    // fails, which is how a suite that does not load is reported.
    final kitRoot = '${repository.path.replaceAll('\\', '/')}/packages/kit';
    final report = File('${repository.parent.path}/report.json')
      ..writeAsStringSync(
        [
          '{"type":"suite","suite":{"id":0,"path":"$kitRoot/test/row_test.dart"}}',
          '{"type":"suite","suite":{"id":1,"path":"test/picker_test.dart"}}',
          '{"type":"testStart","test":{"id":1,"name":"loading","suiteID":0}}',
          '{"type":"testDone","testID":1,"result":"success","skipped":false,"hidden":true}',
          '{"type":"testStart","test":{"id":2,"name":"row lays out","suiteID":0}}',
          '{"type":"testDone","testID":2,"result":"success","skipped":false,"hidden":false}',
          '{"type":"testStart","test":{"id":3,"name":"row wraps","suiteID":0}}',
          '{"type":"testDone","testID":3,"result":"success","skipped":true,"hidden":false}',
          '{"type":"testStart","test":{"id":4,"name":"loading","suiteID":1}}',
          '{"type":"testDone","testID":4,"result":"error","skipped":false,"hidden":true}',
          'not json',
        ].join('\n'),
      );
    final counts = tool.readTestReport(report.path, kitRoot);
    check(
      counts.passed == 1 && counts.skipped == 1 && counts.failed == 1,
      'report counts: $counts',
    );
    check(
      counts.failedFiles.single == 'test/picker_test.dart',
      'report failed files: ${counts.failedFiles}',
    );

    // `HEAD^` reaches the gate as a full commit id, not as text a Windows
    // shell would mangle.
    final history = Directory('${repository.parent.path}/history')
      ..createSync();
    git(history, ['init', '--quiet']);
    write(
      history,
      'tool/check_library_health.dart',
      "import 'dart:io';\nvoid main(List<String> a) {\n  File('gate.args').writeAsStringSync(a.join(' '));\n}\n",
    );
    write(history, 'note.txt', 'one\n');
    const identity = ['-c', 'user.name=t', '-c', 'user.email=t@example.com'];
    git(history, ['add', '-A']);
    git(history, [...identity, 'commit', '--quiet', '-m', 'one']);
    final first = git(history, ['rev-parse', 'HEAD']);
    write(history, 'note.txt', 'two\n');
    git(history, ['add', '-A']);
    git(history, [...identity, 'commit', '--quiet', '-m', 'two']);
    final historyStatus = await tool.run(tool.select(history.path, 'HEAD^'));
    check(historyStatus == 0, "a passing gate passes the run: $historyStatus");
    final args = File('${history.path}/gate.args').readAsStringSync();
    check(args == '--base $first', 'HEAD^ reaches the gate as $args');

    check(
      tool
          .publicNames(
            'extension on int {}\nextension KitInts on int {}\ntypedef KitCallback = void Function();\nFuture<void> runKit() async {}\n',
          )
          .containsAll(['KitInts', 'KitCallback', 'runKit']),
      'declarations',
    );
    // frost_data reads frost_ui's unexported files: a frost_ui change selects
    // all of it, and the reverse does not hold.
    final coupled = Directory('${repository.parent.path}/coupled')
      ..createSync();
    write(coupled, 'packages/frost_ui/pubspec.yaml', 'name: frost_ui\n');
    write(
      coupled,
      'packages/frost_ui/lib/src/helper.dart',
      'int helper() => 1;\n',
    );
    write(
      coupled,
      'packages/frost_ui/test/helper_test.dart',
      'void main() => helper();\n',
    );
    write(coupled, 'packages/frost_data/pubspec.yaml', 'name: frost_data\n');
    write(coupled, 'packages/frost_data/lib/src/data.dart', 'class Data {}\n');
    write(
      coupled,
      'packages/frost_data/test/one_test.dart',
      'void main() {}\n',
    );
    write(
      coupled,
      'packages/frost_data/test/two_test.dart',
      'void main() {}\n',
    );
    git(coupled, ['init', '--quiet']);
    git(coupled, ['add', '-A']);
    final coupledBase = git(coupled, ['write-tree']);
    check(
      tool.select(coupled.path, coupledBase).packages.isEmpty,
      'no change selects no package',
    );

    write(
      coupled,
      'packages/frost_ui/lib/src/helper.dart',
      'int helper() => 2;\n',
    );
    var chosen = tool.select(coupled.path, coupledBase).packages;
    check(
      chosen.map((p) => p.package.name).join(',') == 'frost_data,frost_ui',
      'a frost_ui change selects: $chosen',
    );
    final dataSelection = chosen.first;
    check(dataSelection.analyzeAll, 'frost_data is analyzed whole');
    check(
      dataSelection.tests.length == 2 &&
          dataSelection.tests.containsAll([
            'test/one_test.dart',
            'test/two_test.dart',
          ]),
      'frost_data tests: ${dataSelection.tests}',
    );

    write(
      coupled,
      'packages/frost_ui/lib/src/helper.dart',
      'int helper() => 1;\n',
    );
    write(
      coupled,
      'packages/frost_data/lib/src/data.dart',
      'class Data {}\n\nclass More {}\n',
    );
    chosen = tool.select(coupled.path, coupledBase).packages;
    check(
      chosen.single.package.name == 'frost_data',
      'a frost_data change selects: $chosen',
    );
    check(
      !chosen.single.analyzeAll,
      'a frost_data change alone is not widened',
    );

    stdout.writeln('affected_tests: all checks passed');
  } finally {
    repository.parent.deleteSync(recursive: true);
  }
}
