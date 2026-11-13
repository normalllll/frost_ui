import 'dart:ui' show Tristate, CheckedState;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_control_geometry.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Future<void> showRow(
  WidgetTester tester,
  Widget row, {
  double width = 400,
  double scale = 1,
  FrostDensity density = FrostDensity.compact,
  bool reduced = false,
  double? margin,
}) {
  final content = margin == null
      ? row
      : Padding(
          padding: EdgeInsets.symmetric(horizontal: margin),
          child: FrostKeyline(
            leadingRoom: margin,
            trailingRoom: margin,
            edgeDistanceStart: margin,
            edgeDistanceEnd: margin,
            insideContainer: false,
            contentStart: 0,
            child: row,
          ),
        );
  return tester.pumpWidget(
    frostTestApp(
      MediaQuery(
        data: MediaQueryData(size: const Size(800, 600), textScaler: TextScaler.linear(scale), disableAnimations: reduced),
        child: Center(
          child: SizedBox(width: width, child: content),
        ),
      ),
      density: density,
    ),
  );
}

Color rowInk(WidgetTester tester, String text) => tester.renderObject<RenderParagraph>(find.text(text)).text.style!.color!;

void main() {
  for (final reduced in [false, true]) {
    testWidgets('row content and flow height transition reduced=$reduced without mount animation', (tester) async {
      var value = 'Short';
      var width = 500.0;
      late StateSetter update;
      await tester.pumpWidget(
        frostTestApp(
          MediaQuery(
            data: MediaQueryData(size: const Size(800, 600), disableAnimations: reduced),
            child: Center(
              child: StatefulBuilder(
                builder: (context, set) {
                  update = set;
                  return SizedBox(
                    width: width,
                    child: FrostListRow(title: 'Title', value: value, accessory: FrostRowAccessory.chevron),
                  );
                },
              ),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      expect(tester.hasRunningAnimations, false);
      final before = tester.getSize(find.byType(FrostClickSurface)).height;
      update(() {
        value = 'A long value that must fully wrap on narrow rows';
        width = 200;
      });
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 90));
      final middle = tester.getSize(find.byType(FrostClickSurface)).height;
      await tester.pumpAndSettle();
      final after = tester.getSize(find.byType(FrostClickSurface)).height;
      expect(after, greaterThan(before));
      if (reduced) {
        expect(middle, after);
      } else {
        expect(middle, inExclusiveRange(before, after));
      }
      expect(tester.getTopLeft(find.text(value)).dy, greaterThan(tester.getBottomLeft(find.text('Title')).dy));
      expect(tester.takeException(), isNull);
    });
  }
  for (final density in [FrostDensity.compact, FrostDensity.comfortable]) {
    for (final scale in [1.0, 2.0]) {
      for (final subtitle in [null, 'Details']) {
        testWidgets('row breathing room $density $scale $subtitle', (tester) async {
          await showRow(
            tester,
            FrostListRow(title: 'Title', subtitle: subtitle == null ? null : FrostRowSubtitle(subtitle)),
            scale: scale,
            density: density,
          );
          final context = tester.element(find.text('Title'));
          final expected = frostControlGeometry(context, FrostControlSize.compact).verticalInset;
          final surface = tester.getRect(find.byType(FrostClickSurface));
          final title = tester.getRect(find.text('Title'));
          final bottom = tester.getRect(find.text(subtitle ?? 'Title')).bottom;
          expect(title.top - surface.top, closeTo(expected, .01));
          expect(surface.bottom - bottom, closeTo(expected, .01));
          expect(surface.height, greaterThanOrEqualTo(FrostControlSize.compact.height(context)));
          if (subtitle != null) expect(tester.getTopLeft(find.text(subtitle)).dy - title.bottom, 2);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
  testWidgets('icon column centers 18 in 28; larger leading shifts title', (tester) async {
    await showRow(tester, FrostListRow(title: 'Title', leading: FrostGlyph.icon(testIcons.info)));
    final surface = tester.getRect(find.byType(FrostClickSurface));
    final icon = tester.getRect(find.byType(FrostIcon));
    expect(icon.width, 18);
    expect(icon.left - surface.left, 5);
    expect(tester.getTopLeft(find.text('Title')).dx - surface.left, 36);
    await showRow(tester, const FrostListRow(title: 'Title', leading: FrostLeading.custom(SizedBox(width: 40, height: 40))));
    expect(tester.getTopLeft(find.text('Title')).dx - tester.getTopLeft(find.byType(FrostClickSurface)).dx, 48);
  });
  testWidgets('wide value then trailing then accessory; actual inks', (tester) async {
    await showRow(
      tester,
      const FrostListRow(
        title: 'Title',
        subtitle: FrostRowSubtitle('Detail'),
        value: 'Value',
        trailing: Text('Tail'),
        accessory: FrostRowAccessory.external,
        destructive: true,
      ),
    );
    final tokens = FrostThemeTokens.of(tester.element(find.text('Title')));
    expect(rowInk(tester, 'Title'), tokens.negativeInk);
    expect(rowInk(tester, 'Detail'), tokens.textSecondary);
    expect(rowInk(tester, 'Value'), tokens.textSecondary);
    expect(tester.getTopLeft(find.text('Value')).dx, lessThan(tester.getTopLeft(find.text('Tail')).dx));
    expect(tester.getTopLeft(find.text('Tail')).dx, lessThan(tester.getTopLeft(find.byType(FrostIcon)).dx));
    final icon = tester.widget<FrostIcon>(find.byType(FrostIcon));
    expect(icon.size, 16);
    expect(icon.color, tokens.textTertiary);
    expect(tester.takeException(), isNull);
  });
  testWidgets('cold narrow 200% wraps all text, value below, accessory at end', (tester) async {
    await showRow(
      tester,
      const FrostListRow(
        title: 'A full title across several lines',
        subtitle: FrostRowSubtitle('A full subtitle across several lines'),
        value: 'A full value across several lines',
        accessory: FrostRowAccessory.chevron,
      ),
      width: 220,
      scale: 2,
    );
    final title = tester.getRect(find.text('A full title across several lines'));
    final subtitle = tester.getRect(find.text('A full subtitle across several lines'));
    final value = tester.getRect(find.text('A full value across several lines'));
    final surface = tester.getRect(find.byType(FrostClickSurface));
    final accessory = tester.getRect(find.byType(FrostIcon));
    expect(value.top - subtitle.bottom, 2);
    expect(value.left, title.left);
    expect(accessory.right, surface.right);
    expect(accessory.center.dy, surface.center.dy);
    for (final text in ['A full title across several lines', 'A full subtitle across several lines', 'A full value across several lines']) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(paragraph.maxLines, isNull);
      expect(paragraph.didExceedMaxLines, false);
    }
    expect(tester.takeException(), isNull);
  });
  for (final margin in [12.0, 20.0]) {
    testWidgets('plain row keyline and rounded feedback at margin $margin', (tester) async {
      await showRow(
        tester,
        FrostListRow(title: 'Title', onPressed: () {}),
        margin: margin,
      );
      final row = tester.getRect(find.byType(FrostListRow));
      final surface = tester.getRect(find.byType(FrostClickSurface));
      final inset = FrostGap.of(tester.element(find.text('Title'))).hitInset;
      final snapped = margin - inset <= 4;
      expect(tester.getTopLeft(find.text('Title')).dx, row.left);
      expect(surface.left, row.left - (snapped ? margin : inset));
      final shape = tester
          .widget<FrostClickFeedbackVisual>(find.descendant(of: find.byType(FrostClickSurface), matching: find.byType(FrostClickFeedbackVisual)).first)
          .shape!;
      final radius = switch (shape) {
        RoundedSuperellipseBorder(:final borderRadius) => borderRadius,
        RoundedRectangleBorder(:final borderRadius) => borderRadius,
        _ => throw StateError('shape'),
      };
      expect(radius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.sm);
    });
  }
  testWidgets('toggle/check each exposes one actionable state node and whole row click', (tester) async {
    final semantics = tester.ensureSemantics();
    bool? changed;
    await showRow(tester, FrostListRow.toggle(title: 'Toggle', subtitle: FrostRowSubtitle('Details'), value: false, onChanged: (value) => changed = value));
    final node = tester.getSemantics(find.bySemanticsLabel('Toggle'));
    expect(node.childrenCount, 0);
    expect(node.getSemanticsData().flagsCollection.isToggled, Tristate.isFalse);
    await tester.tap(find.text('Toggle'));
    expect(changed, true);
    var count = 0;
    await showRow(tester, FrostListRow.check(title: 'Check', checked: true, onPressed: () => count++));
    final check = tester.getSemantics(find.bySemanticsLabel('Check'));
    expect(check.childrenCount, 0);
    expect(check.getSemanticsData().flagsCollection.isChecked, CheckedState.isTrue);
    await tester.tap(find.text('Check'));
    expect(count, 1);
    semantics.dispose();
  });
  testWidgets('disabled row opacity, input and focus; context menu', (tester) async {
    var count = 0;
    await showRow(tester, FrostListRow(title: 'Title', enabled: false, onPressed: () => count++));
    expect(
      tester
          .renderObject<RenderFrostContentFade>(find.descendant(of: find.byType(FrostAnimatedMaterialReveal), matching: find.byType(FrostContentFade)).first)
          .opacity,
      .38,
    );
    expect(tester.widget<FrostClickSurface>(find.byType(FrostClickSurface)).focusNode!.canRequestFocus, false);
    await tester.tap(find.text('Title'), warnIfMissed: false);
    expect(count, 0);
    await showRow(
      tester,
      FrostListRow(
        title: 'Title',
        contextMenu: [FrostMenuAction('Copy', onSelected: () => count++)],
      ),
    );
    await tester.tap(find.text('Title'), buttons: 2);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Copy'));
    await tester.pumpAndSettle();
    expect(count, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets('row hover and press have real intermediate feedback', (tester) async {
    await showRow(tester, FrostListRow(title: 'Title', onPressed: () {}));
    Color color() =>
        (tester.widget<DecoratedBox>(find.descendant(of: find.byType(FrostInteractionDecoration), matching: find.byType(DecoratedBox)).first).decoration
                as ShapeDecoration)
            .color!;
    final tokens = FrostThemeTokens.of(tester.element(find.text('Title')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('Title')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(color().a, greaterThan(0));
    expect(color(), isNot(frostFeedbackSurface(tokens, {WidgetState.hovered})));
    await tester.pumpAndSettle();
    final before = color();
    await mouse.down(tester.getCenter(find.text('Title')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(color(), isNot(before));
    expect(color(), isNot(frostFeedbackSurface(tokens, {WidgetState.pressed, WidgetState.hovered})));
    await mouse.up();
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  for (final status in [false, true]) {
    testWidgets('subtitle maxLines caps lines with an ellipsis and keeps the full value status=$status', (tester) async {
      final semantics = tester.ensureSemantics();
      final text = List.filled(30, 'A long plan description').join(' ');
      await showRow(
        tester,
        FrostListRow(
          title: 'Full plan',
          subtitle: status ? FrostRowSubtitle.status(text, FrostStatusTone.positive, maxLines: 2) : FrostRowSubtitle(text, maxLines: 2),
          onPressed: () {},
        ),
        width: 300,
      );
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      expect(paragraph.maxLines, 2);
      expect(paragraph.overflow, TextOverflow.ellipsis);
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(tester.getSemantics(find.byType(FrostListRow)).getSemanticsData().value, text);
      await showRow(tester, FrostListRow(title: 'Full plan', subtitle: FrostRowSubtitle(text), onPressed: () {}), width: 300);
      expect(tester.renderObject<RenderParagraph>(find.text(text)).maxLines, isNull);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }
}
