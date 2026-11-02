import 'dart:io';

import 'evaluate.dart';
import 'git.dart';
import 'growth.dart';
import 'guidance.dart';
import 'layers.dart';
import 'lists.dart';
import 'model.dart';
import 'project.dart';
import 'public_api.dart';
import 'report.dart';
import 'scan.dart';
import 'tokens.dart';

const _usage =
    'Usage: dart tool/check_library_health.dart [--root <dir>] [--base <commit>] '
    '[--prune] [--init]';

Future<int> run(List<String> arguments,
    {required String toolRepository}) async {
  var root = toolRepository;
  String? base;
  var prune = false, init = false;
  for (var i = 0; i < arguments.length; i++) {
    switch (arguments[i]) {
      case '--root' when i + 1 < arguments.length:
        root = arguments[++i];
      case '--base' when i + 1 < arguments.length:
        base = arguments[++i];
      case '--prune':
        prune = true;
      case '--init':
        init = true;
      default:
        stderr.writeln(_usage);
        return 2;
    }
  }
  if (init && prune) {
    stderr.writeln(_usage);
    return 2;
  }

  final project = Project.load(root);
  if (project == null) {
    stderr.writeln('library health: no packages/frost_ui/lib/src under $root');
    return 2;
  }
  if (!project.files.containsKey('${project.libDirectory}/frost_ui.dart')) {
    stderr.writeln(
        'library health: packages/frost_ui/lib/frost_ui.dart is missing');
    return 2;
  }
  var comparable = false;
  if (base != null) {
    try {
      switch (baseState(project.root, base)) {
        case BaseState.notRepository:
          break;
        case BaseState.unknown:
          stderr.writeln('library health: base $base is not known to git');
          return 2;
        case BaseState.ok:
          comparable = true;
      }
    } on GitError catch (error) {
      stderr.writeln('library health: ${error.message}');
      return 2;
    }
  }
  final listDirectory = '${project.root}/tool/library_health';

  if (init) {
    final existing = [
      for (final name in [allowlistName, publicApiName])
        if (File('$listDirectory/$name').existsSync()) name,
    ];
    if (existing.isNotEmpty) {
      stderr.writeln(
        'library health: ${existing.join(' and ')} already exists; '
        'nothing written',
      );
      return 2;
    }
  }

  final List<Finding> findings;
  try {
    findings = await _collect(project, toolRepository);
  } on StateError catch (error) {
    stderr.writeln('library health: ${error.message}');
    return 2;
  }
  final rows = collectPublicApi(project);
  final countable = findings.where((f) => f.rule != 'parse').toList();

  final parseErrors = findings.any((f) => f.rule == 'parse');
  if (init) {
    if (parseErrors) {
      stderr.writeln(
        'library health: some files do not parse, so the lists would be '
        'incomplete; nothing written',
      );
      return 2;
    }
    Directory(listDirectory).createSync(recursive: true);
    File('$listDirectory/$allowlistName').writeAsStringSync(
      renderAllowList(countable),
    );
    File('$listDirectory/$publicApiName')
        .writeAsStringSync(renderApiList(rows));
    stdout.writeln(
      'library health: wrote $allowlistName (${countable.length} occurrences) '
      'and $publicApiName (${rows.length} rows)',
    );
    return 0;
  }

  var allow = readAllowList(listDirectory);
  var api = readApiList(listDirectory);
  if (allow == null || api == null) {
    stderr.writeln(
      allow == null && api == null
          ? 'library health: both lists are missing; run '
              'dart tool/check_library_health.dart --init'
          : 'library health: ${allow == null ? allowlistName : publicApiName} '
              'is missing; restore it from git',
    );
    return 2;
  }
  if (prune && !parseErrors) {
    pruneAllowList(allow, countable);
    pruneApiList(api, rows);
    allow = readAllowList(listDirectory)!;
    api = readApiList(listDirectory)!;
  }

  final outcome = Outcome();
  for (final f in findings.where((f) => f.rule == 'parse')) {
    outcome.violations.add(
      Problem(
        'parse ${f.file}:${f.line} - syntax: ${guidanceFor('parse', '')} (${f.detail})',
        'parse\t${f.file}\t${f.line.toString().padLeft(8, '0')}',
      ),
    );
  }
  evaluateAllowList(outcome, allow, countable);
  evaluateApiList(outcome, api, rows);

  int byKey(Problem a, Problem b) => a.sortKey.compareTo(b.sortKey);
  for (final p in outcome.violations..sort(byKey)) {
    stdout.writeln(p.text);
  }
  for (final p in outcome.stale..sort(byKey)) {
    stdout.writeln(p.text);
  }
  for (final line in sizeReport(project)) {
    stdout.writeln(line);
  }
  final List<Problem> growth;
  try {
    growth = comparable
        ? findGrowth(project.root, base!, listDirectory)
        : <Problem>[];
  } on GitError catch (error) {
    stderr.writeln('library health: ${error.message}');
    return 2;
  }
  for (final p in growth) {
    stdout.writeln(p.text);
  }
  if (comparable) {
    for (final line in baseReport(project.root, base!)) {
      stdout.writeln(line);
    }
  }
  stdout.writeln(
    'library health: ${outcome.violations.length} violations, '
    '${outcome.stale.length} stale, ${growth.length} growth',
  );
  return outcome.violations.isEmpty && outcome.stale.isEmpty && growth.isEmpty
      ? 0
      : 1;
}

Future<List<Finding>> _collect(Project project, String toolRepository) async {
  final files = project.sourceFiles;
  final widgets = collectWidgetClasses(files);
  final findings = <Finding>[];
  for (final file in project.files.values) {
    for (final error in file.errors) {
      findings
          .add(Finding('parse', file.relative, error.line, '-', error.message));
    }
  }
  for (final file in files) {
    final scanner = Scanner(file, widgets);
    file.unit.accept(scanner);
    findings.addAll(scanner.findings);
  }
  findings.addAll(scanLayers(project));
  findings.addAll(await scanTokens(project.root, toolRepository));
  return findings;
}
