import 'dart:io';

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/source/line_info.dart';

/// How the `file` field marks code of the `frost_data` package.
const dataPrefix = 'frost_data:';

/// A parsed source file of the library.
class SourceFile {
  SourceFile(this.path, this.relative, this.text, this.unit, this.lineInfo,
      this.errors);

  /// Absolute, forward slashes.
  final String path;

  /// Relative to `lib/src`; the barrel is `../frost_ui.dart`. Files of
  /// `frost_data` carry [dataPrefix], as in `frost_data:list_source.dart`.
  final String relative;
  final String text;
  final CompilationUnit unit;
  final LineInfo lineInfo;
  final List<({int line, String message})> errors;

  int lineOf(int offset) => lineInfo.getLocation(offset).lineNumber;

  /// Number of lines, a trailing newline not counted as another line.
  int get lineCount {
    if (text.isEmpty) return 0;
    final breaks = '\n'.allMatches(text).length;
    return text.endsWith('\n') ? breaks : breaks + 1;
  }

  /// Whether the file belongs to the `frost_data` package.
  bool get isData => relative.startsWith(dataPrefix);

  String get _local =>
      isData ? relative.substring(dataPrefix.length) : relative;

  /// Whether the file is in `lib/src`.
  bool get isSource => !_local.startsWith('../');

  /// A public entry: a Dart file directly in `lib`.
  bool get isEntry =>
      _local.startsWith('../') && !_local.substring(3).contains('/');

  /// First directory under `lib/src`, or null for a file directly in it or
  /// outside `src`.
  String? get layerDirectory {
    if (!isSource || isData) return null;
    final slash = relative.indexOf('/');
    return slash < 0 ? null : relative.substring(0, slash);
  }
}

String slashes(String path) => path.replaceAll('\\', '/');

String normalizePath(String path) {
  final parts = <String>[];
  for (final part in slashes(path).split('/')) {
    if (part == '.' || (part.isEmpty && parts.isNotEmpty)) continue;
    if (part == '..' && parts.isNotEmpty && parts.last != '..') {
      parts.removeLast();
    } else {
      parts.add(part);
    }
  }
  return parts.join('/');
}

/// Every Dart file under `packages/frost_ui/lib` and `packages/frost_data/lib`.
class Project {
  Project._(this.root, this.libDirectory, this.files);

  final String root;
  final String libDirectory;

  /// Where `frost_data` keeps its code, whether or not the package exists.
  String get dataLibDirectory => '$root/packages/frost_data/lib';

  final Map<String, SourceFile> files;

  String get srcDirectory => '$libDirectory/src';

  /// The public entries: every Dart file directly in `lib`.
  List<SourceFile> get entries => [
        for (final f in files.values)
          if (f.isEntry) f,
      ];

  /// The files under `lib/src`.
  List<SourceFile> get sourceFiles => [
        for (final f in files.values)
          if (f.isSource) f,
      ];

  static Project? load(String rootPath) {
    final root = normalizePath(Directory(rootPath).absolute.path);
    final lib = '$root/packages/frost_ui/lib';
    if (!Directory('$lib/src').existsSync()) return null;
    final dataLib = '$root/packages/frost_data/lib';
    final paths = <String>[
      for (final directory in [lib, dataLib])
        if (Directory(directory).existsSync())
          for (final entity in Directory(directory).listSync(recursive: true))
            if (entity is File && entity.path.endsWith('.dart'))
              normalizePath(entity.path),
    ]..sort();
    final files = <String, SourceFile>{};
    String relativeTo(String directory, String path) =>
        path.startsWith('$directory/src/')
            ? path.substring('$directory/src/'.length)
            : '../${path.substring('$directory/'.length)}';
    for (final path in paths) {
      final text = File(path).readAsStringSync();
      final result = parseString(
        content: text,
        path: path,
        throwIfDiagnostics: false,
        featureSet: FeatureSet.latestLanguageVersion(),
      );
      final relative = path.startsWith('$dataLib/')
          ? '$dataPrefix${relativeTo(dataLib, path)}'
          : relativeTo(lib, path);
      files[path] = SourceFile(
        path,
        relative,
        text,
        result.unit,
        result.lineInfo,
        [
          for (final error in result.errors)
            (
              line: result.lineInfo.getLocation(error.offset).lineNumber,
              message: error.message.replaceAll('\n', ' '),
            ),
        ],
      );
    }
    return Project._(root, lib, files);
  }

  /// The file a directive URI names, or null for other packages and `dart:`.
  SourceFile? resolve(SourceFile from, String uri) {
    final target = resolvePath(from, uri);
    return target == null ? null : files[target];
  }

  /// Like [resolve], but returns the normalized path even when it names no
  /// file the gate has parsed, for URIs that point inside the library.
  String? resolvePath(SourceFile from, String uri) {
    if (uri.startsWith('package:frost_ui/')) {
      return normalizePath('$libDirectory/${uri.substring(17)}');
    }
    if (uri.startsWith('package:frost_data/')) {
      return normalizePath('$dataLibDirectory/${uri.substring(19)}');
    }
    if (uri.contains(':')) return null;
    return normalizePath(
      '${from.path.substring(0, from.path.lastIndexOf('/'))}/$uri',
    );
  }
}
