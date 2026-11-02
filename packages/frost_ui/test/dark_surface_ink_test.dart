import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_field_chrome.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'package:frost_ui/src/controls/_field_options.dart';
import 'package:frost_ui/src/controls/_field_trigger.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:frost_ui/src/overlays/_menu_item.dart';

import 'support.dart';

void main() {
  test('cool and warm dark surfaces follow neutral OKLCH lightness', () {
    final neutral = FrostPalettes.pink.darkNeutral;
    for (final t in [FrostPalettes.pink.darkCool, FrostPalettes.pink.darkWarm]) {
      final actual = [t.canvas, t.surface, t.surfaceRaised, t.surfaceInset, t.surfaceMuted, t.surfaceTint, t.hoverSurface, t.pressedSurface];
      final expected = [
        neutral.canvas,
        neutral.surface,
        neutral.surfaceRaised,
        neutral.surfaceInset,
        neutral.surfaceMuted,
        neutral.surfaceTint,
        neutral.hoverSurface,
        neutral.pressedSurface,
      ];
      for (var i = 0; i < actual.length; i++) {
        expect(_oklab(actual[i]).$1, closeTo(_oklab(expected[i]).$1, .005));
      }
    }
  });
  test('tertiary ink grows across all six palettes and surfaces without changing disabled ink', () {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final t = FrostPalettes.pink.palette(brightness, tone, FrostPalettes.pink.defaultAccent(brightness));
        expect(t.textTertiary.a, 1);
        expect(t.textQuaternary, t.textTertiary);
        expect(t.disabledText.a, closeTo(.25, 1 / 255));
        for (final surface in [t.canvas, t.surface, t.surfaceRaised, t.surfaceInset, t.surfaceMuted, t.surfaceTint]) {
          final contrast = colorContrast(Color.alphaBlend(t.textTertiary, surface), surface);
          final oldContrast = colorContrast(Color.alphaBlend(t.textPrimary.withValues(alpha: .35), surface), surface);
          expect(contrast, greaterThan(oldContrast), reason: '$brightness $tone $surface');
        }
        expect(t.textTertiaryGlass.a, greaterThanOrEqualTo(t.isDark ? .44 : .47));
        expect(colorContrast(Color.alphaBlend(t.textTertiaryGlass, t.surfaceRaised), t.surfaceRaised), greaterThanOrEqualTo(4.5));
      }
    }
  });
  testWidgets('search announcements preserve inherited field validation', (tester) async {
    final text = TextEditingController(text: 'Search');
    final focus = FocusNode();
    addTearDown(text.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostFieldOptions(
          invalid: true,
          child: Center(
            child: SizedBox(
              width: 240,
              child: FrostSearchInput(controller: text, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
            ),
          ),
        ),
      ),
    );
    final frame = find.byType(FrostFieldFrame);
    expect(tester.widget<FrostFieldFrame>(frame).invalid, isTrue);
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.widget<FrostFieldFrame>(frame).invalid, isTrue);
    expect(tester.widget<FrostFieldFrame>(frame).focused, isTrue);
    expect(find.descendant(of: frame, matching: frostFocusRings()), findsNothing);
  });
  testWidgets('selection trigger inherits invalid state and keeps the same edge while focused', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 240,
            child: FrostFieldOptions(
              invalid: true,
              child: FrostFieldTrigger(label: 'Choice', value: 'Current', focus: focus, onPressed: () {}),
            ),
          ),
        ),
      ),
    );
    final trigger = find.byType(FrostFieldTrigger);
    final tokens = FrostThemeTokens.of(tester.element(trigger));
    BorderSide edge() =>
        (tester
                    .renderObjectList<RenderDecoratedBox>(find.descendant(of: trigger, matching: find.byType(DecoratedBox)))
                    .map((box) => box.decoration)
                    .whereType<ShapeDecoration>()
                    .firstWhere((paint) => (paint.shape as OutlinedBorder).side.style == BorderStyle.solid)
                    .shape
                as OutlinedBorder)
            .side;
    final rest = edge();
    expect(rest.color, tokens.negativeInk);
    focus.requestFocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pumpAndSettle();
    expect(edge(), rest);
    expect(find.descendant(of: trigger, matching: frostFocusRings()), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('switch pointer focus has no ring; keyboard focus uses the shared ring', (tester) async {
    final previous = FocusManager.instance.highlightStrategy;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = previous);
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: FrostSwitch(value: false, onChanged: (_) {}, semanticLabel: 'Toggle'),
        ),
      ),
    );
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.down(tester.getCenter(find.byType(FrostSwitch)));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(frostFocusRings(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(frostFocusRings(), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(frostFocusRings(), findsOneWidget);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('standalone list keyboard focus and mouse hover share full-row fill without a ring', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 240,
            child: FrostListRow(title: 'Row', onPressed: () {}),
          ),
        ),
      ),
    );
    final row = find.byType(FrostListRow);
    final tokens = FrostThemeTokens.of(tester.element(row));
    Focus.of(tester.element(find.text('Row'))).requestFocus();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    final colors = tester
        .renderObjectList<RenderDecoratedBox>(find.descendant(of: row, matching: find.byType(DecoratedBox)))
        .map((box) => box.decoration)
        .whereType<ShapeDecoration>()
        .map((paint) => paint.color);
    expect(colors, contains(tokens.textPrimary.withValues(alpha: .04)));
    expect(find.descendant(of: row, matching: frostFocusRings()), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final brightness in Brightness.values) {
    for (final tone in FrostTone.values) {
      for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
        for (final dpr in [1.0, 2.0, 3.0]) {
          testWidgets('field edge is one physical pixel at rest and two or more when focused or invalid $brightness $tone $platform dpr=$dpr', (tester) async {
            late BuildContext context;
            final dark = brightness == Brightness.dark;
            // Use a DPR scope directly, keeping test viewport dimensions intact.
            await tester.pumpWidget(
              FrostScope(
                config: testConfig,
                child: MaterialApp(
                  theme: FrostTheme.build(config: testConfig, brightness: brightness, platform: platform, tone: tone, locale: const Locale('en')),
                  home: MediaQuery(
                    data: MediaQueryData(devicePixelRatio: dpr),
                    child: Builder(
                      builder: (value) {
                        context = value;
                        return const SizedBox();
                      },
                    ),
                  ),
                ),
              ),
            );
            final tokens = FrostThemeTokens.of(context);
            FrostFieldChrome chrome({bool enabled = true, bool focused = false, bool invalid = false, bool hovered = false}) =>
                FrostFieldChrome.resolve(context, enabled: enabled, focused: focused, invalid: invalid, hovered: hovered);
            Color edge(FrostFieldChrome value) => (value.edge.shape as OutlinedBorder).side.color;
            final rest = chrome(),
                active = chrome(focused: true),
                hover = chrome(hovered: true),
                error = chrome(invalid: true),
                disabled = chrome(enabled: false);
            final accentWidth = (dpr.round() < 2 ? 2 : dpr.round()) / dpr;
            for (final (value, accent) in [
              (rest, false),
              (active, true),
              (hover, false),
              (error, true),
              (disabled, false),
              (chrome(focused: true, invalid: true), true),
            ]) {
              final side = (value.edge.shape as OutlinedBorder).side;
              expect(side.width, accent ? closeTo(accentWidth, 1e-9) : closeTo(1 / dpr, 1e-9));
              expect(side.strokeAlign, BorderSide.strokeAlignInside);
              final radius = (value.shape as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x;
              expect(radius, platform == TargetPlatform.windows ? 8 : 10);
            }
            expect(edge(rest), tokens.textPrimary.withValues(alpha: dark ? .11 : .13));
            expect(edge(active), tokens.textPrimary.withValues(alpha: dark ? .34 : .40));
            expect(edge(hover), tokens.textPrimary.withValues(alpha: platform == TargetPlatform.android ? (dark ? .11 : .13) : (dark ? .22 : .26)));
            expect(edge(error), tokens.negativeInk);
            expect(edge(chrome(focused: true, invalid: true)), tokens.negativeInk);
            expect(edge(chrome(enabled: false, focused: true, invalid: true, hovered: true)), edge(disabled));
            expect(active.fill.computeLuminance(), greaterThan(rest.fill.computeLuminance()));
            expect(disabled.fill, Color.alphaBlend(tokens.fill.withValues(alpha: (dark ? .05 : .035) * .38), tokens.surface));
          });
        }
      }
    }
  }

  for (final brightness in Brightness.values) {
    testWidgets('mouse and Tab editing share neutral chrome and accent caret $brightness', (tester) async {
      final previous = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = previous);
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 300,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FrostButton(label: 'Before', onPressed: () {}),
                  FrostTextField(focusNode: focus, placeholder: 'Edit'),
                ],
              ),
            ),
          ),
          brightness: brightness,
        ),
      );
      final frame = find.byType(FrostFieldFrame);
      ShapeDecoration edge() {
        final paint = tester.widget<FrostFieldPaint>(find.descendant(of: frame, matching: find.byType(FrostFieldPaint)).first);
        return ShapeDecoration(shape: paint.shape.copyWith(side: paint.side));
      }

      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(frame));
      await tester.pumpAndSettle();
      final tokens = FrostThemeTokens.of(tester.element(frame));
      expect((edge().shape as OutlinedBorder).side.color, tokens.textPrimary.withValues(alpha: tokens.isDark ? .22 : .26));
      await tester.tap(frame);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      final pointerEdge = edge();
      expect((pointerEdge.shape as OutlinedBorder).side.color, tokens.fieldFocus);
      await tester.tap(find.text('Before'));
      focus.unfocus();
      await tester.pumpAndSettle();
      final beforeFocus = tester.widget<FrostButton>(find.byType(FrostButton));
      expect(beforeFocus.onPressed, isNotNull);
      Focus.of(tester.element(find.text('Before'))).requestFocus();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(focus.hasFocus, isTrue);
      expect(edge(), pointerEdge);
      final editor = tester.widget<TextField>(find.descendant(of: frame, matching: find.byType(TextField)));
      expect(editor.cursorColor, tokens.accent);
      expect(editor.decoration!.filled, isFalse);
      expect(editor.decoration!.focusedBorder, InputBorder.none);
      expect(find.descendant(of: frame, matching: frostFocusRings()), findsNothing);
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });

    testWidgets('menu keyboard current item uses hover fill and no ring $brightness', (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        frostTestApp(
          Center(
            child: SizedBox(
              width: 220,
              child: FrostMenuItem(focusNode: focus, onPressed: () {}, child: const Text('Menu item')),
            ),
          ),
          brightness: brightness,
        ),
      );
      final item = find.byType(FrostMenuItem);
      final tokens = FrostThemeTokens.of(tester.element(item));
      focus.requestFocus();
      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      final colors = tester
          .renderObjectList<RenderDecoratedBox>(find.descendant(of: item, matching: find.byType(DecoratedBox)))
          .map(
            (box) => switch (box.decoration) {
              ShapeDecoration(:final color) => color,
              BoxDecoration(:final color) => color,
              _ => null,
            },
          );
      expect(colors, contains(tokens.textPrimary.withValues(alpha: .04)));
      expect(find.descendant(of: item, matching: frostFocusRings()), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  test('control overlays use four/eight percent without changing base fills', () {
    for (final brightness in Brightness.values) {
      final t = FrostTheme.build(
        config: testConfig,
        brightness: brightness,
        platform: TargetPlatform.windows,
        locale: const Locale('en'),
      ).extension<FrostThemeTokens>()!;
      expect(frostFeedbackSurface(t, {WidgetState.hovered}), t.textPrimary.withValues(alpha: .04));
      expect(frostFeedbackSurface(t, {WidgetState.pressed, WidgetState.hovered}), t.textPrimary.withValues(alpha: .08));
      expect(frostFeedbackSurface(t, {WidgetState.disabled, WidgetState.pressed}).a, 0);
      expect(t.focus, t.textPrimary.withValues(alpha: t.isDark ? .60 : .55));
      expect(FrostMetrics.focusBorderWidth, 1.5);
    }
  });
}

(double, double, double) _oklab(Color color) {
  double linear(double value) => value <= .04045 ? value / 12.92 : math.pow((value + .055) / 1.055, 2.4).toDouble();
  final r = linear(color.r), g = linear(color.g), b = linear(color.b);
  final l = math.pow(.4122214708 * r + .5363325363 * g + .0514459929 * b, 1 / 3);
  final m = math.pow(.2119034982 * r + .6806995451 * g + .1073969566 * b, 1 / 3);
  final s = math.pow(.0883024619 * r + .2817188376 * g + .6299787005 * b, 1 / 3);
  return (
    .2104542553 * l + .793617785 * m - .0040720468 * s,
    1.9779984951 * l - 2.428592205 * m + .4505937099 * s,
    .0259040371 * l + .7827717662 * m - .808675766 * s,
  );
}
