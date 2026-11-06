// App audit. From the repository root:
// dart --disable-dart-dev tool/check_app_ui.dart <app/lib> [--report|--strict]
// No analyzer dependency and no ignore directives. R8 is report-only.
// Conservative lexical candidates, not a Dart type resolver. In particular,
// Transform.translate is reported for review: text cannot prove alignment intent.
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const generatedSuffixes = [
  '.g.dart',
  '.freezed.dart',
  '.gr.dart',
  '.mocks.dart',
  '.gen.dart',
];
const generatedNames = ['l10n.dart', 'messages_all.dart'];
const generatedPrefixes = ['app_localizations', 'messages_'];
const sampleLimit = 5;
const materialComponents = [
  'ElevatedButton',
  'TextButton',
  'FilledButton',
  'OutlinedButton',
  'IconButton',
  'Switch',
  'Checkbox',
  'Radio',
  'Slider',
  'TextField',
  'Scaffold',
  'AppBar',
  'NavigationRail',
  'NavigationBar',
  'TabBar',
  'PopupMenuButton',
  'AlertDialog',
  'SnackBar',
  'ListTile',
  'Card',
  'Chip',
  'PopupMenuItem',
  'showMenu',
  'showDialog',
  'Dialog',
  'CheckboxListTile',
  'ExpansionTile',
  'Badge',
  'Divider',
  'LinearProgressIndicator',
  'CircularProgressIndicator',
  'Tooltip',
];
const numberPattern =
    r'-?(?:0[xX][0-9a-fA-F]+|(?:\d+(?:\.\d+)?|\.\d+)(?:[eE][+-]?\d+)?)';

// R13: names of arguments that carry action or status text. FrostText's first
// positional argument counts too.
const ellipsisName =
    r'^(?:label|title|tooltip|semanticLabel|placeholder|message|description|\w*(?:Label|Title|Tooltip))$';
const textResourceSuffixes = ['.i18n.json', '.i18n.yaml', '.i18n.yml', '.arb'];

enum Rule { r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13 }

/// [key] is the key path of a text resource entry; its [line] is 0 when the
/// entry cannot be located in the file.
typedef Finding = ({
  Rule rule,
  String path,
  int offset,
  int line,
  int column,
  String? key,
});
typedef Literal = ({int start, int end, String value});
typedef Comment = ({int start, int end, String value});
typedef Lexed = ({String code, List<Literal> literals, List<Comment> comments});

/// Masks complete strings/comments, including raw/triple strings and nested
/// comments, while retaining offsets. Interpolated string bodies are masked too.
Lexed lex(String source) {
  final chars = source.split('');
  final literals = <Literal>[];
  final comments = <Comment>[];
  void mask(int start, int end) {
    for (var i = start; i < end; i++) {
      if (chars[i] != '\n' && chars[i] != '\r') chars[i] = ' ';
    }
  }

  var i = 0;
  while (i < source.length) {
    final start = i;
    if (source.startsWith('//', i)) {
      final end = source.indexOf('\n', i);
      i = end < 0 ? source.length : end;
      comments.add((start: start, end: i, value: source.substring(start, i)));
      mask(start, i);
    } else if (source.startsWith('/*', i)) {
      i += 2;
      var depth = 1;
      while (i < source.length && depth > 0) {
        if (source.startsWith('/*', i)) {
          depth++;
          i += 2;
        } else if (source.startsWith('*/', i)) {
          depth--;
          i += 2;
        } else {
          i++;
        }
      }
      comments.add((start: start, end: i, value: source.substring(start, i)));
      mask(start, i);
    } else if (source[i] == "'" || source[i] == '"') {
      final quote = source[i];
      final delimiter = source.startsWith(quote * 3, i) ? quote * 3 : quote;
      final raw = i > 0 && source[i - 1] == 'r';
      i += delimiter.length;
      final body = i;
      var end = i;
      while (i < source.length) {
        if (!raw && source[i] == r'\') {
          i = (i + 2).clamp(0, source.length);
        } else if (source.startsWith(delimiter, i)) {
          end = i;
          i += delimiter.length;
          break;
        } else {
          i++;
          end = i;
        }
      }
      literals.add((start: start, end: i, value: source.substring(body, end)));
      mask(start, i);
    } else {
      i++;
    }
  }
  return (code: chars.join(), literals: literals, comments: comments);
}

bool isGenerated(String path) {
  final name = path.replaceAll(r'\', '/').split('/').last;
  return generatedSuffixes.any(name.endsWith) ||
      generatedNames.contains(name) ||
      generatedPrefixes.any(name.startsWith);
}

int? closingParen(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if (code[i] == '(') depth++;
    if (code[i] == ')') {
      depth--;
      if (depth == 0) return i;
    }
  }
  return null;
}

List<({int start, int end, String? name})> arguments(
  String code,
  int open,
  int close,
) {
  final result = <({int start, int end, String? name})>[];
  var start = open + 1;
  var depth = 0;
  for (var i = start; i <= close; i++) {
    final char = code[i];
    if (i == close || (char == ',' && depth == 0)) {
      final named = RegExp(r'^\s*(\w+)\s*:')
          .firstMatch(code.substring(start, i));
      result.add((
        start: start + (named?.end ?? 0),
        end: i,
        name: named?.group(1),
      ));
      start = i + 1;
    } else if ('([{'.contains(char)) {
      depth++;
    } else if (')]}'.contains(char)) {
      depth--;
    }
  }
  return result;
}

List<Finding> scanSource(String source, String relativePath) {
  if (isGenerated(relativePath)) return [];
  final parsed = lex(source);
  final code = parsed.code;
  final hits = <({Rule rule, int offset})>{};
  void add(Rule rule, int offset) => hits.add((rule: rule, offset: offset));
  void matches(Rule rule, String pattern) {
    for (final match in RegExp(pattern).allMatches(code)) {
      add(rule, match.start);
    }
  }

  final custom = relativePath.replaceAll(r'\', '/').startsWith('ui/custom/');
  if (custom) {
    final firstCode = code.indexOf(RegExp(r'\S'));
    final declared = parsed.comments.any(
      (c) =>
          (firstCode < 0 || c.start < firstCode) &&
          RegExp(r'^//\s*(?:app-owned|frost-escape):\s*\S[^\r\n]*$').hasMatch(c.value.trim()),
    );
    if (!declared) add(Rule.r9, 0);
  }
  // App-owned widgets in ui/custom/ may draw and set text themselves; they
  // still take no Material, no Material icons, no literal colours and no
  // numeric radii.
  {
    // Import URI strings are inspected only when preceded by the import token;
    // literal text saying "import ..." never creates a finding.
    for (final statement in RegExp(r'\bimport\b[^;]*;').allMatches(code)) {
      for (final literal in parsed.literals) {
        if (literal.start >= statement.start &&
            literal.end <= statement.end &&
            (literal.value == 'package:flutter/material.dart' ||
                literal.value == 'package:flutter/cupertino.dart')) {
          add(Rule.r1, literal.start);
        }
      }
    }
    matches(
      Rule.r2,
      r'\b(?:' +
          materialComponents.join('|') +
          r')\b(?=\s*(?:<[^;(){}]*>)?\s*[.(])',
    );
    matches(Rule.r3, r'\bIcons\s*\.');
    matches(Rule.r4, r'\bColor\s*\(\s*0[xX][0-9a-fA-F]+|\bColors\s*\.');
    matches(
      Rule.r7,
      r'\b(?:BorderRadius|Radius)\s*\.\s*circular\s*\(\s*' +
          numberPattern +
          r'\s*\)',
    );
  }
  if (!custom) {
    matches(
      Rule.r5,
      r'\b(?:BoxDecoration|ShapeDecoration|CustomPaint|ClipRRect|ClipPath)\s*\(',
    );
    for (final m in RegExp(r'\bContainer\s*\(').allMatches(code)) {
      final close = closingParen(code, m.end - 1);
      if (close != null &&
          arguments(code, m.end - 1, close).any((a) => a.name == 'decoration'))
        add(Rule.r5, m.start);
    }
    matches(
      Rule.r6,
      r'\bTextStyle\s*\(|\b(?:fontSize|fontWeight)\s*:|\bTheme\s*\.\s*of\s*\(',
    );
    matches(Rule.r10, r'\bbleed\s*:|\bTransform\s*\.\s*translate\s*\(');
    matches(
      Rule.r11,
      r'\b(?:Text(?:\s*\.\s*rich)?|RichText|SelectableText(?:\s*\.\s*rich)?)\s*\(',
    );
    matches(Rule.r12, r'\bSkeletonizer\s*(?:\.\s*\w+)?\s*\(|\bSkeleton\s*\.');
    for (final constructor in RegExp(
      r'\bEdgeInsets(?:Directional)?\s*\.\s*(?:all|symmetric|only|fromLTRB|fromSTEB)\s*\(|\bSizedBox\s*\(',
    ).allMatches(code)) {
      final open = constructor.end - 1;
      final close = closingParen(code, open);
      if (close == null) continue;
      final box = constructor.group(0)!.startsWith('SizedBox');
      for (final arg in arguments(code, open, close)) {
        if (box && arg.name != 'width' && arg.name != 'height') continue;
        final value = code.substring(arg.start, arg.end);
        if (!box) {
          final negative = RegExp(r'^\s*(-)\s*\w').firstMatch(value);
          if (negative != null) add(Rule.r10, arg.start + value.indexOf('-'));
        }
        // Direct literals only: coefficients and nested constructors are not
        // counted as inset values. Each conditional literal is still reported.
        var depth = 0;
        var cursor = 0;
        for (final n in RegExp(numberPattern).allMatches(value)) {
          while (cursor < n.start) {
            if ('([{'.contains(value[cursor])) depth++;
            if (')]}'.contains(value[cursor])) depth--;
            cursor++;
          }
          final before = value.substring(0, n.start).trimRight();
          final after = value.substring(n.end).trimLeft();
          if (depth != 0 ||
              RegExp(r'[\w.]$').hasMatch(before) ||
              RegExp(r'^[\w.]').hasMatch(after))
            continue;
          if (RegExp(r'[*%/]$').hasMatch(before) ||
              RegExp(r'^[*%/]').hasMatch(after))
            continue;
          final literal = n.group(0)!;
          final numeric =
              literal.replaceFirst('-', '').toLowerCase().startsWith('0x')
              ? int.parse(
                  literal.replaceFirst('-', '').substring(2),
                  radix: 16,
                ).toDouble()
              : double.parse(literal);
          if (numeric != 0) add(Rule.r8, arg.start + n.start);
          if (!box && literal.startsWith('-') && numeric != 0)
            add(Rule.r10, arg.start + n.start);
        }
      }
    }
  }
  // R13: Truncation belongs to the component, so action and status text does
  // not end in an ellipsis. Only literals passed as the arguments named by
  // carriesText count; adjacent literals (or joined with +) form one string,
  // judged by its last literal, and ternary branches are judged one by one.
  for (final (index, literal) in parsed.literals.indexed) {
    if (!endsWithEllipsis(literal.value)) continue;
    if (index + 1 < parsed.literals.length &&
        RegExp(r'^\s*\+?\s*$').hasMatch(
          code.substring(literal.end, parsed.literals[index + 1].start),
        )) {
      continue;
    }
    var first = index;
    while (first > 0 &&
        RegExp(r'^\s*\+?\s*$').hasMatch(
          code.substring(
            parsed.literals[first - 1].end,
            parsed.literals[first].start,
          ),
        )) {
      first--;
    }
    var start = parsed.literals[first].start;
    if (start > 0 && code[start - 1] == 'r') start--;
    if (carriesText(code, start)) add(Rule.r13, literal.start);
  }
  final sorted = hits.toList()
    ..sort((a, b) {
      final rule = a.rule.index.compareTo(b.rule.index);
      return rule == 0 ? a.offset.compareTo(b.offset) : rule;
    });
  return [
    for (final hit in sorted)
      () {
        final prefix = source.substring(0, hit.offset);
        final line = '\n'.allMatches(prefix).length + 1;
        final last = prefix.lastIndexOf('\n');
        return (
          rule: hit.rule,
          path: relativePath,
          offset: hit.offset,
          line: line,
          column: hit.offset - last,
          key: null,
        );
      }(),
  ];
}

bool endsWithEllipsis(String value) {
  final text = value.trimRight();
  return text.endsWith('\u2026') ||
      text.endsWith('...') ||
      text.endsWith(r'\u2026') ||
      text.endsWith(r'\u{2026}');
}

bool isTextResource(String path) => textResourceSuffixes.any(path.endsWith);

/// Whether the expression starting at [start] is an argument that carries
/// action or status text: a named argument from [ellipsisName], or the first
/// argument of FrostText. Only brackets balanced inside the argument count, so
/// a literal in a ternary branch qualifies and one inside a nested call does
/// not.
bool carriesText(String code, int start) {
  var depth = 0;
  var i = start - 1;
  for (; i >= 0; i--) {
    final char = code[i];
    if (')]}'.contains(char)) {
      depth++;
    } else if ('([{'.contains(char)) {
      if (depth == 0) break;
      depth--;
    } else if (char == ',' && depth == 0) {
      break;
    } else if (char == ';' && depth == 0) {
      return false;
    }
  }
  if (i < 0) return false;
  final named = RegExp(r'^\s*(\w+)\s*:(?!:)')
      .firstMatch(code.substring(i + 1, start));
  if (named != null) return RegExp(ellipsisName).hasMatch(named.group(1)!);
  return code[i] == '(' &&
      RegExp(r'\bFrostText\s*(?:\.\s*\w+\s*)?$')
          .hasMatch(code.substring(math.max(0, i - 40), i));
}

/// Entries of a text resource whose string value ends in an ellipsis, as key
/// paths: nested JSON objects join with dots and lists add `[index]`. ARB
/// metadata (keys starting with `@`) is not text and is skipped. YAML is read
/// as the plain `key: value` / `- value` subset slang files use.
List<Finding> scanTextResource(String source, String relativePath) {
  final entries =
      relativePath.endsWith('.yaml') || relativePath.endsWith('.yml')
      ? yamlStrings(source)
      : jsonStrings(source, skipMetadata: relativePath.endsWith('.arb'));
  return [
    for (final entry in entries)
      if (endsWithEllipsis(entry.value))
        (
          rule: Rule.r13,
          path: relativePath,
          offset: entry.offset,
          line: '\n'.allMatches(source.substring(0, entry.offset)).length + 1,
          column: 0,
          key: entry.key,
        ),
  ];
}

typedef TextEntry = ({String key, String value, int offset});

/// String values of a JSON document with their key paths and the offset of
/// each value. A malformed document yields no entries.
List<TextEntry> jsonStrings(String source, {bool skipMetadata = false}) {
  final result = <TextEntry>[];
  var i = 0;
  void space() {
    while (i < source.length && ' \t\r\n'.contains(source[i])) {
      i++;
    }
  }

  String string() {
    final start = i++;
    while (i < source.length && source[i] != '"') {
      i += source[i] == r'\' ? 2 : 1;
    }
    if (i >= source.length) throw const FormatException('unterminated string');
    i++;
    return jsonDecode(source.substring(start, i)) as String;
  }

  void value(String key) {
    space();
    if (i >= source.length) throw const FormatException('unexpected end');
    final char = source[i];
    if (char == '"') {
      final offset = i;
      result.add((key: key, value: string(), offset: offset));
    } else if (char == '{' || char == '[') {
      final object = char == '{';
      i++;
      var index = 0;
      while (true) {
        space();
        if (i < source.length && source[i] == (object ? '}' : ']')) {
          i++;
          return;
        }
        if (object) {
          space();
          if (i >= source.length || source[i] != '"') {
            throw const FormatException('expected key');
          }
          final name = string();
          space();
          if (i >= source.length || source[i] != ':') {
            throw const FormatException('expected colon');
          }
          i++;
          final mark = result.length;
          value(key.isEmpty ? name : key + '.' + name);
          if (skipMetadata && name.startsWith('@')) {
            result.removeRange(mark, result.length);
          }
        } else {
          value(key + '[' + (index++).toString() + ']');
        }
        space();
        if (i < source.length && source[i] == ',') i++;
      }
    } else {
      while (i < source.length && !',]} \t\r\n'.contains(source[i])) {
        i++;
      }
    }
  }

  try {
    value('');
  } on FormatException {
    return [];
  }
  return result;
}

/// String values of a YAML mapping tree with their key paths. Reads nested
/// `key:` blocks by indentation, `key: value` scalars (plain, single or double
/// quoted) and `- value` list items; block scalars and flow collections are
/// skipped.
List<TextEntry> yamlStrings(String source) {
  final result = <TextEntry>[];
  final stack = <({int indent, String key})>[];
  final counters = <String, int>{};
  String scalar(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return text;
    final quote = text[0];
    if (quote == '"' || quote == "'") {
      final close = text.indexOf(quote, 1);
      if (close > 0) return text.substring(1, close);
    }
    final comment = text.indexOf(' #');
    return comment >= 0 ? text.substring(0, comment).trimRight() : text;
  }

  var offset = 0;
  for (final line in source.split('\n')) {
    final lineOffset = offset;
    offset += line.length + 1;
    final trimmed = line.trimRight();
    final content = trimmed.trimLeft();
    if (content.isEmpty || content.startsWith('#')) continue;
    final indent = trimmed.length - content.length;
    while (stack.isNotEmpty && stack.last.indent >= indent) {
      stack.removeLast();
    }
    final parent = stack.map((e) => e.key).join('.');
    String path(String leaf) => parent.isEmpty
        ? leaf
        : leaf.startsWith('[')
        ? parent + leaf
        : parent + '.' + leaf;
    if (content.startsWith('- ')) {
      final index = counters.update(parent, (n) => n + 1, ifAbsent: () => 0);
      final value = scalar(content.substring(2));
      if (value.isNotEmpty && !'|>[{'.contains(value[0])) {
        result.add((
          key: path('[$index]'),
          value: value,
          offset: lineOffset + indent,
        ));
      }
      continue;
    }
    final match = RegExp(
      r'''^((?:"[^"]*"|'[^']*'|[^\s:"'#][^:#]*?))\s*:(?:\s+(.*))?$''',
    ).firstMatch(content);
    if (match == null) continue;
    final name = scalar(match.group(1)!);
    final rest = (match.group(2) ?? '').trim();
    if (rest.isEmpty || rest.startsWith('#')) {
      stack.add((indent: indent, key: name));
      counters.remove(stack.map((e) => e.key).join('.'));
    } else {
      final value = scalar(rest);
      if (value.isNotEmpty && !'|>[{&*!'.contains(rest[0])) {
        result.add((
          key: path(name),
          value: value,
          offset: lineOffset + indent,
        ));
      }
    }
  }
  return result;
}

List<Finding> scanDirectory(Directory root) {
  final files =
      root
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where(
            (file) => file.path.endsWith('.dart') || isTextResource(file.path),
          )
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
  return [
    for (final file in files)
      ...() {
        final relative = file.path
            .substring(
              root.path.replaceFirst(RegExp(r'[/\\]+$'), '').length + 1,
            )
            .replaceAll(r'\', '/');
        final source = file.readAsStringSync();
        return isTextResource(file.path)
            ? scanTextResource(source, relative)
            : scanSource(source, relative);
      }(),
  ];
}

void main(List<String> args) {
  final paths = args.where((a) => !a.startsWith('--')).toList();
  if (paths.length != 1 ||
      args.any(
        (a) => a.startsWith('--') && a != '--report' && a != '--strict',
      ) ||
      (args.contains('--report') && args.contains('--strict'))) {
    stderr.writeln('Usage: check_app_ui.dart <app/lib> [--report|--strict]');
    exitCode = 64;
    return;
  }
  final root = Directory(paths.single);
  if (!root.existsSync()) {
    stderr.writeln('Missing App lib directory: ' + root.path);
    exitCode = 64;
    return;
  }
  final findings = scanDirectory(root);
  stdout.writeln('App UI lexical audit: ' + root.absolute.path);
  for (final rule in Rule.values) {
    final hits = findings.where((hit) => hit.rule == rule).toList();
    stdout.writeln(
      rule.name.toUpperCase() +
          ': ' +
          hits.length.toString() +
          (rule == Rule.r8 ? ' [report]' : ' [fail]'),
    );
    for (final hit in hits.take(sampleLimit)) {
      stdout.writeln(
        hit.key == null
            ? '  ' +
                  hit.path +
                  ':' +
                  hit.line.toString() +
                  ':' +
                  hit.column.toString()
            : '  ' +
                  hit.path +
                  (hit.line > 0 ? ':' + hit.line.toString() : '') +
                  ' ' +
                  hit.key!,
      );
    }
    if (hits.length > sampleLimit)
      stdout.writeln(
        '  ... ' + (hits.length - sampleLimit).toString() + ' more',
      );
  }
  final failures = findings.where((hit) => hit.rule != Rule.r8).length;
  stdout.writeln('failure candidates: ' + failures.toString());
  if (!args.contains('--report') && failures > 0) exitCode = 1;
}
