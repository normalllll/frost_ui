import 'dart:io';

import 'model.dart';

const baselineMarker = 'baseline-20261102';

const allowlistName = 'allowlist.txt';
const publicApiName = 'public_api.txt';

/// One line of a list file. Comments and blank lines have no [fields].
class ListLine {
  ListLine(this.number, this.raw)
      : fields =
            raw.trim().isEmpty || raw.startsWith('#') ? null : raw.split('\t');

  final int number;
  final String raw;
  final List<String>? fields;
}

List<ListLine> parseLines(String text) {
  final lines = text.split('\n');
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  return [
    for (var i = 0; i < lines.length; i++)
      ListLine(i + 1, lines[i].replaceAll('\r', '')),
  ];
}

/// A parsed allowlist entry.
class AllowEntry {
  AllowEntry(this.line, this.fields);

  final ListLine line;
  final List<String> fields;

  String get rule => fields[0];
  String get file => fields[1];
  String get scope => fields[2];
  String get detail => fields[3];
  int? get count => fields.length > 4 ? int.tryParse(fields[4].trim()) : null;
  String get reason => fields.length > 5 ? fields.sublist(5).join('\t') : '';
  bool get wellFormed => fields.length >= 5 && (count ?? 0) >= 1;
  String get key => Finding.keyOf(rule, file, scope, detail);
}

class AllowList {
  AllowList(this.path, this.lines);

  final String path;
  final List<ListLine> lines;

  Iterable<AllowEntry> get entries sync* {
    for (final line in lines) {
      final fields = line.fields;
      if (fields != null) yield AllowEntry(line, fields);
    }
  }
}

/// A parsed public API snapshot entry.
class ApiEntry {
  ApiEntry(this.line, this.fields);

  final ListLine line;
  final List<String> fields;

  String get kind => fields[0];
  String get name => fields[1];
  String get file => fields.length > 2 ? fields[2] : '';
  String get detail => fields.length > 3 ? fields[3] : '-';
  String get source => fields.length > 4 ? fields.sublist(4).join('\t') : '';
  bool get wellFormed =>
      fields.length >= 5 && fields.take(3).every((f) => f.isNotEmpty);
  String get key => [kind, name, file].join('\t');
  Set<String> get params =>
      detail == '-' || detail.isEmpty ? <String>{} : detail.split(',').toSet();
}

class ApiList {
  ApiList(this.path, this.lines);

  final String path;
  final List<ListLine> lines;

  Iterable<ApiEntry> get entries sync* {
    for (final line in lines) {
      final fields = line.fields;
      if (fields != null) yield ApiEntry(line, fields);
    }
  }
}

AllowList? readAllowList(String directory) {
  final file = File('$directory/$allowlistName');
  if (!file.existsSync()) return null;
  return AllowList(file.path, parseLines(file.readAsStringSync()));
}

ApiList? readApiList(String directory) {
  final file = File('$directory/$publicApiName');
  if (!file.existsSync()) return null;
  return ApiList(file.path, parseLines(file.readAsStringSync()));
}

const allowHeader =
    '''# frost_ui library health: violations that already existed, frozen.
# Counts may only go down. Fields are separated by a tab:
# rule\tfile\tscope\tdetail\tcount\treason
''';

const apiHeader = '''# frost_ui library health: the public API snapshot.
# Fields are separated by a tab:
# kind\tname\tfile\tdetail\tsource
''';

String renderAllowList(List<Finding> findings) {
  final counts = <String, int>{};
  final fields = <String, List<String>>{};
  for (final f in findings) {
    counts[f.key] = (counts[f.key] ?? 0) + 1;
    fields[f.key] = [f.rule, f.file, f.scope, f.detail];
  }
  final rows = [
    for (final e in fields.entries)
      [...e.value, '${counts[e.key]}', baselineMarker],
  ]..sort(compareFields);
  return allowHeader + [for (final r in rows) '${r.join('\t')}\n'].join();
}

String renderApiList(List<ApiRow> rows) {
  final fields = [
    for (final r in rows) [r.kind, r.name, r.file, r.detail, baselineMarker],
  ]..sort(compareFields);
  return apiHeader + [for (final r in fields) '${r.join('\t')}\n'].join();
}
