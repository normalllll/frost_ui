// Environment and check functions for the component contract tests.
//
// Every check returns null when the component honours the contract and a short
// description of the violation otherwise. The family test files compare that
// result with the known failures in tool/library_health/allowlist.txt.
import 'dart:async';
import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import '../support.dart' show testConfig, testIcons;

/// Content for the text-scale check: long enough to wrap or ellipsise at twice the size in a 400 px window.
const longLabel = 'A rather long label for large text';

const pageMarker = 'contract-page', baseMarker = 'contract-base', overlayMarker = 'contract-overlay';

/// Counts how often a component reports that it was activated.
class Probe {
  int _calls = 0;

  /// Callbacks received, plus anything copied to the clipboard since the app was mounted.
  int get count => _calls + clipboardWrites;
  void call() => _calls++;
}

int clipboardWrites = 0;

/// True while the intrinsic check runs: a case that gives its component a host
/// size with [hosted] drops it, so the component alone answers.
bool bareMode = false;

/// Hosts [child] at a fixed size, except in the intrinsic check.
Widget hosted({double? width, double? height, required Widget child}) => bareMode ? child : SizedBox(width: width, height: height, child: child);

// ---------------------------------------------------------------------------
// Known failures

/// `contract` rows of tool/library_health/allowlist.txt as `case<TAB>check`.
final Set<String> knownFailures = _readKnownFailures();

Set<String> _readKnownFailures() {
  final file = File('../../tool/library_health/allowlist.txt');
  if (!file.existsSync()) return {};
  return {for (final line in file.readAsLinesSync()) ?_contractKey(line)};
}

String? _contractKey(String line) {
  final fields = line.split('\t');
  return !line.startsWith('#') && fields.length > 3 && fields[0] == 'contract' ? '${fields[1]}\t${fields[3]}' : null;
}

/// Fails unless [problem] matches what allowlist.txt says about this case and check.
void expectContract(String id, String check, String? problem, {Set<String>? listed}) {
  final known = (listed ?? knownFailures).contains('$id\t$check');
  if (problem == null && known) {
    fail('"$id" now passes "$check": delete its contract row from tool/library_health/allowlist.txt.');
  }
  if (problem != null && !known) fail('"$id" violates "$check": $problem');
}

// ---------------------------------------------------------------------------
// Cases

/// A component under test. [build] receives the callback the component must
/// call when it is activated; display cases ignore it.
class Case {
  Case(this.id, this.type, this.build, {this.start, this.end, this.hasContent = true, Finder? subject, Map<String, String> skip = const {}})
    : _subject = subject, // ignore: prefer_initializing_formals
      skip = {...skip};

  /// `Class.new` or `Class.named` for constructor cases.
  final String id;
  final Type type;
  final Widget Function(VoidCallback activate) build;

  /// The leading and trailing child, for the mirror check in RTL.
  final Finder? start, end;

  /// False when an empty widget is legitimate.
  final bool hasContent;

  /// Checks that do not apply, with the reason.
  final Map<String, String> skip;
  final Finder? _subject;

  /// The whole component, or the part of a larger host that the case is about.
  Finder get component => _subject ?? find.byType(type);

  /// What a user taps or focuses; defaults to the component.
  Finder get target => component;
  String get className => id.split('.').first;
}

enum ControlKind {
  /// Enter or Space activates it.
  button,

  /// Enter or Space activates it and it keeps a value.
  toggle,

  /// Focus is its activation; text goes in.
  field,

  /// Focusable and clickable, but not activated by Enter or Space (pickers,
  /// sliders, rows).
  other,
}

class InteractiveCase extends Case {
  InteractiveCase(
    super.id,
    super.type,
    super.build, {
    this.kind = ControlKind.button,
    Finder? target,
    this.opens,
    this.action,
    Finder? focusTarget,
    super.start,
    super.end,
    super.hasContent,
    super.subject,
    super.skip,
  }) : _target = target, // ignore: prefer_initializing_formals
       _focusTarget = focusTarget; // ignore: prefer_initializing_formals

  final ControlKind kind;
  final Finder? _target, _focusTarget;

  /// What appears when the control opens a menu or panel instead of calling back.
  final Finder? opens;

  /// The semantics action it advertises; tap, or focus for a field.
  final SemanticsAction? action;

  @override
  Finder get target => _target ?? component;

  /// What holds focus after Tab, when that is not the tapped part.
  Finder get focusTarget => _focusTarget ?? target;

  SemanticsAction get semanticsAction => action ?? (kind == ControlKind.field ? SemanticsAction.focus : SemanticsAction.tap);
}

class DisplayCase extends Case {
  DisplayCase(super.id, super.type, super.build, {super.hasContent, super.start, super.end, super.subject, super.skip});
}

// ---------------------------------------------------------------------------
// Environment

class _Router extends RouterDelegate<Object> with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  _Router(this.pages);
  final List<Page<void>> pages;
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  Future<void> setNewRoutePath(Object configuration) async {}
  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: List.of(pages),
    onDidRemovePage: (page) {
      pages.remove(page);
      notifyListeners();
    },
  );
}

/// Mounts [content] in a Frost app with the given environment. [under] pages
/// are added below the page that holds [content].
Future<void> pumpEnv(
  WidgetTester tester,
  Widget content, {
  TargetPlatform platform = TargetPlatform.windows,
  Size size = const Size(1200, 800),
  double textScale = 1,
  TextDirection direction = TextDirection.ltr,
  bool reducedMotion = false,
  bool? enabled,
  bool underPage = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(disableAnimations: reducedMotion);
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  debugDefaultTargetPlatformOverride = platform;
  clipboardWrites = 0;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'Clipboard.setData') clipboardWrites++;
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  Widget page = Center(child: content);
  if (enabled != null) page = FrostControlScope(enabled: enabled, child: page);
  final router = _Router([
    if (underPage)
      const MaterialPage<void>(
        key: ValueKey('base'),
        child: Scaffold(body: Center(child: Text(baseMarker))),
      ),
    MaterialPage<void>(
      key: const ValueKey('page'),
      child: Scaffold(body: page),
    ),
  ]);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    FrostApp.router(
      config: testConfig,
      title: 'contract',
      routerConfig: RouterConfig<Object>(routerDelegate: router, backButtonDispatcher: RootBackButtonDispatcher()),
      builder: (context, child) => Directionality(textDirection: direction, child: child!),
    ),
  );
  await tester.pump();
}

/// Mounts [content] with a bare [WidgetsApp]: no Frost theme, scope or config.
Future<void> pumpBare(WidgetTester tester, Widget content) async {
  debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF000000),
      localizationsDelegates: const [DefaultWidgetsLocalizations.delegate, DefaultMaterialLocalizations.delegate],
      pageRouteBuilder: <T>(settings, builder) => PageRouteBuilder<T>(settings: settings, pageBuilder: (context, _, _) => builder(context)),
      home: Material(child: Center(child: content)),
    ),
  );
  await tester.pump();
}

/// Runs [body] while collecting every framework error. Errors count as a
/// failure unless [errorsAreFailures] is false.
Future<String?> guarded(WidgetTester tester, Future<String?> Function(List<String> errors) body, {bool errorsAreFailures = true}) async {
  final errors = <String>[];
  final previous = FlutterError.onError;
  FlutterError.onError = (details) => errors.add(_firstLine(details.exceptionAsString()));
  String? problem;
  try {
    // Errors thrown from a timer or microtask would otherwise end the test.
    problem = await runZonedGuarded<Future<String?>>(() => body(errors), (error, stack) => errors.add(_firstLine(error.toString())));
  } catch (error) {
    problem = 'the check could not run: ${_firstLine(error.toString())}';
  } finally {
    final pending = tester.takeException();
    if (pending != null) errors.add(_firstLine(pending.toString()));
    FlutterError.onError = previous;
    debugDefaultTargetPlatformOverride = null;
  }
  if (problem == null && errorsAreFailures && errors.isNotEmpty) problem = 'framework error: ${errors.first}';
  return problem;
}

String _firstLine(String text) => text.trim().split('\n').first;

/// Lets route transitions and short animations finish without waiting for
/// endless ones.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
  // A success or busy state may lock a button for a few seconds.
  await tester.pump(const Duration(seconds: 3));
}

bool _focusWithin(Finder target) {
  final context = FocusManager.instance.primaryFocus?.context;
  final targets = target.evaluate().toSet();
  if (context == null || targets.isEmpty) return false;
  if (targets.contains(context)) return true;
  var inside = false;
  context.visitAncestorElements((element) {
    inside = targets.contains(element);
    return !inside;
  });
  return inside;
}

/// Presses Tab until [target] holds focus, at most [limit] times.
Future<bool> _tabTo(WidgetTester tester, Finder target, {int limit = 4}) async {
  for (var i = 0; i < limit; i++) {
    if (_focusWithin(target)) return true;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
  }
  return _focusWithin(target);
}

Future<void> _dismissOverlays(WidgetTester tester) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await tester.pump();
  await tester.binding.handlePopRoute();
  await settle(tester);
}

Future<bool> _activated(WidgetTester tester, InteractiveCase c, Probe probe, int before) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
  if (probe.count > before) return true;
  if (c.opens != null && c.opens!.evaluate().isNotEmpty) return true;
  return c.kind == ControlKind.field && _focusWithin(c.focusTarget);
}

// ---------------------------------------------------------------------------
// Semantics

/// The semantics nodes a component owns, with the data each carries once its
/// merged descendants are folded in.
List<SemanticsData> semanticsOf(WidgetTester tester, Finder target) {
  final element = target.evaluate().first;
  final nodes = <SemanticsNode>{};
  void visit(RenderObject object) {
    final node = object.debugSemantics;
    if (node != null) {
      var owner = node;
      while (owner.isMergedIntoParent && owner.parent != null) {
        owner = owner.parent!;
      }
      nodes.add(owner);
    }
    object.visitChildren(visit);
  }

  visit(element.renderObject!);
  if (nodes.isEmpty) nodes.add(tester.semantics.find(target.first));
  return [for (final node in nodes) node.getSemanticsData()];
}

String _describeFlags(SemanticsData data) => 'enabled=${data.flagsCollection.isEnabled.name} label="${data.label}"';

// ---------------------------------------------------------------------------
// Interactive checks

/// The actions a disabled control must not offer.
const _userActions = [
  SemanticsAction.tap,
  SemanticsAction.longPress,
  SemanticsAction.focus,
  SemanticsAction.increase,
  SemanticsAction.decrease,
  SemanticsAction.setText,
];

const _scopeKeys = [LogicalKeyboardKey.enter, LogicalKeyboardKey.space];

Future<String?> checkDisabledScope(WidgetTester tester, InteractiveCase c) => guarded(tester, (errors) async {
  final probe = Probe();
  await pumpEnv(tester, c.build(probe.call), enabled: false);
  await tester.tap(c.target.first, warnIfMissed: false);
  await tester.pump();
  if (tester.testTextInput.hasAnyClients) tester.testTextInput.enterText('x');
  for (var i = 0; i < 4; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    for (final key in _scopeKeys) {
      await tester.sendKeyEvent(key);
    }
  }
  await settle(tester);
  if (probe.count > 0) return 'a control inside FrostControlScope(enabled: false) was activated ${probe.count} time(s) by tap, Enter or Space';
  if (c.opens != null && c.opens!.evaluate().isNotEmpty) return 'a control inside FrostControlScope(enabled: false) opened its panel';
  if (c.kind == ControlKind.field && _focusWithin(c.focusTarget)) return 'a field inside FrostControlScope(enabled: false) took focus';
  return null;
});

Future<String?> checkDisabledSemantics(WidgetTester tester, InteractiveCase c) => guarded(tester, (errors) async {
  final handle = tester.ensureSemantics();
  try {
    await pumpEnv(tester, c.build(() {}), enabled: false);
    final all = semanticsOf(tester, c.component);
    if (!all.any((d) => d.flagsCollection.isEnabled == Tristate.isFalse)) {
      return 'no semantics node is marked disabled inside FrostControlScope(enabled: false) (${all.map(_describeFlags).join('; ')})';
    }
    final leaking = <String>[];
    for (final d in all) {
      final names = [
        for (final action in _userActions)
          if (d.hasAction(action)) action.name,
      ];
      if (names.isEmpty) continue;
      final state = d.flagsCollection.isEnabled == Tristate.isFalse ? 'disabled' : 'not marked disabled';
      leaking.add('${names.join(', ')} on a node that is $state');
    }
    if (leaking.isNotEmpty) return 'a disabled control still advertises actions: ${leaking.join('; ')}';
    return null;
  } finally {
    handle.dispose();
  }
});

Future<String?> checkSemantics(WidgetTester tester, InteractiveCase c) => guarded(tester, (errors) async {
  final handle = tester.ensureSemantics();
  try {
    await pumpEnv(tester, c.build(() {}));
    final all = semanticsOf(tester, c.component);
    final actionable = all.where((d) => d.hasAction(c.semanticsAction)).toList();
    if (actionable.isEmpty) return 'no semantics node has a ${c.semanticsAction.name} action (${all.map(_describeFlags).join('; ')})';
    if (!actionable.any((d) => d.label.trim().isNotEmpty)) return 'the node with the ${c.semanticsAction.name} action has an empty label';
    return null;
  } finally {
    handle.dispose();
  }
});

Future<String?> checkKeyboard(WidgetTester tester, InteractiveCase c) => guarded(tester, (errors) async {
  final probe = Probe();
  await pumpEnv(tester, c.build(probe.call));
  if (!await _tabTo(tester, c.focusTarget)) return 'Tab does not move focus into the control';
  if (c.kind != ControlKind.button && c.kind != ControlKind.toggle) return null;
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
  if (probe.count == 0) {
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
  }
  if (probe.count == 0 && !(c.opens?.evaluate().isNotEmpty ?? false)) return 'neither Enter nor Space activates the focused control';
  return null;
});

Future<String?> checkTouchTarget(WidgetTester tester, InteractiveCase c) => guarded(tester, (errors) async {
  final probe = Probe();
  await pumpEnv(tester, c.build(probe.call), platform: TargetPlatform.android);
  final center = tester.getCenter(c.target.first);
  final size = tester.getSize(c.target.first);
  final missed = <Offset>[];
  for (final offset in const [Offset(-21, -21), Offset(21, -21), Offset(-21, 21), Offset(21, 21)]) {
    FocusManager.instance.primaryFocus?.unfocus();
    final before = probe.count;
    await tester.tapAt(center + offset);
    if (!await _activated(tester, c, probe, before)) missed.add(offset);
    await _dismissOverlays(tester);
  }
  if (missed.isEmpty) return null;
  return 'taps ${missed.length} of 4 corners of the 44x44 box did not activate it (offsets from the centre: ${missed.join(', ')}; control is ${size.width.round()}x${size.height.round()})';
});

// ---------------------------------------------------------------------------
// Checks for every case

Future<String?> checkTextScale(WidgetTester tester, Case c) => guarded(tester, (errors) async {
  const window = Size(400, 800);
  await pumpEnv(tester, c.build(() {}), size: window, textScale: 2);
  await tester.pump(const Duration(milliseconds: 100));
  if (errors.isNotEmpty) return null;
  final outside = textOutsideWindow(tester, window);
  if (outside.isEmpty) return null;
  return 'text lies outside the ${window.width.round()}x${window.height.round()} window outside any scroll view: ${outside.take(3).join(', ')}';
});

/// Visible text that sticks out of [window] and is not inside a scrollable.
List<String> textOutsideWindow(WidgetTester tester, Size window) {
  final outside = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    final box = element.renderObject;
    if (box is! RenderParagraph || !box.hasSize || box.size.isEmpty) continue;
    // A scroll view the user cannot scroll (ignoring pointers, or never-scrollable physics) hides text instead.
    var scrolls = false, ignored = false;
    element.visitAncestorElements((ancestor) {
      final widget = ancestor.widget;
      if (widget is IgnorePointer && widget.ignoring) ignored = true;
      if (widget is Scrollable) {
        scrolls = !ignored && widget.physics is! NeverScrollableScrollPhysics;
        ignored = false;
      }
      return !scrolls;
    });
    if (scrolls) continue;
    final rect = box.localToGlobal(Offset.zero) & box.size;
    if (rect.left < -.5 || rect.top < -.5 || rect.right > window.width + .5 || rect.bottom > window.height + .5) {
      outside.add('"${box.text.toPlainText().trim()}" at x=${rect.left.round()}..${rect.right.round()}');
    }
  }
  return outside;
}

Future<String?> checkRtl(WidgetTester tester, Case c) => guarded(tester, (errors) async {
  Future<(double, double)?> measure(TextDirection direction) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpEnv(tester, c.build(() {}), direction: direction);
    await tester.pump(const Duration(milliseconds: 100));
    if (c.start == null || c.end == null) return null;
    final centre = tester.getCenter(c.component.first).dx;
    return (tester.getCenter(c.start!.first).dx - centre, tester.getCenter(c.end!.first).dx - centre);
  }

  final ltr = await measure(TextDirection.ltr);
  final rtl = await measure(TextDirection.rtl);
  if (ltr == null || rtl == null) return null;
  if (ltr.$1 >= ltr.$2) return 'the start child is not left of the end child in LTR, so the case cannot test mirroring';
  if ((ltr.$1 + rtl.$1).abs() > 1 || (ltr.$2 + rtl.$2).abs() > 1) {
    return 'children do not mirror about the centre: start ${ltr.$1.toStringAsFixed(1)} -> ${rtl.$1.toStringAsFixed(1)}, '
        'end ${ltr.$2.toStringAsFixed(1)} -> ${rtl.$2.toStringAsFixed(1)}';
  }
  return null;
});

Future<String?> checkNoTheme(WidgetTester tester, Case c) => guarded(tester, (errors) async {
  await pumpBare(tester, c.build(() {}));
  await tester.pump(const Duration(milliseconds: 100));
  if (errors.isNotEmpty || tester.takeException() != null) return null;
  return 'rendered silently without a Frost theme, scope or configuration';
}, errorsAreFailures: false);

// ---------------------------------------------------------------------------
// Display checks

Future<String?> checkIntrinsic(WidgetTester tester, Case c) => guarded(tester, (errors) async {
  const natural = ValueKey('contract-natural'), intrinsic = ValueKey('contract-intrinsic');
  bareMode = true;
  try {
    await pumpEnv(tester, ConstrainedBox(key: natural, constraints: const BoxConstraints(), child: c.build(() {})));
    await tester.pump(const Duration(milliseconds: 100));
    errors.clear();
    final loose = tester.getSize(find.byKey(natural));
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpEnv(
      tester,
      IntrinsicWidth(
        key: intrinsic,
        child: IntrinsicHeight(child: c.build(() {})),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    if (errors.isNotEmpty) return null;
    final size = tester.getSize(find.byKey(intrinsic));
    if (!c.hasContent) return null;
    if (size.width <= 0 || size.height <= 0) return 'measured ${size.width}x${size.height} inside IntrinsicWidth and IntrinsicHeight';
    // Only an axis where the content shrink-wraps under loose constraints has a natural size.
    final window = tester.view.physicalSize / tester.view.devicePixelRatio;
    final tooNarrow = loose.width < window.width - 1 && size.width < loose.width - .5;
    final tooShort = loose.height < window.height - 1 && size.height < loose.height - .5;
    if (tooNarrow || tooShort) {
      return 'measured ${size.width.round()}x${size.height.round()} inside IntrinsicWidth and IntrinsicHeight, below its natural ${loose.width.round()}x${loose.height.round()}';
    }
    return null;
  } finally {
    bareMode = false;
  }
});

// ---------------------------------------------------------------------------
// Reduced motion

Future<String?> checkReducedMotion(WidgetTester tester, InteractiveCase c) => guarded(tester, (errors) async {
  final probe = Probe();
  await pumpEnv(tester, c.build(probe.call), reducedMotion: true);
  await tester.tap(c.target.first, warnIfMissed: false);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  // An idle overlay can keep a passive callback registered; a running animation always has a frame scheduled.
  final running = tester.binding.transientCallbackCount;
  if (running > 0 && tester.binding.hasScheduledFrame) return '$running animation(s) still running 150 ms after activation with disableAnimations';
  if (tester.binding.hasScheduledFrame) return 'a frame is still scheduled 150 ms after activation with disableAnimations';
  return null;
});

// ---------------------------------------------------------------------------
// Hiding

/// A component that can hide its child. [create] is called once per test.
class HidingCase {
  HidingCase(this.id, this.create, {Map<String, String> skip = const {}}) : skip = {...skip};
  final String id;
  final HidingSubject Function() create;
  final Map<String, String> skip;
}

abstract class HidingSubject {
  /// The component showing [child], or hiding it when [hidden].
  Widget build(Widget child, bool hidden);
  void dispose() {}
}

class SimpleHiding extends HidingSubject {
  SimpleHiding(this._build);
  final Widget Function(Widget child, bool hidden) _build;
  @override
  Widget build(Widget child, bool hidden) => _build(child, hidden);
}

class _Hidden {
  final probe = Probe();
  final hidden = ValueNotifier(false);
  BuildContext? context;
  late final buttonKey = GlobalKey();

  Widget get child => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      FrostButton(key: buttonKey, label: 'Hidden button', onPressed: probe.call),
      Builder(
        builder: (context) {
          this.context = context;
          return const SizedBox(width: 10, height: 10);
        },
      ),
    ],
  );

  Finder get button => find.byKey(buttonKey, skipOffstage: false);
}

Future<(_Hidden, HidingSubject)> _pumpHiding(WidgetTester tester, HidingCase c) async {
  final state = _Hidden(), subject = c.create();
  addTearDown(subject.dispose);
  addTearDown(state.hidden.dispose);
  await pumpEnv(tester, ValueListenableBuilder<bool>(valueListenable: state.hidden, builder: (context, hidden, _) => subject.build(state.child, hidden)));
  await tester.pump(const Duration(milliseconds: 500));
  return (state, subject);
}

Future<String?> checkHiddenFocus(WidgetTester tester, HidingCase c) => guarded(tester, (errors) async {
  final (state, _) = await _pumpHiding(tester, c);
  if (state.button.evaluate().isEmpty) return 'the child is not shown before it is hidden, so the case cannot test hiding';
  state.hidden.value = true;
  await settle(tester);
  for (var i = 0; i < 5; i++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (_focusWithin(state.button)) return 'Tab focused a button inside the hidden subtree';
  }
  return null;
});

Future<String?> checkHiddenTap(WidgetTester tester, HidingCase c) => guarded(tester, (errors) async {
  final (state, _) = await _pumpHiding(tester, c);
  if (state.button.evaluate().isEmpty) return 'the child is not shown before it is hidden, so the case cannot test hiding';
  final where = tester.getCenter(state.button);
  state.hidden.value = true;
  await settle(tester);
  await tester.tapAt(where);
  await tester.pump();
  if (state.probe.count > 0) return 'tapping where a hidden button was triggered it';
  return null;
});

Future<String?> checkHiddenTicker(WidgetTester tester, HidingCase c) => guarded(tester, (errors) async {
  final (state, _) = await _pumpHiding(tester, c);
  if (state.context == null) return 'the child is not built before it is hidden, so the case cannot test hiding';
  state.hidden.value = true;
  await settle(tester);
  final context = state.context!;
  if (!context.mounted) return null;
  if (TickerMode.valuesOf(context).enabled) return 'TickerMode.of is still true inside the hidden subtree';
  return null;
});

// ---------------------------------------------------------------------------
// Overlays

class OverlayOptions {
  const OverlayOptions({required this.canPop, this.barrierDismissible = true});
  final bool canPop;
  final bool barrierDismissible;

  /// Overlay content that carries the PopScope the case should expose.
  Widget content({double width = 240, double height = 120}) => PopScope(
    canPop: canPop,
    child: SizedBox(width: width, height: height, child: const Text(overlayMarker)),
  );
}

class OverlayCase {
  OverlayCase(
    this.id, {
    this.open,
    this.anchor,
    this.opener,
    this.closeButton,
    this.dragTarget,
    this.dragBy = const Offset(0, 500),
    this.platform = TargetPlatform.windows,
    this.size = const Size(1200, 800),
    Map<String, String> skip = const {},
  }) : skip = {...skip},
       assert(open != null || anchor != null && opener != null);
  final String id;

  /// Opens the overlay from the page's context.
  final Future<Object?> Function(BuildContext context, OverlayOptions options)? open;

  /// Alternatively a widget on the page and what to tap to open it.
  final Widget Function(OverlayOptions options)? anchor;
  final Finder? opener;

  /// The overlay's own close button, if it has one.
  final Finder? closeButton;

  /// What to drag to dismiss, if the overlay can be dragged away.
  final Finder? dragTarget;
  final Offset dragBy;
  final TargetPlatform platform;
  final Size size;
  final Map<String, String> skip;
}

Future<String?> _withOverlay(
  WidgetTester tester,
  OverlayCase c,
  OverlayOptions options,
  Future<String?> Function(List<String> errors) body, {
  bool underPage = true,
  bool shell = false,
}) => guarded(tester, (errors) async {
  BuildContext? context;
  shellBacks = 0;
  final page = Builder(
    builder: (ctx) {
      context = ctx;
      return Column(mainAxisSize: MainAxisSize.min, children: [const Text(pageMarker), ?c.anchor?.call(options)]);
    },
  );
  await pumpEnv(tester, shell ? _shellAround(page) : page, platform: c.platform, size: c.size, underPage: underPage);
  if (c.open != null) {
    unawaited(Future.sync(() => c.open!(context!, options)).then<void>((_) {}, onError: (Object error) => errors.add('opening failed: $error')));
  } else {
    await tester.tap(c.opener!);
  }
  await settle(tester);
  if (find.text(overlayMarker).evaluate().isEmpty) return 'the overlay did not open (or does not show the PopScope content)';
  return body(errors);
});

/// How often the shell was asked to go back.
int shellBacks = 0;

/// [page] as a routed page inside a shell, as an app has it.
Widget _shellAround(Widget page) => FrostShell(
  destinations: [FrostNavDestination(icon: testIcons.add, label: 'Home')],
  selectedIndex: 0,
  atDestinationRoot: false,
  onDestinationSelected: (_) {},
  canGoBack: true,
  onBack: () => shellBacks++,
  showsMobileNavigation: false,
  child: Navigator(
    onDidRemovePage: (_) {},
    pages: [MaterialPage<void>(child: page)],
  ),
);

bool _open() => find.text(overlayMarker).evaluate().isNotEmpty;

Future<String?> checkPopScopeEsc(WidgetTester tester, OverlayCase c) => _withOverlay(tester, c, const OverlayOptions(canPop: false), (errors) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.escape);
  await settle(tester);
  return _open() ? null : 'Escape closed an overlay whose PopScope has canPop: false';
});

Future<String?> checkPopScopeClose(WidgetTester tester, OverlayCase c) => _withOverlay(tester, c, const OverlayOptions(canPop: false), (errors) async {
  if (c.closeButton == null || c.closeButton!.evaluate().isEmpty) return 'the case has no close button, so it should be skipped';
  await tester.tap(c.closeButton!.first);
  await settle(tester);
  return _open() ? null : 'the close button closed an overlay whose PopScope has canPop: false';
});

Future<String?> checkPopScopeDrag(WidgetTester tester, OverlayCase c) => _withOverlay(tester, c, const OverlayOptions(canPop: false), (errors) async {
  final target = c.dragTarget!;
  final before = tester.getTopLeft(target.first);
  await tester.fling(target.first, c.dragBy, 1500);
  await settle(tester);
  if (!_open()) return 'dragging closed an overlay whose PopScope has canPop: false';
  final after = tester.getTopLeft(target.first);
  if ((after - before).distance > 1) return 'the overlay did not spring back: it moved from $before to $after';
  return null;
});

Future<String?> checkPopScopeBack(WidgetTester tester, OverlayCase c) => _withOverlay(tester, c, const OverlayOptions(canPop: false), (errors) async {
  await tester.binding.handlePopRoute();
  await settle(tester);
  return _open() ? null : 'system back closed an overlay whose PopScope has canPop: false';
});

Future<String?> checkBarrier(WidgetTester tester, OverlayCase c) =>
    _withOverlay(tester, c, const OverlayOptions(canPop: true, barrierDismissible: false), (errors) async {
      await tester.tapAt(const Offset(4, 4));
      await settle(tester);
      if (!_open()) return 'tapping the barrier closed an overlay with barrierDismissible: false';
      await tester.dragFrom(const Offset(4, 4), c.dragBy);
      await settle(tester);
      if (!_open()) return 'dragging from the barrier closed an overlay with barrierDismissible: false';
      if (c.dragTarget != null) {
        await tester.fling(c.dragTarget!.first, c.dragBy, 1500);
        await settle(tester);
        if (!_open()) return 'dragging the overlay closed it with barrierDismissible: false';
      }
      return null;
    });

Future<String?> checkBackOnlyOverlay(WidgetTester tester, OverlayCase c) => _withOverlay(tester, c, const OverlayOptions(canPop: true), (errors) async {
  await tester.binding.handlePopRoute();
  await settle(tester);
  if (_open()) return 'system back did not close the overlay';
  if (find.text(pageMarker).evaluate().isEmpty) return 'system back also closed the page under the overlay';
  return null;
});

Future<String?> checkEscOnlyOverlay(WidgetTester tester, OverlayCase c) =>
    _withOverlay(tester, c, const OverlayOptions(canPop: true), shell: true, (errors) async {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await settle(tester);
      if (_open()) return 'Escape did not close the overlay';
      if (shellBacks > 0) return 'Escape also asked the shell to go back ($shellBacks time(s))';
      if (find.text(pageMarker).evaluate().isEmpty) return 'Escape also closed the page under the overlay';
      return null;
    });

// ---------------------------------------------------------------------------
// Search dropdown host

/// [content] as the dropdown of a focused [FrostSearchInput.suggesting] that
/// already holds text, for components that only work inside a search dropdown.
Widget searchDropdown(Widget content) => _SearchDropdown(content);

class _SearchDropdown extends StatefulWidget {
  const _SearchDropdown(this.content);
  final Widget content;

  @override
  State<_SearchDropdown> createState() => _SearchDropdownState();
}

class _SearchDropdownState extends State<_SearchDropdown> {
  final _controller = TextEditingController(text: 'ab');
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_reopen);
    HardwareKeyboard.instance.addHandler(_escape);
    _reopen();
  }

  /// The checks click away and press Escape; the dropdown comes back with the
  /// focus so the next click has something to hit.
  bool _escape(KeyEvent event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
      // Escape hides the dropdown while the field keeps focus; losing and regaining focus shows it again.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.unfocus();
      });
      WidgetsBinding.instance.scheduleFrame();
    }
    return false;
  }

  void _reopen() {
    if (_focus.hasFocus) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_focus.hasFocus) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.removeListener(_reopen);
    HardwareKeyboard.instance.removeHandler(_escape);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // A disabled scope would keep the field from opening its dropdown, so the
    // field is enabled and the scope the case runs in is applied to the content.
    final enabled = FrostControlScope.enabledOf(context);
    // The dropdown fades in; without motion it is fully shown on the frame it opens, which the checks need.
    final media = MediaQuery.of(context).copyWith(disableAnimations: true);
    return MediaQuery(
      data: media,
      child: FrostControlScope(
        enabled: true,
        child: SizedBox(
          width: 360,
          child: FrostSearchInput.suggesting(
            controller: _controller,
            focusNode: _focus,
            autofocus: true,
            placeholder: 'Search',
            onSubmitted: (_) {},
            placement: FrostSuggestionPlacement.overlay,
            content: FrostControlScope(enabled: enabled, child: widget.content),
          ),
        ),
      ),
    );
  }
}
