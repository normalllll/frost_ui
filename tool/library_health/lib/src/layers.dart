import 'package:analyzer/dart/ast/ast.dart';

import 'model.dart';
import 'project.dart';

const _layerOf = {
  'foundation': 0,
  'primitives': 1,
  'motion': 1,
  'surface': 1,
  'controls': 2,
  'display': 2,
  'feedback': 2,
  'lists': 2,
  'overlays': 2,
  'layout': 2,
  'media': 2,
  'navigation': 3,
  'social': 3,
};

/// The URIs a directive points at, every conditional branch included.
List<String?> _urisOf(Directive directive) => switch (directive) {
      NamespaceDirective() => [
          directive.uri.stringValue,
          for (final configuration in directive.configurations)
            configuration.uri.stringValue,
        ],
      PartDirective() => [directive.uri.stringValue],
      _ => <String?>[],
    };

/// `frost_data` sits above every layer of `frost_ui` and uses its public
/// entries: each reach into `frost_ui`'s other files is a finding, its source
/// may not import its own entries, and `frost_ui` may not reach it.
void _scanDataBoundary(
    Project project, SourceFile file, List<Finding> findings) {
  final dataPrefixPath = '${project.dataLibDirectory}/';
  final libPrefix = '${project.libDirectory}/';
  for (final directive in file.unit.directives) {
    for (final uri in _urisOf(directive)) {
      if (uri == null) continue;
      final target = project.resolvePath(file, uri);
      if (file.isData && target != null && target.startsWith(libPrefix)) {
        final inside = target.substring(libPrefix.length);
        if (inside.contains('/')) {
          findings.add(
            Finding(
              'layers',
              file.relative,
              file.lineOf(directive.offset),
              '-',
              inside.startsWith('src/')
                  ? 'frost_ui:${inside.substring(4)}'
                  : 'frost_ui:../$inside',
            ),
          );
        }
        continue;
      }
      if (target == null || !target.startsWith(dataPrefixPath)) continue;
      final inside = target.substring(dataPrefixPath.length);
      final named = inside.startsWith('src/')
          ? '$dataPrefix${inside.substring(4)}'
          : '$dataPrefix../$inside';
      final reachesEntry = !inside.contains('/');
      if (file.isData && !(file.isSource && reachesEntry)) continue;
      findings.add(
        Finding(
          'layers',
          file.relative,
          file.lineOf(directive.offset),
          '-',
          named,
        ),
      );
    }
  }
}

/// Imports and exports that reach a higher layer, and files outside the layers.
List<Finding> scanLayers(Project project) {
  final findings = <Finding>[];
  final sourcePrefix = '${project.srcDirectory}/';
  final libPrefix = '${project.libDirectory}/';
  for (final file in project.files.values) {
    _scanDataBoundary(project, file, findings);
    if (file.isEntry) continue;
    if (file.isData) {
      if (!file.isSource) {
        findings
            .add(Finding('layers', file.relative, 1, '-', 'unknown directory'));
      }
      continue;
    }
    final directory = file.layerDirectory;
    final layer = directory == null ? null : _layerOf[directory];
    if (layer == null) {
      findings
          .add(Finding('layers', file.relative, 1, '-', 'unknown directory'));
      continue;
    }
    for (final directive in file.unit.directives) {
      for (final uri in _urisOf(directive)) {
        if (uri == null) continue;
        final target = project.resolvePath(file, uri);
        if (target == null) continue;
        // A public entry reaches every layer, so source may not import one.
        if (target.startsWith(libPrefix) &&
            target.endsWith('.dart') &&
            !target.substring(libPrefix.length).contains('/')) {
          findings.add(
            Finding(
              'layers',
              file.relative,
              file.lineOf(directive.offset),
              '-',
              '../${target.substring(libPrefix.length)}',
            ),
          );
          continue;
        }
        if (!target.startsWith(sourcePrefix)) continue;
        final relative = target.substring(sourcePrefix.length);
        final slash = relative.indexOf('/');
        if (slash < 0) continue;
        final targetLayer = _layerOf[relative.substring(0, slash)];
        if (targetLayer != null && targetLayer > layer) {
          findings.add(
            Finding(
              'layers',
              file.relative,
              file.lineOf(directive.offset),
              '-',
              relative,
            ),
          );
        }
      }
    }
  }
  return findings;
}
