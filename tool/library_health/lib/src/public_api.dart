import 'package:analyzer/dart/ast/ast.dart';

import 'model.dart';
import 'project.dart';

/// The symbols every public entry (`lib/*.dart`) exports, as snapshot rows.
List<ApiRow> collectPublicApi(Project project) {
  final rows = <String, ApiRow>{};
  final exports = _Exports(project);
  for (final entry in project.entries) {
    for (final list in exports.namespaceOf(entry, {}).values) {
      for (final row in list) {
        rows.putIfAbsent(row.key, () => row);
      }
    }
  }
  return rows.values.toList();
}

/// Names visible through a library mapped to the rows each name brings.
typedef _Namespace = Map<String, List<ApiRow>>;

class _Exports {
  _Exports(this.project);

  final Project project;

  _Namespace namespaceOf(SourceFile library, Set<String> visiting) {
    final result = <String, List<ApiRow>>{};
    if (!visiting.add(library.path)) return result;
    for (final file in _libraryFiles(library, {})) {
      _declarations(file, result);
    }
    for (final directive in library.unit.directives) {
      if (directive is! ExportDirective) continue;
      // Every branch of a conditional export is followed.
      final uris = [
        directive.uri.stringValue,
        for (final configuration in directive.configurations)
          configuration.uri.stringValue,
      ];
      // A name two branches both declare keeps the rows of each branch.
      final merged = <String, List<ApiRow>>{};
      void merge(_Namespace names) =>
          names.forEach((n, r) => (merged[n] ??= []).addAll(r));
      for (final uri in uris) {
        if (uri == null) continue;
        final target = project.resolve(library, uri);
        if (target == null) {
          if (project.resolvePath(library, uri) != null) continue;
          final external = <String, List<ApiRow>>{};
          _reexport(library, directive, uri, external);
          merge(external);
          continue;
        }
        var exported = namespaceOf(target, visiting);
        for (final combinator in directive.combinators) {
          if (combinator is ShowCombinator) {
            final names = {for (final n in combinator.shownNames) n.name};
            exported = {
              for (final e in exported.entries)
                if (names.contains(e.key)) e.key: e.value,
            };
          } else if (combinator is HideCombinator) {
            final names = {for (final n in combinator.hiddenNames) n.name};
            exported = {
              for (final e in exported.entries)
                if (!names.contains(e.key)) e.key: e.value,
            };
          }
        }
        merge(exported);
      }
      merged.forEach((name, rows) => result.putIfAbsent(name, () => rows));
    }
    visiting.remove(library.path);
    return result;
  }

  Iterable<SourceFile> _libraryFiles(
      SourceFile library, Set<String> seen) sync* {
    if (!seen.add(library.path)) return;
    yield library;
    for (final directive in library.unit.directives) {
      if (directive is! PartDirective) continue;
      final uri = directive.uri.stringValue;
      final part = uri == null ? null : project.resolve(library, uri);
      if (part != null) yield* _libraryFiles(part, seen);
    }
  }

  void _reexport(
    SourceFile library,
    ExportDirective directive,
    String uri,
    _Namespace result,
  ) {
    final line = library.lineOf(directive.offset);
    ApiRow row(String name) => ApiRow('reexport', name, library.relative, line);
    for (final combinator in directive.combinators) {
      if (combinator is ShowCombinator) {
        for (final name in combinator.shownNames) {
          result.putIfAbsent(name.name, () => [row(name.name)]);
        }
        return;
      }
    }
    result.putIfAbsent(uri, () => [row(uri)]);
  }

  void _declarations(SourceFile file, _Namespace result) {
    void add(String name, ApiRow row, [List<ApiRow> more = const []]) {
      if (name.startsWith('_')) return;
      result.putIfAbsent(name, () => [row, ...more]);
    }

    for (final declaration in file.unit.declarations) {
      int line(AstNode node) => file.lineOf(node.offset);
      switch (declaration) {
        case ClassDeclaration():
          final name = declaration.namePart.typeName.lexeme;
          add(
            name,
            ApiRow('class', name, file.relative, line(declaration)),
            [
              ..._constructors(
                  file, name, declaration.namePart, declaration.body.members),
              ..._members(file, name, declaration.body.members),
            ],
          );
        case ClassTypeAlias():
          add(
            declaration.name.lexeme,
            ApiRow('class', declaration.name.lexeme, file.relative,
                line(declaration)),
          );
        case EnumDeclaration():
          final name = declaration.namePart.typeName.lexeme;
          add(
            name,
            ApiRow('enum', name, file.relative, line(declaration)),
            [
              for (final constant in declaration.body.constants)
                if (!constant.name.lexeme.startsWith('_'))
                  ApiRow('member', '$name.${constant.name.lexeme}',
                      file.relative, line(constant)),
              ..._members(file, name, declaration.body.members, isEnum: true),
            ],
          );
        case MixinDeclaration():
          final name = declaration.name.lexeme;
          add(
            name,
            ApiRow('mixin', name, file.relative, line(declaration)),
            _members(file, name, declaration.body.members),
          );
        case ExtensionTypeDeclaration():
          final name = declaration.namePart.typeName.lexeme;
          add(
            name,
            ApiRow('class', name, file.relative, line(declaration)),
            [
              ..._constructors(
                  file, name, declaration.namePart, declaration.body.members),
              ..._members(file, name, declaration.body.members),
            ],
          );
        case GenericTypeAlias():
          final name = declaration.name.lexeme;
          add(name, ApiRow('typedef', name, file.relative, line(declaration)));
        case FunctionTypeAlias():
          final name = declaration.name.lexeme;
          add(name, ApiRow('typedef', name, file.relative, line(declaration)));
        case ExtensionDeclaration():
          final name = declaration.name?.lexeme;
          if (name == null) continue;
          final members = <String, ApiRow>{};
          for (final member in declaration.body.members) {
            if (member is! MethodDeclaration) continue;
            final method = member.name.lexeme;
            if (method.startsWith('_')) continue;
            members.putIfAbsent(
              method,
              () => ApiRow('ext', '$name.$method', file.relative, line(member)),
            );
          }
          add(
            name,
            ApiRow('extension', name, file.relative, line(declaration)),
            members.values.toList(),
          );
        case FunctionDeclaration():
          final name = declaration.name.lexeme;
          add(name, ApiRow('func', name, file.relative, line(declaration)));
        case TopLevelVariableDeclaration():
          for (final variable in declaration.variables.variables) {
            final name = variable.name.lexeme;
            add(name, ApiRow('var', name, file.relative, line(variable)));
          }
        default:
          break;
      }
    }
  }

  static PrimaryConstructorDeclaration? _primary(ClassNamePart? part) =>
      part is PrimaryConstructorDeclaration ? part : null;

  List<ApiRow> _constructors(
    SourceFile file,
    String className,
    ClassNamePart namePart,
    List<ClassMember> members,
  ) {
    final rows = <ApiRow>[];
    final primary = _primary(namePart);
    if (primary != null) {
      final constructor = primary.constructorName?.name.lexeme;
      if (constructor == null || !constructor.startsWith('_')) {
        rows.add(
          ApiRow(
            'ctor',
            '$className.${constructor ?? 'new'}',
            file.relative,
            file.lineOf(primary.offset),
            publicParameters(primary.formalParameters).join(',').ifEmpty('-'),
          ),
        );
      }
    }
    for (final member in members) {
      if (member is! ConstructorDeclaration) continue;
      final constructor = member.name?.lexeme;
      if (constructor != null && constructor.startsWith('_')) continue;
      rows.add(
        ApiRow(
          'ctor',
          '$className.${constructor ?? 'new'}',
          file.relative,
          file.lineOf(member.offset),
          publicParameters(member.parameters).join(',').ifEmpty('-'),
        ),
      );
    }
    return rows;
  }

  static bool _overrides(List<Annotation> metadata) =>
      metadata.any((a) => a.name.name == 'override');

  /// Public methods, getters, setters and fields that are not `@override`.
  /// A field a constructor parameter initializes (`this.label`) is left out:
  /// its name is already in that constructor's parameter list.
  List<ApiRow> _members(
    SourceFile file,
    String owner,
    List<ClassMember> members, {
    bool isEnum = false,
  }) {
    final rows = <String, ApiRow>{};
    void add(String name, AstNode node) {
      if (name.startsWith('_')) return;
      rows.putIfAbsent(
        name,
        () => ApiRow(
            'member', '$owner.$name', file.relative, file.lineOf(node.offset)),
      );
    }

    // Only a public constructor gets a `ctor` row, so only its `this.x`
    // parameters are already listed.
    final initialized = {
      for (final member in members)
        if (member is ConstructorDeclaration &&
            !(member.name?.lexeme.startsWith('_') ?? false) &&
            !isEnum)
          for (final parameter in member.parameters.parameters)
            if (parameter is FieldFormalParameter) parameter.name.lexeme,
    };
    for (final member in members) {
      if (_overrides(member.metadata)) continue;
      if (member is MethodDeclaration) {
        add(member.name.lexeme, member);
      } else if (member is FieldDeclaration) {
        for (final variable in member.fields.variables) {
          final name = variable.name.lexeme;
          if (!initialized.contains(name)) add(name, variable);
        }
      }
    }
    return rows.values.toList();
  }
}

/// Public parameter names of a parameter list, sorted.
List<String> publicParameters(FormalParameterList list) {
  final names = <String>{};
  for (final parameter in list.parameters) {
    var name = parameter.name?.lexeme;
    if (name == null) continue;
    if (name.startsWith('_')) {
      // A private name is public only as a named parameter that initializes a
      // private field.
      if (!parameter.isNamed || name.length == 1) continue;
      name = name.substring(1);
    }
    names.add(name);
  }
  return names.toList()..sort();
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}
