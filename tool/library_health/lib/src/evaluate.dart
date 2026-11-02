import 'dart:io';

import 'guidance.dart';
import 'lists.dart';
import 'model.dart';

class Outcome {
  final List<Problem> violations = [];
  final List<Problem> stale = [];
}

String _order(String rule, String file, int line) =>
    '$rule\t$file\t${line.toString().padLeft(8, '0')}';

String findingText(Finding f) =>
    '${f.rule} ${f.file}:${f.line} ${f.scope} ${f.detail}: '
    '${guidanceFor(f.rule, f.detail)}';

void _allowlistProblem(
  Outcome outcome,
  AllowEntry entry,
  String detail,
  String message,
) {
  outcome.violations.add(
    Problem(
      'allowlist $allowlistName:${entry.line.number} ${_word(entry.rule)} '
      '${_word(detail)}: $message',
      _order('allowlist', allowlistName, entry.line.number),
    ),
  );
}

String _word(String text) =>
    text.trim().isEmpty ? '-' : text.replaceAll(' ', '_');

Map<String, List<Finding>> _group(List<Finding> findings) {
  final groups = <String, List<Finding>>{};
  for (final f in findings) {
    groups.putIfAbsent(f.key, () => []).add(f);
  }
  for (final list in groups.values) {
    list.sort((a, b) {
      final c = a.file.compareTo(b.file);
      return c != 0 ? c : a.line.compareTo(b.line);
    });
  }
  return groups;
}

/// Compares the counted findings with the allowlist.
void evaluateAllowList(
  Outcome outcome,
  AllowList list,
  List<Finding> findings,
) {
  final groups = _group(findings);
  final allowed = <String, int>{};
  final seen = <String>{};
  for (final entry in list.entries) {
    if (!entry.wellFormed) {
      _allowlistProblem(
        outcome,
        entry,
        'malformed',
        guidanceFor('allowlist', ''),
      );
      continue;
    }
    if (!seen.add(entry.key)) {
      _allowlistProblem(
          outcome, entry, 'duplicate', guidanceFor('allowlist', ''));
      continue;
    }
    if (entry.reason.trim().isEmpty) {
      _allowlistProblem(
          outcome, entry, entry.detail, guidanceFor('allowlist', ''));
    }
    allowed[entry.key] = entry.count!;
    final actual = groups[entry.key]?.length ?? 0;
    if (actual < entry.count!) {
      outcome.stale.add(
        Problem(
          'stale ${entry.rule} ${entry.file} ${_word(entry.scope)} '
          '${_word(entry.detail)}: run --prune',
          _order(entry.rule, entry.file, 0),
        ),
      );
    }
  }
  groups.forEach((key, group) {
    for (final f in group.skip(allowed[key] ?? 0)) {
      outcome.violations
          .add(Problem(findingText(f), _order(f.rule, f.file, f.line)));
    }
  });
}

void _apiViolation(Outcome outcome, String file, int line, String kind,
    String name, String sortFile) {
  outcome.violations.add(
    Problem(
      'public-api $file:$line $kind $name: ${guidanceFor('public-api', '')}',
      _order('public-api', sortFile, line),
    ),
  );
}

void _apiStale(Outcome outcome, ApiEntry entry) {
  outcome.stale.add(
    Problem(
      'stale public-api ${entry.file} ${entry.kind} ${entry.name}: run --prune',
      _order('public-api', entry.file, 0),
    ),
  );
}

/// Compares the exported symbols with the snapshot.
void evaluateApiList(Outcome outcome, ApiList list, List<ApiRow> rows) {
  final actual = {for (final r in rows) r.key: r};
  final listed = <String>{};
  for (final entry in list.entries) {
    if (!entry.wellFormed) {
      _apiViolation(
        outcome,
        publicApiName,
        entry.line.number,
        entry.fields.isNotEmpty ? _word(entry.kind) : '-',
        entry.fields.length > 1 ? _word(entry.name) : '-',
        publicApiName,
      );
      continue;
    }
    if (!listed.add(entry.key)) {
      _apiViolation(outcome, publicApiName, entry.line.number, entry.kind,
          entry.name, publicApiName);
      continue;
    }
    if (entry.source.trim().isEmpty) {
      _apiViolation(outcome, publicApiName, entry.line.number, entry.kind,
          entry.name, publicApiName);
    }
    final row = actual[entry.key];
    if (row == null) {
      _apiStale(outcome, entry);
    } else if (entry.kind == 'ctor') {
      final before = entry.params, now = row.params;
      if (before.difference(now).isNotEmpty) _apiStale(outcome, entry);
      if (now.difference(before).isNotEmpty) {
        _apiViolation(
            outcome, row.file, row.line, row.kind, row.name, row.file);
      }
    }
  }
  for (final row in rows) {
    if (!listed.contains(row.key)) {
      _apiViolation(outcome, row.file, row.line, row.kind, row.name, row.file);
    }
  }
}

/// Shrinks the allowlist file to what still exists. Adds nothing.
void pruneAllowList(AllowList list, List<Finding> findings) {
  final groups = _group(findings);
  final seen = <String>{};
  final out = <String>[];
  var changed = false;
  final entries = {for (final e in list.entries) e.line.number: e};
  for (final line in list.lines) {
    final entry = entries[line.number];
    if (entry == null || !entry.wellFormed || !seen.add(entry.key)) {
      out.add(line.raw);
      continue;
    }
    final actual = groups[entry.key]?.length ?? 0;
    if (actual == 0) {
      changed = true;
    } else if (actual < entry.count!) {
      changed = true;
      final fields = [...entry.fields];
      fields[4] = '$actual';
      out.add(fields.join('\t'));
    } else {
      out.add(line.raw);
    }
  }
  if (changed) File(list.path).writeAsStringSync('${out.join('\n')}\n');
}

/// Shrinks the snapshot file to what is still exported. Adds nothing.
void pruneApiList(ApiList list, List<ApiRow> rows) {
  final actual = {for (final r in rows) r.key: r};
  final seen = <String>{};
  final out = <String>[];
  var changed = false;
  final entries = {for (final e in list.entries) e.line.number: e};
  for (final line in list.lines) {
    final entry = entries[line.number];
    if (entry == null || !entry.wellFormed || !seen.add(entry.key)) {
      out.add(line.raw);
      continue;
    }
    final row = actual[entry.key];
    if (row == null) {
      changed = true;
    } else if (entry.kind == 'ctor' &&
        entry.params.difference(row.params).isNotEmpty) {
      changed = true;
      final kept = (entry.params.intersection(row.params)).toList()..sort();
      final fields = [...entry.fields];
      fields[3] = kept.isEmpty ? '-' : kept.join(',');
      out.add(fields.join('\t'));
    } else {
      out.add(line.raw);
    }
  }
  if (changed) File(list.path).writeAsStringSync('${out.join('\n')}\n');
}
