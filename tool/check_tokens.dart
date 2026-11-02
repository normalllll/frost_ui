// Token audit. Run from the repository root:
// dart --disable-dart-dev tool/check_tokens.dart [--report|--strict]
// Counts occurrences, including multiple literals on the same line.
// Includes EdgeInsetsDirectional and FontWeight literals in conditional branches.
// Comments and strings are masked without changing source offsets.
import 'dart:io';

const _number =
    r'-?(?:0[xX][0-9a-fA-F]+|(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?)';
final _numeric = RegExp('(?<![\\w.])$_number(?![\\w.])');
final _radius = RegExp(
  '\\b(?:BorderRadius|Radius)\\s*\\.\\s*circular\\s*\\(\\s*($_number)\\s*\\)',
);
final _color = RegExp(
  r'\bColor\s*\(\s*0[xX][0-9a-fA-F]+\s*\)|\bColors\s*\.\s*(\w+)',
);
final _spacing = RegExp(
  r'\bEdgeInsets(?:Directional)?\s*\.\s*(all|symmetric|only|fromLTRB|fromSTEB)\s*\(|\b(SizedBox)\s*\(',
);
final _text = RegExp('\\bfontSize\\s*:\\s*($_number)\\s*(?=[,)])');
final _fontWeight = RegExp(r'\bfontWeight\s*:');
final _weightLiteral = RegExp(r'\bFontWeight\s*\.\s*w[1-9]00\b');

final _progress = RegExp(
  r'\b(?:CircularProgressIndicator|LinearProgressIndicator)\b',
);

/// Progress names in executable code, excluding comments and strings.
Iterable<int> progressOffsets(String source) =>
    _progress.allMatches(_codeOnly(source)).map((match) => match.start);

enum Rule { radius, color, spacing, text, progress }

typedef Hit = ({int offset, Rule rule});

void main(List<String> args) {
  if (args.any((arg) => arg != '--report' && arg != '--strict') ||
      (args.contains('--report') && args.contains('--strict'))) {
    stderr.writeln('Usage: check_tokens.dart [--report|--strict]');
    exitCode = 64;
    return;
  }
  final root = Directory('packages/frost_ui/lib/src');
  if (!root.existsSync()) {
    stderr.writeln('Missing ' + root.path + '; run from the repository root.');
    exitCode = 64;
    return;
  }
  final files =
      [root, Directory('packages/frost_data/lib/src')]
          .where((directory) => directory.existsSync())
          .expand(
            (directory) =>
                directory.listSync(recursive: true, followLinks: false),
          )
          .whereType<File>()
          .where((file) {
            final path = file.path.replaceAll('\\', '/');
            return path.endsWith('.dart') &&
                !path.startsWith(root.path + '/foundation/');
          })
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  final counts = {for (final rule in Rule.values) rule: 0};
  for (final file in files) {
    final source = file.readAsStringSync();
    final code = _codeOnly(source);
    final hits = <Hit>[
      for (final match in _radius.allMatches(code))
        (offset: match.start, rule: Rule.radius),
      for (final match in _color.allMatches(code))
        if (match.group(1) != 'transparent')
          (offset: match.start, rule: Rule.color),
      for (final match in _text.allMatches(code))
        (offset: match.start, rule: Rule.text),
      for (final offset in progressOffsets(source))
        (offset: offset, rule: Rule.progress),
    ];
    for (final property in _fontWeight.allMatches(code)) {
      final end = _argumentEnd(code, property.end);
      for (final weight in _weightLiteral.allMatches(
        code.substring(property.end, end),
      )) {
        hits.add((offset: property.end + weight.start, rule: Rule.text));
      }
    }
    for (final constructor in _spacing.allMatches(code)) {
      final open = constructor.end - 1;
      final close = _closingParen(code, open);
      if (close == null) continue;
      final isBox = constructor.group(2) == 'SizedBox';
      var start = open + 1;
      while (start < close) {
        final end = _argumentEnd(code, start);
        final argument = code.substring(start, end);
        final named = RegExp(r'^\s*(\w+)\s*:').firstMatch(argument);
        if (!isBox ||
            named != null &&
                (named.group(1) == 'width' || named.group(1) == 'height')) {
          final valueStart = start + (named?.end ?? 0);
          for (final offset in _spacingNumbers(code, valueStart, end)) {
            hits.add((offset: offset, rule: Rule.spacing));
          }
        }
        start = end + 1;
      }
    }
    hits.sort((a, b) {
      final order = a.offset.compareTo(b.offset);
      return order == 0 ? a.rule.index.compareTo(b.rule.index) : order;
    });
    final lines = source.split('\n');
    var line = 0;
    var lineStart = 0;
    for (final hit in hits) {
      while (line + 1 < lines.length &&
          lineStart + lines[line].length < hit.offset) {
        lineStart += lines[line].length + 1;
        line++;
      }
      counts[hit.rule] = counts[hit.rule]! + 1;
      stdout.writeln(
        file.path.replaceAll('\\', '/') +
            ':' +
            (line + 1).toString() +
            ': ' +
            hit.rule.name +
            ': ' +
            lines[line].trim(),
      );
    }
  }
  final total = counts.values.fold(0, (sum, count) => sum + count);
  for (final rule in Rule.values) {
    stdout.writeln(rule.name + ': ' + counts[rule].toString());
  }
  stdout.writeln('total: $total');
  if (!args.contains('--report') && total > 0) exitCode = 1;
}

// Inspect only the actual argument value. Nested constructor/call arguments
// belong to that object, not to this inset or box. Grouping parentheses and
// conditional branches are retained; multiplicative operands are coefficients.
Iterable<int> _spacingNumbers(String code, int start, int end) sync* {
  final expression = code.substring(start, end);
  final nested = <bool>[];
  var callDepth = 0;
  var cursor = 0;
  for (final number in _numeric.allMatches(expression)) {
    while (cursor < number.start) {
      final char = expression[cursor];
      if (char == '(' || char == '[' || char == '{') {
        final prefix = expression.substring(0, cursor).trimRight();
        final call = char == '(' && RegExp(r'[\w.\]!]$').hasMatch(prefix);
        nested.add(call);
        if (call) callDepth++;
      } else if ((char == ')' || char == ']' || char == '}') &&
          nested.isNotEmpty) {
        if (nested.removeLast()) callDepth--;
      }
      cursor++;
    }
    if (_isZero(number.group(0)!)) continue;
    final before = expression.substring(0, number.start).trimRight();
    final after = expression.substring(number.end).trimLeft();
    final additive =
        RegExp(r'[+-]$').hasMatch(before) ||
        RegExp(r'^[+-]').hasMatch(after) ||
        number.group(0)!.startsWith('-') && RegExp(r'[\w)]$').hasMatch(before);
    if (callDepth > 0 && !additive) continue;
    if (RegExp(r'[*%/]$').hasMatch(before) || RegExp(r'^[*%/]').hasMatch(after))
      continue;
    yield start + number.start;
  }
}

bool _isZero(String literal) {
  final unsigned = literal.startsWith('-') ? literal.substring(1) : literal;
  return unsigned.toLowerCase().startsWith('0x')
      ? int.parse(unsigned.substring(2), radix: 16) == 0
      : double.parse(literal) == 0;
}

// A named argument can contain calls, collections or a conditional expression.
// Only top-level delimiters end it; count each hardcoded branch separately.
int _argumentEnd(String code, int start) {
  var depth = 0;
  for (var index = start; index < code.length; index++) {
    final char = code[index];
    if (depth == 0 &&
        (char == ',' || char == ')' || char == ']' || char == '}'))
      return index;
    if (char == '(' || char == '[' || char == '{') depth++;
    if (char == ')' || char == ']' || char == '}') depth--;
  }
  return code.length;
}

int? _closingParen(String code, int open) {
  var depth = 0;
  for (var index = open; index < code.length; index++) {
    if (code[index] == '(') depth++;
    if (code[index] == ')') {
      depth--;
      if (depth == 0) return index;
    }
  }
  return null;
}

/// Keep newlines and offsets intact so diagnostics refer to the original file.
/// Handles line comments, nested block comments and raw/triple-quoted strings.
String _codeOnly(String source) {
  final chars = source.split('');
  void mask(int start, int end) {
    for (var index = start; index < end; index++) {
      if (chars[index] != '\n' && chars[index] != '\r') chars[index] = ' ';
    }
  }

  var index = 0;
  while (index < source.length) {
    final start = index;
    if (source.startsWith('//', index)) {
      final end = source.indexOf('\n', index);
      index = end < 0 ? source.length : end;
      mask(start, index);
    } else if (source.startsWith('/*', index)) {
      index += 2;
      var depth = 1;
      while (index < source.length && depth > 0) {
        if (source.startsWith('/*', index)) {
          depth++;
          index += 2;
        } else if (source.startsWith('*/', index)) {
          depth--;
          index += 2;
        } else {
          index++;
        }
      }
      mask(start, index);
    } else if (source[index] == "'" || source[index] == '"') {
      final quote = source[index];
      final triple = source.startsWith(quote * 3, index);
      final delimiter = triple ? quote * 3 : quote;
      final raw = index > 0 && source[index - 1] == 'r';
      index += delimiter.length;
      while (index < source.length) {
        if (!raw && source[index] == '\\') {
          index = (index + 2).clamp(0, source.length);
        } else if (source.startsWith(delimiter, index)) {
          index += delimiter.length;
          break;
        } else {
          index++;
        }
      }
      mask(start, index);
    } else {
      index++;
    }
  }
  return chars.join();
}
