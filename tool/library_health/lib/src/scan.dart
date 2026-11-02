import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

import 'model.dart';
import 'project.dart';

const _widgetBases = {
  'StatelessWidget',
  'StatefulWidget',
  'InheritedWidget',
  'ProxyWidget',
  'InheritedNotifier',
  'AnimatedWidget',
  'ImplicitlyAnimatedWidget',
};

/// How a class name is looked up: a `_` name is private to its file, so the
/// file is part of the key; any other name is shared by all files.
String widgetKey(SourceFile file, String name) =>
    name.startsWith('_') ? '${file.path}#$name' : name;

/// Keys (see [widgetKey]) of every widget class declared in [files],
/// including subclasses of widget classes found anywhere and class aliases of
/// widget bases.
Set<String> collectWidgetClasses(Iterable<SourceFile> files) {
  final parents = <String, ({SourceFile file, String name})>{};
  for (final file in files) {
    for (final declaration in file.unit.declarations) {
      if (declaration is ClassDeclaration) {
        final parent = declaration.extendsClause?.superclass.name.lexeme;
        if (parent != null) {
          parents[widgetKey(file, declaration.namePart.typeName.lexeme)] =
              (file: file, name: parent);
        }
      } else if (declaration is ClassTypeAlias) {
        parents[widgetKey(file, declaration.name.lexeme)] =
            (file: file, name: declaration.superclass.name.lexeme);
      }
    }
  }
  bool isBase(String name) =>
      _widgetBases.contains(name) || name.endsWith('RenderObjectWidget');
  final widgets = <String>{};
  var changed = true;
  while (changed) {
    changed = false;
    parents.forEach((key, parent) {
      if (!widgets.contains(key) &&
          (isBase(parent.name) ||
              widgets.contains(widgetKey(parent.file, parent.name)))) {
        widgets.add(key);
        changed = true;
      }
    });
  }
  return widgets;
}

/// The last identifier of `A` or `prefix.A`, which is the type name once an
/// import prefix is ignored.
String? _lastName(Expression? e) => switch (e) {
      SimpleIdentifier() => e.name,
      PrefixedIdentifier() => e.identifier.name,
      _ => null,
    };

Expression _unparen(Expression e) {
  while (e is ParenthesizedExpression) {
    e = e.expression;
  }
  return e;
}

/// All the syntax rules in a single walk of one file.
class Scanner extends RecursiveAstVisitor<void> {
  Scanner(this.file, this.widgets)
      : basis = file.layerDirectory != 'foundation';

  final SourceFile file;
  final Set<String> widgets;

  /// Whether the basis rule applies to this file.
  final bool basis;
  final List<Finding> findings = [];

  String? _type;
  String? _member;

  /// `runtimeType` reads already counted as part of a comparison.
  final Set<AstNode> _counted = {};

  String get _scope {
    if (_type != null && _member != null) return '$_type.$_member';
    return _type ?? _member ?? '-';
  }

  void _add(String rule, int offset, String detail) {
    findings.add(
      Finding(rule, file.relative, file.lineOf(offset), _scope, detail),
    );
  }

  // ---------------------------------------------------------------- scopes

  void _inType(String? name, void Function() body) {
    final outerType = _type, outerMember = _member;
    _type = name;
    _member = null;
    body();
    _type = outerType;
    _member = outerMember;
  }

  void _inMember(String? name, void Function() body) {
    final outer = _member;
    _member = name;
    body();
    _member = outer;
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    _inType(node.namePart.typeName.lexeme, () {
      final parent = node.extendsClause?.superclass;
      if (parent?.name.lexeme == 'MaterialScrollBehavior') {
        _add('framework', parent!.offset, 'MaterialScrollBehavior');
      }
      super.visitClassDeclaration(node);
    });
  }

  @override
  void visitClassTypeAlias(ClassTypeAlias node) {
    _inType(node.name.lexeme, () {
      if (node.superclass.name.lexeme == 'MaterialScrollBehavior') {
        _add('framework', node.superclass.offset, 'MaterialScrollBehavior');
      }
      super.visitClassTypeAlias(node);
    });
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) =>
      _inType(node.name.lexeme, () => super.visitMixinDeclaration(node));

  @override
  void visitEnumDeclaration(EnumDeclaration node) => _inType(
        node.namePart.typeName.lexeme,
        () => super.visitEnumDeclaration(node),
      );

  @override
  void visitExtensionDeclaration(ExtensionDeclaration node) =>
      _inType(node.name?.lexeme, () => super.visitExtensionDeclaration(node));

  @override
  void visitExtensionTypeDeclaration(ExtensionTypeDeclaration node) => _inType(
        node.namePart.typeName.lexeme,
        () => super.visitExtensionTypeDeclaration(node),
      );

  @override
  void visitMethodDeclaration(MethodDeclaration node) =>
      _inMember(node.name.lexeme, () {
        if (node.name.lexeme == 'hitTest' &&
            node.metadata.any((a) => a.name.name == 'override')) {
          _add('framework', node.name.offset, 'hitTest');
        }
        super.visitMethodDeclaration(node);
      });

  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (node.parent is CompilationUnit) {
      _inMember(node.name.lexeme, () => super.visitFunctionDeclaration(node));
    } else {
      super.visitFunctionDeclaration(node);
    }
  }

  /// Comments, doc comment references included, are not code.
  @override
  void visitComment(Comment node) {}

  // ------------------------------------------------------------- framework

  static const _byName = {
    'addEarlyKeyEventHandler',
    'addLateKeyEventHandler',
    'hitTestInView',
    'visitAncestorElements',
    'visitChildElements',
  };
  static const _routerMethods = {'addRoute', 'addGlobalRoute', 'add'};

  @override
  void visitAssignmentExpression(AssignmentExpression node) {
    final target = node.leftHandSide;
    final name = switch (target) {
      SimpleIdentifier() => target.name,
      PrefixedIdentifier() => target.identifier.name,
      PropertyAccess() => target.propertyName.name,
      _ => null,
    };
    if (name == 'highlightStrategy') {
      _add('framework', target.offset, 'highlightStrategy=');
    }
    super.visitAssignmentExpression(node);
  }

  bool _hasNamedSize(ArgumentList list) => list.arguments.any(
        (a) => a is NamedArgument && a.name.lexeme == 'size',
      );

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName;
    if (name.type.name.lexeme == 'MediaQueryData' &&
        name.name == null &&
        _hasNamedSize(node.argumentList)) {
      _add('framework', node.offset, 'MediaQuery.size');
    }
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.name;
    final target = node.realTarget;
    final targetText = target?.toSource() ?? '';
    final at = node.methodName.offset;
    if (name == 'addHandler' && targetText.contains('HardwareKeyboard')) {
      _add('framework', at, 'HardwareKeyboard.addHandler');
    }
    if (_routerMethods.contains(name) && targetText.contains('pointerRouter')) {
      _add('framework', at, 'pointerRouter');
    }
    if (name == 'copyWith' &&
        _hasNamedSize(node.argumentList) &&
        (targetText.contains('MediaQuery') ||
            targetText.contains('mediaQuery') ||
            (target is SimpleIdentifier && target.name == 'data'))) {
      _add('framework', at, 'MediaQuery.size');
    }
    if (name == 'MediaQueryData' && _hasNamedSize(node.argumentList)) {
      _add('framework', at, 'MediaQuery.size');
    }

    if (basis) {
      final owner = _lastName(target);
      if (owner == 'FrostSizeClass' && name == 'of') {
        _add('basis', at, 'FrostSizeClass');
      }
      if (owner == 'MediaQuery') {
        if (name == 'sizeOf' || name == 'maybeSizeOf') {
          _add('basis', at, 'MediaQuery.size');
        }
        if (name == 'orientationOf' || name == 'maybeOrientationOf') {
          _add('basis', at, 'MediaQuery.orientation');
        }
      }
      if (owner == 'TargetPlatform') {
        _add('basis', at, 'TargetPlatform');
      }
    }

    if (name == 'whereType') {
      for (final argument
          in node.typeArguments?.arguments ?? const <TypeAnnotation>[]) {
        _checkChildType(argument, at);
      }
    }
    if (name == 'catchError') {
      final literals = [
        for (final a in node.argumentList.arguments)
          if (a.argumentExpression case final FunctionExpression f) f,
      ];
      final reported = literals.any((f) {
        final finder = _CallFinder(_reports, throws: true);
        f.accept(finder);
        return finder.found;
      });
      if (!reported) _add('silent', at, 'catch');
    }
    super.visitMethodInvocation(node);
  }

  // ----------------------------------------------------------------- basis

  static const _platformNames = {
    'android',
    'iOS',
    'linux',
    'macOS',
    'windows',
    'fuchsia',
  };

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (node.parent is! Combinator && node.parent is! Label) {
      final name = node.name;
      if (_byName.contains(name)) _add('framework', node.offset, name);
      if (basis && (name == 'defaultTargetPlatform' || name == 'kIsWeb')) {
        _add('basis', node.offset, name);
      }
    }
    super.visitSimpleIdentifier(node);
  }

  @override
  void visitDotShorthandPropertyAccess(DotShorthandPropertyAccess node) {
    if (basis && _platformNames.contains(node.propertyName.name)) {
      _add('basis', node.offset, 'TargetPlatform');
    }
    super.visitDotShorthandPropertyAccess(node);
  }

  static final _platformIs = RegExp(r'^is[A-Z0-9]');

  /// A property read: `x.platform`, `x.physicalSize`, `x.runtimeType`.
  void _propertyRead(AstNode node, String name, int offset) {
    final parent = node.parent;
    final assigned =
        parent is AssignmentExpression && parent.leftHandSide == node;
    if (basis && !assigned) {
      if (name == 'platform') _add('basis', offset, '.platform');
      if (name == 'physicalSize') _add('basis', offset, 'physicalSize');
    }
    if (name == 'runtimeType' && !_counted.contains(node)) {
      _add('child-type', offset, 'runtimeType');
    }
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    final prefix = node.prefix.name;
    final name = node.identifier.name;
    if (basis) {
      if (prefix == 'TargetPlatform') {
        _add('basis', node.offset, 'TargetPlatform');
      }
      if (prefix == 'Platform') {
        if (_platformIs.hasMatch(name)) {
          _add('basis', node.offset, 'Platform.is');
        }
        if (name == 'operatingSystem') {
          _add('basis', node.offset, 'Platform.operatingSystem');
        }
      }
      // `MediaQuery.of(context).size` is a property access; a bare
      // `MediaQuery.size` is not a real API.
    }
    _propertyRead(node, name, node.identifier.offset);
    super.visitPrefixedIdentifier(node);
  }

  bool _isMediaQueryOf(Expression? e) {
    e = e == null ? null : _unparen(e);
    // `MediaQuery.maybeOf(c)!.size`
    if (e is PostfixExpression && e.operator.type == TokenType.BANG) {
      e = _unparen(e.operand);
    }
    return e is MethodInvocation &&
        (e.methodName.name == 'of' || e.methodName.name == 'maybeOf') &&
        _lastName(e.realTarget) == 'MediaQuery';
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final name = node.propertyName.name;
    final target = node.realTarget;
    _propertyRead(node, name, node.propertyName.offset);
    if (basis) {
      if (name == 'size' && _isMediaQueryOf(target)) {
        _add('basis', node.propertyName.offset, 'MediaQuery.size');
      }
      // A prefixed import: `material.TargetPlatform.android`.
      if (_lastName(target) == 'TargetPlatform' &&
          target is! SimpleIdentifier) {
        _add('basis', node.offset, 'TargetPlatform');
      }
      if (_lastName(target) == 'Platform' && target is PrefixedIdentifier) {
        if (_platformIs.hasMatch(name)) {
          _add('basis', node.offset, 'Platform.is');
        }
        if (name == 'operatingSystem') {
          _add('basis', node.offset, 'Platform.operatingSystem');
        }
      }
    }
    super.visitPropertyAccess(node);
  }

  // ------------------------------------------------------------ child-type

  void _checkChildType(TypeAnnotation? type, int offset) {
    if (type is NamedType &&
        widgets.contains(widgetKey(file, type.name.lexeme))) {
      _add('child-type', offset, type.name.lexeme);
    }
  }

  @override
  void visitIsExpression(IsExpression node) {
    _checkChildType(node.type, node.isOperator.offset);
    super.visitIsExpression(node);
  }

  @override
  void visitAsExpression(AsExpression node) {
    _checkChildType(node.type, node.asOperator.offset);
    super.visitAsExpression(node);
  }

  /// Whether [pattern] is part of a switch case or an if-case, not of a
  /// destructuring declaration or assignment.
  static bool _inCase(AstNode pattern) {
    for (AstNode? p = pattern.parent; p != null; p = p.parent) {
      if (p is GuardedPattern || p is CaseClause) return true;
      if (p is PatternVariableDeclaration ||
          p is PatternAssignment ||
          p is ForEachPartsWithPattern ||
          p is Statement ||
          p is Expression ||
          p is ClassMember) {
        return false;
      }
    }
    return false;
  }

  void _checkPatternType(TypeAnnotation? type, AstNode node) {
    if (_inCase(node)) _checkChildType(type, node.offset);
  }

  @override
  void visitObjectPattern(ObjectPattern node) {
    _checkPatternType(node.type, node);
    if (basis) {
      for (final field in node.fields) {
        // `ThemeData(:final platform)` reads platform without a property
        // access in sight.
        if (field.effectiveName == 'platform' ||
            _fieldName(field) == 'platform') {
          _add('basis', field.offset, '.platform');
        }
      }
    }
    super.visitObjectPattern(node);
  }

  /// The property a pattern field reads, from its explicit name or from the
  /// variable it declares (`:final platform`).
  static String? _fieldName(PatternField field) {
    final name = field.name;
    if (name == null) return null;
    final explicit = name.name?.lexeme;
    if (explicit != null) return explicit;
    final pattern = field.pattern;
    return pattern is DeclaredVariablePattern ? pattern.name.lexeme : null;
  }

  @override
  void visitDeclaredVariablePattern(DeclaredVariablePattern node) {
    _checkPatternType(node.type, node);
    super.visitDeclaredVariablePattern(node);
  }

  @override
  void visitWildcardPattern(WildcardPattern node) {
    _checkPatternType(node.type, node);
    super.visitWildcardPattern(node);
  }

  static bool _isRuntimeType(Expression e) {
    e = _unparen(e);
    return switch (e) {
      PrefixedIdentifier() => e.identifier.name == 'runtimeType',
      PropertyAccess() => e.propertyName.name == 'runtimeType',
      _ => false,
    };
  }

  String? _widgetName(Expression e) {
    final name = _lastName(_unparen(e));
    return name != null && widgets.contains(widgetKey(file, name))
        ? name
        : null;
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    final operator = node.operator.type;
    if (operator == TokenType.EQ_EQ || operator == TokenType.BANG_EQ) {
      final left = node.leftOperand, right = node.rightOperand;
      if (_isRuntimeType(left) || _isRuntimeType(right)) {
        // One finding for the comparison, not one per side.
        for (final side in [left, right]) {
          if (_isRuntimeType(side)) _counted.add(_unparen(side));
        }
        final widget = _widgetName(left) ?? _widgetName(right);
        _add('child-type', node.operator.offset, widget ?? 'runtimeType');
      }
    }
    if (operator == TokenType.QUESTION_QUESTION &&
        _readsEnvironment(node.leftOperand)) {
      _add('silent', node.operator.offset, 'maybeOf-fallback');
    }
    super.visitBinaryExpression(node);
  }

  // ---------------------------------------------------------------- silent

  static const _lookups = {
    'maybeOf',
    'getInheritedWidgetOfExactType',
    'dependOnInheritedWidgetOfExactType',
    'findAncestorWidgetOfExactType',
    'findAncestorStateOfType',
    'findRootAncestorStateOfType',
    'findAncestorRenderObjectOfType',
  };
  static const _reports = {'reportError', 'completeError'};

  bool _readsEnvironment(Expression e) {
    final finder = _CallFinder(_lookups);
    e.accept(finder);
    return finder.found;
  }

  @override
  void visitCatchClause(CatchClause node) {
    final finder = _CallFinder(_reports, throws: true);
    node.body.accept(finder);
    if (!finder.found) _add('silent', node.offset, 'catch');
    super.visitCatchClause(node);
  }
}

class _CallFinder extends RecursiveAstVisitor<void> {
  _CallFinder(this.names, {this.throws = false});

  final Set<String> names;
  final bool throws;
  bool found = false;

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (names.contains(node.methodName.name)) found = true;
    super.visitMethodInvocation(node);
  }

  @override
  void visitRethrowExpression(RethrowExpression node) {
    if (throws) found = true;
  }

  @override
  void visitThrowExpression(ThrowExpression node) {
    if (throws) found = true;
    super.visitThrowExpression(node);
  }
}
