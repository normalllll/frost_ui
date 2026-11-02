import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';

import 'git.dart';
import 'lists.dart';
import 'project.dart';
import 'public_api.dart' show publicParameters;

const maxFileLines = 800;
const maxConstructorParameters = 15;

/// Lines that describe the code and never decide the result.
List<String> sizeReport(Project project) {
  final out = <String>[];
  final files = project.files.values.toList()
    ..sort((a, b) => a.relative.compareTo(b.relative));
  for (final file in files) {
    if (file.lineCount > maxFileLines) {
      out.add('report large-file ${file.relative} ${file.lineCount} lines');
    }
    for (final declaration in file.unit.declarations) {
      if (declaration is! ClassDeclaration) continue;
      final className = declaration.namePart.typeName.lexeme;
      if (className.startsWith('_')) continue;
      final primary = declaration.namePart;
      if (primary is PrimaryConstructorDeclaration) {
        final count = publicParameters(primary.formalParameters).length;
        if (count > maxConstructorParameters) {
          out.add(
            'report wide-constructor ${file.relative}:${file.lineOf(primary.offset)} '
            '$className.new $count parameters',
          );
        }
      }
      for (final member in declaration.body.members) {
        if (member is! ConstructorDeclaration) continue;
        final name = member.name?.lexeme;
        if (name != null && name.startsWith('_')) continue;
        final count = publicParameters(member.parameters).length;
        if (count > maxConstructorParameters) {
          out.add(
            'report wide-constructor ${file.relative}:${file.lineOf(member.offset)} '
            '$className.${name ?? 'new'} $count parameters',
          );
        }
      }
    }
  }
  return out;
}

int _netLines(String root, String base, String directory) {
  var net = 0;
  final numstat = git(root, [
    'diff',
    '--numstat',
    '--no-renames',
    base,
    '--',
    directory,
  ]);
  for (final line in const LineSplitter().convert(numstat ?? '')) {
    final parts = line.split('\t');
    if (parts.length < 3) continue;
    net += (int.tryParse(parts[0]) ?? 0) - (int.tryParse(parts[1]) ?? 0);
  }
  final untracked = git(root, [
    'ls-files',
    '--others',
    '--exclude-standard',
    '--',
    directory,
  ]);
  for (final path in const LineSplitter().convert(untracked ?? '')) {
    final file = File('$root/$path');
    if (file.existsSync()) {
      net += const LineSplitter().convert(file.readAsStringSync()).length;
    }
  }
  return net;
}

/// What changed since [base]: net lines of `lib/src`, and the rows of the two
/// lists, compared with the committed versions so that lists git does not
/// track yet are included. Empty when [root] is not a git repository; the
/// caller has checked that [base] exists.
List<String> baseReport(String root, String base) {
  final out = <String>[];
  String signed(int n) => '${n >= 0 ? '+' : ''}$n';
  final net = _netLines(root, base, 'packages/frost_ui/lib/src');
  out.add('report lib/src net lines since $base: ${signed(net)}');
  // Code moved to frost_data leaves lib/src, so its growth is shown too.
  if (Directory('$root/packages/frost_data/lib/src').existsSync()) {
    final data = _netLines(root, base, 'packages/frost_data/lib/src');
    out.add('report frost_data lib/src net lines since $base: ${signed(data)}');
  }
  for (final name in [publicApiName, allowlistName]) {
    final file = File('$root/tool/library_health/$name');
    final before = _rows(fileAtBase(root, base, 'tool/library_health/$name'));
    final now = _rows(file.existsSync() ? file.readAsStringSync() : null);
    final added = _minus(now, before);
    final removed = _minus(before, now);
    out.add(
      'report $name since $base: +${added.length} -${removed.length}',
    );
    for (final row in added) {
      out.add('  +$row');
    }
    for (final row in removed) {
      out.add('  -$row');
    }
  }
  return out;
}

List<String> _rows(String? text) => [
      for (final line in const LineSplitter().convert(text ?? ''))
        if (line.trim().isNotEmpty && !line.startsWith('#')) line,
    ];

/// The rows of [a] that [b] does not have, counting repeats.
List<String> _minus(List<String> a, List<String> b) {
  final left = <String, int>{};
  for (final row in b) {
    left[row] = (left[row] ?? 0) + 1;
  }
  final out = <String>[];
  for (final row in a) {
    final n = left[row] ?? 0;
    if (n > 0) {
      left[row] = n - 1;
    } else {
      out.add(row);
    }
  }
  return out;
}
