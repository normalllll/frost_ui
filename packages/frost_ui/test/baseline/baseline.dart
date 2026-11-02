// Constructor baselines: render a public constructor with fixed arguments in
// each listed environment and fail if it throws or overflows its layout.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import '../support.dart';

/// How the subject is offered input.
enum BaselineInput { pointer, touch }

/// One rendering environment. [width] is the parent's maximum width.
@immutable
class BaselineEnv {
  const BaselineEnv({this.brightness = Brightness.dark, this.textScale = 1, this.input = BaselineInput.pointer, this.width = 720});

  /// Dark, 1×, pointer, width 720: the environment every case runs in unless it
  /// varies a dimension its arguments depend on.
  static const standard = BaselineEnv();

  static const light = BaselineEnv(brightness: Brightness.light);
  static const largeText = BaselineEnv(textScale: 2);
  static const touch = BaselineEnv(input: BaselineInput.touch);
  static const narrow = BaselineEnv(width: 360);

  /// Standard plus light: for arguments whose colors depend on brightness.
  static const themes = [standard, light];

  /// Standard plus every single-dimension variation.
  static const all = [standard, light, largeText, touch, narrow];

  final Brightness brightness;
  final double textScale;
  final BaselineInput input;
  final double width;

  BaselineEnv copyWith({Brightness? brightness, double? textScale, BaselineInput? input, double? width}) =>
      BaselineEnv(brightness: brightness ?? this.brightness, textScale: textScale ?? this.textScale, input: input ?? this.input, width: width ?? this.width);

  String get id {
    final scale = textScale == textScale.roundToDouble() ? textScale.toInt() : textScale;
    return '${brightness.name}-${scale}x-${input.name}-w${width.toInt()}';
  }
}

/// Drives an interaction state (hover, press, focus, open, running, done)
/// after the first frame. [subject] finds the widget under test.
typedef BaselineAct = Future<void> Function(WidgetTester tester, Finder subject);

/// One registered constructor call.
@immutable
class BaselineCase {
  const BaselineCase(this.id, this.builder, {this.envs = const [BaselineEnv.standard], this.act, this.height});

  /// `Constructor/argument summary`, for example `FrostListRow.toggle/subtitle`.
  /// The minimal case uses the summary `required`.
  final String id;
  final WidgetBuilder builder;
  final List<BaselineEnv> envs;
  final BaselineAct? act;

  /// Gives the subject a tight size of `env.width × height` instead of loose
  /// constraints, for page-level components that fill their parent.
  final double? height;

}

const _subjectKey = ValueKey('baseline-subject');

/// Registers one test per case and environment for [widget], the public
/// component the cases belong to.
void baselineGroup(String widget, List<BaselineCase> cases) {
  final ids = <String>{};
  for (final c in cases) {
    if (!ids.add(c.id)) throw StateError('duplicate baseline case ${c.id}');
  }
  group('baseline $widget', () {
    for (final c in cases) {
      for (final env in c.envs) {
        testWidgets('${c.id}@${env.id}', (tester) => _run(tester, widget, c, env));
      }
    }
  });
}

Future<void> _run(WidgetTester tester, String widget, BaselineCase c, BaselineEnv env) async {
  // Disposed before the end-of-test check, which runs ahead of tear-downs.
  final semantics = tester.ensureSemantics();
  try {
    await _render(tester, widget, c, env);
  } finally {
    semantics.dispose();
  }
}

Future<void> _render(WidgetTester tester, String widget, BaselineCase c, BaselineEnv env) async {
  final surface = Size(env.width < 1280 ? 1280 : env.width + 80, c.height == null ? 900 : c.height! + 80);
  tester.view
    ..physicalSize = surface
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final platform = env.input == BaselineInput.touch ? TargetPlatform.android : TargetPlatform.windows;
  Widget subject = KeyedSubtree(
    key: _subjectKey,
    child: Builder(builder: c.builder),
  );
  subject = c.height == null
      ? ConstrainedBox(
          constraints: BoxConstraints(maxWidth: env.width),
          child: subject,
        )
      : SizedBox(width: env.width, height: c.height, child: subject);
  await tester.pumpWidget(
    frostTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(env.textScale)),
          child: Align(
            alignment: Alignment.topLeft,
            child: RepaintBoundary(child: subject),
          ),
        ),
      ),
      brightness: env.brightness,
      platform: platform,
    ),
  );
  await _settle(tester);
  final finder = find.byKey(_subjectKey);
  if (c.act != null) {
    await c.act!(tester, finder);
    await _settle(tester);
  }
  final exception = tester.takeException();
  if (exception != null) throw exception;

}

// Fake time makes a timed-out settle deterministic, so infinite animations
// (spinners, skeleton shimmer) stop at the same frame on every run.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 100), EnginePhase.sendSemanticsUpdate, const Duration(seconds: 3));
  } on FlutterError {
    // Still animating after 3 s.
  }
}

/// A small icon from the shared test icon set, for icon arguments.
const baselineIcon = FrostIconData.glyph(IconData(0xe010));

/// The same [testLabels] the rest of the suite uses.
FrostLabels baselineLabels(BuildContext context) => testLabels(context);

/// Moves a mouse over the subject's center.
Future<void> baselineHover(WidgetTester tester, Finder subject) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(tester.getCenter(subject));
}

/// Holds a press on the subject's center; released at teardown.
Future<void> baselinePress(WidgetTester tester, Finder subject) async {
  final gesture = await tester.startGesture(tester.getCenter(subject));
  addTearDown(gesture.up);
  await tester.pump(const Duration(milliseconds: 200));
}

/// Taps the subject's center, for example to open a menu or panel.
Future<void> baselineTap(WidgetTester tester, Finder subject) => tester.tapAt(tester.getCenter(subject));

/// Moves keyboard focus to the first focusable widget in the subject.
Future<void> baselineFocus(WidgetTester tester, Finder subject) async {
  await tester.sendKeyEvent(LogicalKeyboardKey.tab);
}
