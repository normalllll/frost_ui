// Selects the checks a change needs instead of the whole suite: analysis of
// the changed libraries and their direct importers, the tests that use what
// the changed libraries declare, and the files of dependent apps that use the
// same API.
//
// frost_ui code imports the defining library directly, so the direct
// importers of a changed library are the code that uses it; they are always
// analyzed. Their tests run only with --dependents, for a change to a default
// every caller sees. Tests import the public barrel, so tests are matched by
// the public names a library declares rather than by their imports.
import 'dart:convert';
import 'dart:io';

const _usage = '''
Usage: dart tool/affected_tests.dart <base> [options]
       dart tool/affected_tests.dart --all [--repo <dir>] [--run]

Lists the analyzer targets and tests affected by the changes between <base>
(a commit or tree) and the working tree, including untracked files.

  --repo <dir>       Repository to inspect (default: the one holding this tool).
  --consumer <dir>   App that depends on this repository: also lists its tests
                     and the sources that use the affected API. Repeatable.
  --dependents       Also select the tests of the direct importers, for a
                     change to a default or geometry that every caller sees.
  --run              Analyze the affected files and run the selected tests.
                     Tests print only failures; each package ends with one
                     summary line, and the full results go to
                     .dart_tool/affected_tests/ in the repository.
  --all              Select every package's whole analysis and test suite and
                     every tool test instead of a change. Only when the owner
                     asks for a full run.
  --json             Print the selection as JSON.''';

/// Packages that read the unexported files of another package in this
/// repository, by name. A change there can break them with no change of their
/// own and no public name to match, so they are selected whole.
const _readsPrivateFilesOf = {'frost_data': 'frost_ui'};

/// A selection covering more than this share of a package's tests is broad.
/// It is noted in the listing and still runs: with failures-only output a
/// large selection costs machine time, not reading.
const broadShare = 0.5;

const _skippedDirectories = {
  'build',
  'ephemeral',
  'node_modules',
  'Pods',
  'library_health',
  'target',
};

final _directive = RegExp(
  r'''^\s*(import|export|part\s+of|part)\s+['"]([^'"]+)['"]''',
  multiLine: true,
);
final _typeDeclaration = RegExp(
  r'^(?:(?:abstract|sealed|final|base|interface|mixin)\s+)*(?:class|enum|mixin|typedef|extension\s+type|extension)\s+([A-Za-z_$][\w$]*)',
  multiLine: true,
);
final _functionDeclaration = RegExp(
  r'^(?:[A-Za-z_$][\w$]*(?:<[^()]*>)?\??\s+)+([A-Za-z$][\w$]*)\s*(?:<[^()]*>)?\(',
  multiLine: true,
);
final _variableDeclaration = RegExp(
  r'^(?:const|final)\s+(?:[A-Za-z_$][\w$<>?, ]*\s+)?([A-Za-z$][\w$]*)\s*=',
  multiLine: true,
);
const _notNames = {
  'on',
  'if',
  'for',
  'while',
  'switch',
  'return',
  'get',
  'set',
  'operator',
};

class Package {
  Package(this.root, this.name);

  /// Absolute path with forward slashes and no trailing slash.
  final String root;
  final String name;
}

class PackageSelection {
  PackageSelection(this.package);
  final Package package;
  final Set<String> changedLibraries = {};
  final Set<String> affectedLibraries = {};
  final Set<String> names = {};
  final Set<String> tests = {};
  final Set<String> analyze = {};
  int totalTests = 0;

  /// pubspec.yaml or analysis_options.yaml changed, so the whole package is
  /// analyzed; tests still follow the library selection.
  bool analyzeAll = false;

  bool get broad => totalTests > 0 && tests.length > totalTests * broadShare;
}

class ConsumerSelection {
  ConsumerSelection(this.package);
  final Package package;
  final Set<String> tests = {};
  final Set<String> sources = {};
}

class Selection {
  Selection(this.root, this.base, {this.full = false});
  final String root;
  final String base;

  /// Every package and tool test, from --all, rather than a change.
  final bool full;
  final List<String> changed = [];
  final List<PackageSelection> packages = [];
  final List<ConsumerSelection> consumers = [];

  /// Repository-relative Dart scripts that test a changed tool.
  final Set<String> scripts = {};

  /// Changed files that no check covers, such as documentation.
  final List<String> unchecked = [];

  bool get broad => packages.any((p) => p.broad);
}

String _slashes(String path) => path.replaceAll('\\', '/');

String _basename(String path) => path.split('/').last;

bool _isPrivate(String path) => _basename(path).startsWith('_');

List<String> _lines(String text) => const LineSplitter()
    .convert(text)
    .where((l) => l.trim().isNotEmpty)
    .toList();

String _git(String repo, List<String> arguments) {
  final result = Process.runSync('git', [
    '-c',
    'core.quotepath=off',
    '-C',
    repo,
    ...arguments,
  ], stdoutEncoding: utf8);
  if (result.exitCode != 0)
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  return result.stdout as String;
}

String? _baseSource(String repo, String base, String path) {
  final result = Process.runSync('git', [
    '-C',
    repo,
    'show',
    '$base:$path',
  ], stdoutEncoding: utf8);
  return result.exitCode == 0 ? result.stdout as String : null;
}

/// Whether commit [base] has [path]. Throws when git itself fails, which is
/// not the same as the commit lacking the file.
bool _presentAtBase(String repo, String base, String path) =>
    _git(repo, ['ls-tree', '--name-only', base, '--', path]).trim().isNotEmpty;

/// Public top-level names a Dart source declares.
Set<String> publicNames(String source) {
  final names = <String>{};
  void add(String name) {
    if (!name.startsWith('_') && !_notNames.contains(name)) names.add(name);
  }

  for (final pattern in [
    _typeDeclaration,
    _functionDeclaration,
    _variableDeclaration,
  ]) {
    for (final match in pattern.allMatches(source)) {
      add(match.group(1)!);
    }
  }
  // Callers name an extension's members, not the extension.
  for (final match in _extensionStart.allMatches(source)) {
    final body = _braceBody(source, match.end - 1);
    for (final member in _extensionMember.allMatches(body)) {
      add(member.group(1)!);
    }
  }
  return names;
}

final _extensionStart = RegExp(
  r'^extension\s+[A-Za-z_$][\w$]*(?:<[^>]*>)?\s+on\s+[^{]+\{',
  multiLine: true,
);
final _extensionMember = RegExp(
  r'^  (?:static\s+)?(?:[A-Za-z_$][\w$<>?, ]*\s+)+(?:get\s+)?([A-Za-z$][\w$]*)\s*(?:<[^()]*>)?[({=]',
  multiLine: true,
);

/// The text between the brace at [open] and its match.
String _braceBody(String source, int open) {
  var depth = 0;
  for (var i = open; i < source.length; i++) {
    final c = source[i];
    if (c == '{') depth++;
    if (c == '}' && --depth == 0) return source.substring(open + 1, i);
  }
  return source.substring(open + 1);
}

/// A package entry point: a library directly under `lib/`.
bool _isEntry(String path) =>
    path.startsWith('lib/') && !path.substring(4).contains('/');

final _exportDirective = RegExp(
  r'''^\s*export\s+['"]([^'"]+)['"]\s*((?:show|hide)\s+[^;]*)?;''',
  multiLine: true,
);

/// What an entry exports from each target: `(mode, names)`, where mode is
/// `show`, `hide` or `all`.
Map<String, (String, Set<String>)> _exports(
  String? text,
  String entry,
  Package package,
) {
  final exports = <String, (String, Set<String>)>{};
  if (text == null) return exports;
  for (final match in _exportDirective.allMatches(text)) {
    final target = _resolve(package, entry, match.group(1)!);
    if (target == null) continue;
    final clause = match.group(2)?.trim();
    if (clause == null) {
      exports[target] = ('all', {});
    } else {
      final names = clause
          .substring(4)
          .split(',')
          .map((n) => n.trim())
          .where((n) => n.isNotEmpty)
          .toSet();
      exports[target] = (clause.substring(0, 4), names);
    }
  }
  return exports;
}

/// The names whose export an entry's change adds or removes. [sourceOf]
/// returns a target library's text, current or from the base.
Set<String> _changedExports(
  String? before,
  String? after,
  String entry,
  String? Function(String target) sourceOf,
  Package package,
) {
  final old = _exports(before, entry, package);
  final now = _exports(after, entry, package);
  final names = <String>{};
  for (final target in {...old.keys, ...now.keys}) {
    final a = old[target], b = now[target];
    if (a != null &&
        b != null &&
        a.$1 == b.$1 &&
        a.$2.length == b.$2.length &&
        a.$2.containsAll(b.$2)) {
      continue;
    }
    if (a != null && b != null && a.$1 == b.$1 && a.$1 != 'all') {
      names.addAll(a.$2.difference(b.$2));
      names.addAll(b.$2.difference(a.$2));
    } else {
      names.addAll(publicNames(sourceOf(target) ?? ''));
      names.addAll(a?.$2 ?? const {});
      names.addAll(b?.$2 ?? const {});
    }
  }
  return names;
}

List<Package> findPackages(String root) {
  final packages = <Package>[];
  void visit(Directory directory) {
    final pubspec = File('${directory.path}/pubspec.yaml');
    if (pubspec.existsSync()) {
      final name = RegExp(
        r'^name:\s*(\S+)',
        multiLine: true,
      ).firstMatch(pubspec.readAsStringSync())?.group(1);
      if (name != null) packages.add(Package(_slashes(directory.path), name));
    }
    for (final child
        in directory.listSync(followLinks: false).whereType<Directory>()) {
      final name = _basename(_slashes(child.path));
      if (name.startsWith('.') || _skippedDirectories.contains(name)) continue;
      visit(child);
    }
  }

  visit(Directory(root));
  return packages;
}

/// Resolves a directive URI to a package-relative path, or null when it leaves
/// the package.
String? _resolve(Package package, String from, String uri) {
  final prefix = 'package:${package.name}/';
  if (uri.startsWith(prefix)) return 'lib/${uri.substring(prefix.length)}';
  if (uri.contains(':')) return null;
  final segments = from.split('/')..removeLast();
  for (final segment in uri.split('/')) {
    if (segment == '..') {
      if (segments.isNotEmpty) segments.removeLast();
    } else if (segment != '.') {
      segments.add(segment);
    }
  }
  return segments.join('/');
}

class _Source {
  _Source(this.text);
  final String text;
  final Set<String> imports = {};
  final Set<String> parts = {};
  String? partOf;
}

Map<String, _Source> _readSources(Package package, String directory) {
  final sources = <String, _Source>{};
  final root = Directory('${package.root}/$directory');
  if (!root.existsSync()) return sources;
  for (final file in root.listSync(recursive: true).whereType<File>()) {
    final path = _slashes(file.path);
    if (!path.endsWith('.dart')) continue;
    final relative = path.substring(package.root.length + 1);
    final source = _Source(file.readAsStringSync());
    for (final match in _directive.allMatches(source.text)) {
      final target = _resolve(package, relative, match.group(2)!);
      if (target == null) continue;
      switch (match.group(1)!.split(RegExp(r'\s+')).join(' ')) {
        case 'import':
          source.imports.add(target);
        case 'part':
          source.parts.add(target);
        case 'part of':
          source.partOf = target;
      }
    }
    sources[relative] = source;
  }
  return sources;
}

PackageSelection _selectPackage(
  String root,
  String base,
  Package package,
  List<String> changed, {
  required bool dependents,
}) {
  final selection = PackageSelection(package);
  final prefix = package.root == root
      ? ''
      : '${package.root.substring(root.length + 1)}/';
  final libraries = _readSources(package, 'lib');
  String libraryOf(String path) => libraries[path]?.partOf ?? path;

  final importers = <String, Set<String>>{};
  libraries.forEach((path, source) {
    for (final target in source.imports) {
      importers.putIfAbsent(libraryOf(target), () => {}).add(libraryOf(path));
    }
  });

  final seeds = <String>{};
  final entries = <String>{};
  for (final path in changed.where(
    (p) => p.startsWith('lib/') && p.endsWith('.dart'),
  )) {
    selection.changedLibraries.add(path);
    // Every test imports an entry point, so a changed entry selects by the
    // names whose export it changed, not by its importers.
    if (_isEntry(path)) {
      if (libraries.containsKey(path)) entries.add(path);
      selection.names.addAll(
        _changedExports(
          _baseSource(root, base, '$prefix$path'),
          libraries[path]?.text,
          path,
          (target) =>
              libraries[target]?.text ??
              _baseSource(root, base, '$prefix$target'),
          package,
        ),
      );
      continue;
    }
    seeds.add(libraryOf(path));
    // Declarations removed or renamed by the change still have callers.
    final previous = _baseSource(root, base, '$prefix$path');
    if (previous != null) selection.names.addAll(publicNames(previous));
  }
  // A private library is used only through the libraries that import it.
  final pending = [...seeds.where(_isPrivate)];
  while (pending.isNotEmpty) {
    for (final importer
        in importers[pending.removeLast()] ?? const <String>{}) {
      if (seeds.add(importer) && _isPrivate(importer)) pending.add(importer);
    }
  }
  final affected = {
    ...seeds,
    for (final seed in seeds) ...?importers[seed],
  }.where(libraries.containsKey);
  selection.affectedLibraries.addAll(affected);
  for (final path
      in dependents ? affected : seeds.where(libraries.containsKey)) {
    final library = libraries[path]!;
    selection.names.addAll(publicNames(library.text));
    for (final part in library.parts) {
      final text = libraries[part]?.text;
      if (text != null) selection.names.addAll(publicNames(text));
    }
  }

  // Constructor baselines are cheap and show whether a change reached the
  // components built on the changed one, so they are selected by the names
  // of the direct importers too.
  final baselineNames = {...selection.names};
  for (final path in affected) {
    final library = libraries[path]!;
    baselineNames.addAll(publicNames(library.text));
    for (final part in library.parts) {
      final text = libraries[part]?.text;
      if (text != null) baselineNames.addAll(publicNames(text));
    }
  }
  final baselinePattern = baselineNames.isEmpty
      ? null
      : RegExp('\\b(?:${baselineNames.map(RegExp.escape).join('|')})\\b');
  // A re-recorded baseline file selects the test that owns its records.
  final rerecorded = {
    for (final path in changed)
      if (RegExp(r'^test/baseline/([^/]+)/').firstMatch(path) case final m?)
        m.group(1)!,
  };

  final tests = _readSources(package, 'test');
  final changedTests = changed
      .where((p) => p.startsWith('test/') && p.endsWith('.dart'))
      .toSet();
  final changedHelpers = changedTests
      .where((p) => !p.endsWith('_test.dart'))
      .toSet();
  final pattern = selection.names.isEmpty
      ? null
      : RegExp('\\b(?:${selection.names.map(RegExp.escape).join('|')})\\b');
  tests.forEach((path, source) {
    if (!path.endsWith('_test.dart')) return;
    selection.totalTests++;
    final selected =
        changedTests.contains(path) ||
        source.imports.any(
          (target) =>
              selection.affectedLibraries.contains(target) ||
              changedHelpers.contains(target),
        ) ||
        (pattern?.hasMatch(source.text) ?? false) ||
        (path.startsWith('test/baseline/') &&
            ((baselinePattern?.hasMatch(source.text) ?? false) ||
                rerecorded.any(
                  (widget) => source.text.contains("baselineGroup('$widget'"),
                )));
    if (selected) selection.tests.add(path);
  });

  selection.analyzeAll =
      changed.contains('pubspec.yaml') ||
      changed.contains('analysis_options.yaml');
  selection.analyze.addAll([
    ...entries,
    ...selection.affectedLibraries,
    ...selection.tests,
    ...changedHelpers.where((p) => File('${package.root}/$p').existsSync()),
  ]);
  return selection;
}

ConsumerSelection? _selectConsumer(
  Package package,
  List<PackageSelection> dependencies,
) {
  final pubspec = File('${package.root}/pubspec.yaml').readAsStringSync();
  final names = {
    for (final dependency in dependencies)
      if (RegExp(
        '^\\s+${RegExp.escape(dependency.package.name)}:',
        multiLine: true,
      ).hasMatch(pubspec))
        ...dependency.names,
  };
  if (names.isEmpty) return null;
  final pattern = RegExp('\\b(?:${names.map(RegExp.escape).join('|')})\\b');
  final selection = ConsumerSelection(package);
  // Tool scripts use the library too; they are analyzed, not run.
  for (final directory in ['lib', 'test', 'tool']) {
    _readSources(package, directory).forEach((path, source) {
      if (!pattern.hasMatch(source.text)) return;
      if (directory == 'test' && path.endsWith('_test.dart')) {
        selection.tests.add(path);
      } else {
        // A part is analyzed through its library: on Windows `flutter analyze`
        // lowercases the paths it is given, and a part whose name has capitals
        // then no longer matches its library's `part` directive.
        selection.sources.add(source.partOf ?? path);
      }
    });
  }
  return selection;
}

Selection select(
  String repository,
  String base, {
  List<String> consumers = const [],
  bool dependents = false,
}) {
  final root = _slashes(
    _git(repository, ['rev-parse', '--show-toplevel']).trim(),
  );
  _git(root, ['rev-parse', '--verify', '--quiet', '$base^{tree}']);
  final changed = {
    ..._lines(_git(root, ['diff', '--name-only', '--no-renames', base])),
    ..._lines(_git(root, ['ls-files', '--others', '--exclude-standard'])),
  }.toList()..sort();
  final selection = Selection(root, base)..changed.addAll(changed);

  // The deepest package owns a path.
  final packages = findPackages(root)
    ..sort((a, b) => b.root.length.compareTo(a.root.length));
  final owned = <Package, List<String>>{};
  for (final path in changed) {
    final absolute = '$root/$path';
    final package = packages
        .where((p) => absolute.startsWith('${p.root}/'))
        .firstOrNull;
    final relative = package == null
        ? path
        : absolute.substring(package.root.length + 1);
    final inPackageCode =
        relative.startsWith('lib/') ||
        relative.startsWith('test/') ||
        relative == 'pubspec.yaml' ||
        relative == 'analysis_options.yaml';
    if (package != null && inPackageCode) {
      owned.putIfAbsent(package, () => []).add(relative);
      continue;
    }
    // The health gate's package is covered by its test script. Its lists and
    // notes are data that the gate itself checks on every run.
    if (path.startsWith('tool/library_health/')) {
      const healthTest = 'tool/check_library_health_test.dart';
      final data = path.endsWith('.txt') || path.endsWith('.md');
      if (!data && File('$root/$healthTest').existsSync()) {
        selection.scripts.add(healthTest);
      }
      continue;
    }
    // A changed tool or its test data is covered by the tool's own test script.
    final test = path.endsWith('_test.dart')
        ? path
        : path.endsWith('.dart')
        ? '${path.substring(0, path.length - 5)}_test.dart'
        : null;
    final data = RegExp(r'^(.*?/)?testdata/').firstMatch(path);
    if (test != null && File('$root/$test').existsSync()) {
      selection.scripts.add(test);
    } else if (data != null) {
      final directory = Directory('$root/${data.group(1) ?? ''}');
      selection.scripts.addAll(
        directory
            .listSync()
            .whereType<File>()
            .map((f) => _slashes(f.path))
            .where((p) => p.endsWith('_test.dart'))
            .map((p) => p.substring(root.length + 1)),
      );
    } else {
      selection.unchecked.add(path);
    }
  }
  final whole = {
    for (final package in packages)
      if (owned.keys.any((p) => p.name == _readsPrivateFilesOf[package.name]))
        package,
  };
  for (final package in whole) {
    owned.putIfAbsent(package, () => []);
  }
  owned.forEach((package, paths) {
    final packageSelection = _selectPackage(
      root,
      base,
      package,
      paths,
      dependents: dependents,
    );
    if (whole.contains(package)) {
      packageSelection.analyzeAll = true;
      packageSelection.tests.addAll(
        _readSources(
          package,
          'test',
        ).keys.where((p) => p.endsWith('_test.dart')),
      );
    }
    selection.packages.add(packageSelection);
  });
  selection.packages.sort((a, b) => a.package.root.compareTo(b.package.root));

  for (final consumer in consumers) {
    for (final package in findPackages(
      _slashes(Directory(consumer).absolute.path),
    )) {
      final consumerSelection = _selectConsumer(package, selection.packages);
      if (consumerSelection != null) selection.consumers.add(consumerSelection);
    }
  }
  return selection;
}

/// Every package's whole analysis and test suite, and every tool test, for a
/// full run the owner asked for.
Selection selectAll(String repository) {
  final root = _slashes(
    _git(repository, ['rev-parse', '--show-toplevel']).trim(),
  );
  final selection = Selection(root, 'all', full: true);
  for (final package in findPackages(
    root,
  )..sort((a, b) => a.root.compareTo(b.root))) {
    final packageSelection = PackageSelection(package)..analyzeAll = true;
    final tests = Directory('${package.root}/test');
    if (tests.existsSync()) {
      for (final file in tests.listSync(recursive: true).whereType<File>()) {
        final path = _slashes(file.path);
        if (path.endsWith('_test.dart')) {
          packageSelection.tests.add(path.substring(package.root.length + 1));
        }
      }
    }
    packageSelection.totalTests = packageSelection.tests.length;
    selection.packages.add(packageSelection);
  }
  final tools = Directory('$root/tool');
  if (tools.existsSync()) {
    for (final file in tools.listSync().whereType<File>()) {
      final path = _slashes(file.path);
      if (path.endsWith('_test.dart')) {
        selection.scripts.add(path.substring(root.length + 1));
      }
    }
  }
  return selection;
}

String _relativeTo(String from, String path) =>
    path.startsWith('$from/') ? path.substring(from.length + 1) : path;

List<String> _sorted(Iterable<String> values) => values.toList()..sort();

String describe(Selection selection) {
  final out = StringBuffer(
    selection.full
        ? 'Full run: every package and tool test.\n'
        : 'Base ${selection.base}: ${selection.changed.length} changed files.\n',
  );
  for (final package in selection.packages) {
    final location = _relativeTo(selection.root, package.package.root);
    out
      ..writeln()
      ..writeln(
        '${package.package.name} (${location == selection.root ? '.' : location})',
      )
      ..writeln(
        '  changed libraries: ${package.changedLibraries.length}, analyzed with direct importers: ${package.affectedLibraries.length}',
      )
      ..writeln(
        '  tests: ${package.tests.length} of ${package.totalTests}${package.broad && !selection.full ? ' (broad: more than half of the package)' : ''}',
      );
    for (final test in _sorted(package.tests)) {
      out.writeln('    $test');
    }
    out.writeln(
      package.analyzeAll
          ? '  analyze: whole package (pubspec or analysis options changed)'
          : '  analyze: ${package.analyze.length} files',
    );
  }
  if (selection.scripts.isNotEmpty) {
    out
      ..writeln()
      ..writeln('tool scripts:');
    for (final script in _sorted(selection.scripts)) {
      out.writeln('  dart $script');
    }
  }
  for (final consumer in selection.consumers) {
    out
      ..writeln()
      ..writeln('consumer ${consumer.package.name} (${consumer.package.root})')
      ..writeln('  tests: ${consumer.tests.length}');
    for (final test in _sorted(consumer.tests)) {
      out.writeln('    $test');
    }
    out.writeln(
      '  sources using the affected API (analyzed; the app recaptures screens only at its next stage acceptance): ${consumer.sources.length}',
    );
    for (final source in _sorted(consumer.sources)) {
      out.writeln('    $source');
    }
  }
  if (selection.unchecked.isNotEmpty) {
    out
      ..writeln()
      ..writeln('no checks needed: ${selection.unchecked.join(', ')}');
  }
  return out.toString();
}

Map<String, Object?> toJson(Selection selection) => {
  'base': selection.base,
  'full': selection.full,
  'changed': selection.changed,
  'broad': selection.broad,
  'packages': [
    for (final p in selection.packages)
      {
        'name': p.package.name,
        'root': p.package.root,
        'tests': _sorted(p.tests),
        'totalTests': p.totalTests,
        'broad': p.broad,
        'analyzeAll': p.analyzeAll,
        'analyze': _sorted(p.analyze),
      },
  ],
  'scripts': _sorted(selection.scripts),
  'consumers': [
    for (final c in selection.consumers)
      {
        'name': c.package.name,
        'root': c.package.root,
        'tests': _sorted(c.tests),
        'sources': _sorted(c.sources),
      },
  ],
  'unchecked': selection.unchecked,
};

/// Splits arguments so each command line stays under the Windows cmd limit.
Iterable<List<String>> _batches(List<String> paths) sync* {
  var batch = <String>[];
  var length = 0;
  for (final path in paths) {
    if (batch.isNotEmpty && length + path.length > 6000) {
      yield batch;
      batch = [];
      length = 0;
    }
    batch.add(path);
    length += path.length + 1;
  }
  if (batch.isNotEmpty) yield batch;
}

/// Outcome of the tests of one package, read from the JSON reporter.
class TestCounts {
  int passed = 0;
  int failed = 0;
  int skipped = 0;

  /// Package-relative test files with a failing test.
  final Set<String> failedFiles = {};

  void add(TestCounts other) {
    passed += other.passed;
    failed += other.failed;
    skipped += other.skipped;
    failedFiles.addAll(other.failedFiles);
  }

  @override
  String toString() => '$passed passed, $failed failed, $skipped skipped';
}

/// Reads a `flutter test --file-reporter json:<path>` file. A hidden entry
/// (loading a suite) counts only when it fails, as a compile or load error.
TestCounts readTestReport(String path, String packageRoot) {
  final counts = TestCounts();
  final file = File(path);
  if (!file.existsSync()) return counts;
  final suites = <int, String>{};
  final testSuites = <int, int>{};
  for (final line in file.readAsLinesSync()) {
    if (!line.startsWith('{')) continue;
    final Object? event;
    try {
      event = jsonDecode(line);
    } on FormatException {
      continue;
    }
    if (event is! Map<String, Object?>) continue;
    switch (event['type']) {
      case 'suite':
        final suite = event['suite']! as Map<String, Object?>;
        final suitePath = _slashes(suite['path'] as String? ?? '');
        suites[suite['id']! as int] = _relativeTo(packageRoot, suitePath);
      case 'testStart':
        final test = event['test']! as Map<String, Object?>;
        testSuites[test['id']! as int] = test['suiteID']! as int;
      case 'testDone':
        final success = event['result'] == 'success';
        if (event['skipped'] == true) {
          counts.skipped++;
        } else if (success) {
          if (event['hidden'] != true) counts.passed++;
        } else {
          counts.failed++;
          final suite = suites[testSuites[event['testID']]];
          if (suite != null) counts.failedFiles.add(suite);
        }
    }
  }
  return counts;
}

Future<int> run(Selection selection) async {
  var status = 0;
  final reports = Directory('${selection.root}/.dart_tool/affected_tests')
    ..createSync(recursive: true);
  for (final old in reports.listSync().whereType<File>()) {
    old.deleteSync();
  }
  var reportCount = 0;
  final summary = <String>[];

  Future<bool> execute(
    String directory,
    String executable,
    List<String> arguments, {
    int files = 0,
  }) async {
    // A long file list says nothing the listing above has not said.
    final shown = files == 0
        ? arguments
        : [...arguments.take(arguments.length - files), '<$files files>'];
    stdout.writeln('\n> ($directory) $executable ${shown.join(' ')}');
    final process = await Process.start(
      executable,
      arguments,
      workingDirectory: directory,
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    final ok = await process.exitCode == 0;
    if (!ok) status = 1;
    return ok;
  }

  Future<bool> analyze(String root, Iterable<String> files, bool all) async {
    if (all) return execute(root, 'flutter', ['analyze']);
    var ok = true;
    for (final batch in _batches(_sorted(files))) {
      ok =
          await execute(root, 'flutter', [
            'analyze',
            ...batch,
          ], files: batch.length) &&
          ok;
    }
    return ok;
  }

  Future<TestCounts> test(String root, Iterable<String> files) async {
    final counts = TestCounts();
    for (final batch in _batches(_sorted(files))) {
      final report = '${reports.path}/${++reportCount}.json';
      final ok = await execute(root, 'flutter', [
        'test',
        '-r',
        'failures-only',
        '--file-reporter',
        'json:$report',
        ...batch,
      ], files: batch.length);
      final batchCounts = readTestReport(report, root);
      if (!ok && batchCounts.failed == 0) {
        // The run stopped before it reported a failing test.
        batchCounts.failed++;
        batchCounts.failedFiles.add('(run ended early; see the output above)');
      }
      counts.add(batchCounts);
    }
    return counts;
  }

  String line(String name, bool analyzed, Set<String> tests, TestCounts c) {
    final testPart = tests.isEmpty ? 'no tests' : 'tests $c';
    final failed = c.failedFiles.isEmpty
        ? ''
        : '\n    failed: ${_sorted(c.failedFiles).join(', ')}';
    return '$name: analyze ${analyzed ? 'clean' : 'has issues'}; $testPart$failed';
  }

  // The library health gate: repositories that have it run it first.
  const gate = 'tool/check_library_health.dart';
  if (File('${selection.root}/$gate').existsSync()) {
    // The gate gets a full commit id: the shell on Windows eats the `^` of
    // `HEAD^`. `_git` starts git without a shell.
    String? baseCommit;
    if (!selection.full) {
      try {
        String resolve(String kind) => _git(selection.root, [
          'rev-parse',
          '--verify',
          '${selection.base}^{$kind}',
        ]).trim();
        try {
          baseCommit = resolve('commit');
        } on StateError {
          // A bare tree id is a base too; the gate only needs its tree.
          baseCommit = resolve('tree');
        }
      } on StateError catch (error) {
        status = 1;
        summary.add('$gate: cannot resolve base ${selection.base}: $error');
      }
    }
    if (selection.full || baseCommit != null) {
      final ok = await execute(selection.root, 'dart', [
        gate,
        if (baseCommit != null) ...['--base', baseCommit],
      ]);
      summary.add('$gate: ${ok ? 'passed' : 'failed'}');
    }
  } else if (!selection.full) {
    // Deleting the gate must not make a run pass, and a git failure must not
    // look like a base without the gate.
    try {
      if (_presentAtBase(selection.root, selection.base, gate)) {
        status = 1;
        summary.add(
          '$gate: missing, but present at ${selection.base}; the gate cannot '
          'be removed',
        );
      }
    } on StateError catch (error) {
      status = 1;
      summary.add('$gate: cannot check ${selection.base} for the gate: $error');
    }
  }
  for (final package in selection.packages) {
    final root = package.package.root;
    final analyzed = await analyze(root, package.analyze, package.analyzeAll);
    final counts = await test(root, package.tests);
    summary.add(line(package.package.name, analyzed, package.tests, counts));
  }
  for (final script in _sorted(selection.scripts)) {
    final ok = await execute(selection.root, 'dart', [script]);
    summary.add('$script: ${ok ? 'passed' : 'failed'}');
  }
  for (final consumer in selection.consumers) {
    final root = consumer.package.root;
    final analyzed = await analyze(root, {
      ...consumer.sources,
      ...consumer.tests,
    }, false);
    final counts = await test(root, consumer.tests);
    summary.add(
      line(
        'consumer ${consumer.package.name}',
        analyzed,
        consumer.tests,
        counts,
      ),
    );
  }

  stdout.writeln('\nSummary');
  for (final entry in summary) {
    stdout.writeln('  $entry');
  }
  if (reportCount > 0) {
    stdout.writeln('  full test results: ${reports.path}');
  }
  return status;
}

Future<void> main(List<String> arguments) async {
  String? base;
  var repository = _slashes(File.fromUri(Platform.script).parent.parent.path);
  final consumers = <String>[];
  var execute = false, json = false, dependents = false, all = false;
  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    switch (argument) {
      case '--repo' when i + 1 < arguments.length:
        repository = arguments[++i];
      case '--consumer' when i + 1 < arguments.length:
        consumers.add(arguments[++i]);
      case '--dependents':
        dependents = true;
      case '--run':
        execute = true;
      case '--all':
        all = true;
      case '--allow-broad':
        // Kept so older instructions still parse; a broad selection runs anyway.
        break;
      case '--json':
        json = true;
      case '-h' || '--help':
        stdout.writeln(_usage);
        return;
      default:
        if (argument.startsWith('-') || base != null) {
          stderr.writeln(_usage);
          exitCode = 2;
          return;
        }
        base = argument;
    }
  }
  // --all replaces the change-based selection, so it takes no base, consumers
  // or dependents.
  if (all ? base != null || consumers.isNotEmpty || dependents : base == null) {
    stderr.writeln(_usage);
    exitCode = 2;
    return;
  }

  final Selection selection;
  try {
    selection = all
        ? selectAll(repository)
        : select(
            repository,
            base!,
            consumers: consumers,
            dependents: dependents,
          );
  } on StateError catch (error) {
    stderr.writeln(error.message);
    exitCode = 2;
    return;
  }
  stdout.write(
    json
        ? '${const JsonEncoder.withIndent('  ').convert(toJson(selection))}\n'
        : describe(selection),
  );
  if (!execute) return;
  exitCode = await run(selection);
}
