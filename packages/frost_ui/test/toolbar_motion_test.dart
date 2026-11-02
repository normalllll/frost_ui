import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/navigation/toolbar_menu_button.dart' show FrostToolbarControl;

import 'support.dart';

void main() {
  group('page header title arriving and leaving', () {
    void viewport(WidgetTester tester, double width) {
      tester.view.physicalSize = Size(width, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
    }

    Finder outgoingPaint() => find.descendant(
      of: find.byType(FrostLayoutCrossfade),
      matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == '_OutgoingFramePainter'),
    );
    Finder reveal() => find.descendant(of: find.byType(FrostLayoutCrossfade), matching: find.byType(FrostMaterialRevealTransition)).first;
    void expectNoCrossfade(WidgetTester tester) {
      final finder = outgoingPaint();
      final painter = tester.widget<CustomPaint>(finder).foregroundPainter!;
      final size = tester.getSize(finder);
      expect((Canvas canvas) => painter.paint(canvas, size), paintsNothing);
      expect(tester.widget<FrostMaterialRevealTransition>(reveal()).opacity.value, 1);
    }

    Widget header(ValueListenable<bool> shown, {VoidCallback? onBack, List<FrostToolbarItem>? actions, String text = 'Title', bool reduced = false}) => frostTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: Align(
            alignment: Alignment.topCenter,
            child: ValueListenableBuilder(
              valueListenable: shown,
              builder: (_, value, _) => FrostPageHeader(
                title: value ? FrostText(text) : null,
                onBack: onBack ?? () {},
                actions: actions ?? [FrostToolbarItem.action(icon: testIcons.add, label: 'More', onPressed: () {})],
              ),
            ),
          ),
        ),
      ),
    );

    Finder control(String label) => find.byWidgetPredicate((w) => w is FrostToolbarControl && w.label == label);
    Finder itemFade(String label) => find.ancestor(
      of: control(label),
      matching: find.descendant(of: find.byType(FrostToolbar), matching: find.byWidgetPredicate((w) => w is FadeTransition && w.opacity is AnimationController)),
    );
    Widget together(ValueListenable<bool> shown, {VoidCallback? onRead, bool reduced = false}) => frostTestApp(
      Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
          child: Align(
            alignment: Alignment.topCenter,
            child: ValueListenableBuilder(
              valueListenable: shown,
              builder: (_, value, _) => FrostPageHeader(
                title: value ? const FrostText('Title') : null,
                onBack: () {},
                actions: [if (value) FrostToolbarItem.action(icon: testIcons.add, label: 'Read', showsLabel: true, onPressed: onRead ?? () {})],
              ),
            ),
          ),
        ),
      ),
    );

    testWidgets('title and the only action arriving and leaving together keep Back still', (tester) async {
      viewport(tester, 390);
      final shown = ValueNotifier(false);
      addTearDown(shown.dispose);
      final semantics = tester.ensureSemantics();
      var reads = 0;
      bool spoken(String label) {
        var found = false;
        void visit(SemanticsNode node) {
          found = found || node.label.contains(label);
          node.visitChildren((child) {
            visit(child);
            return true;
          });
        }

        visit(tester.getSemantics(find.byType(FrostPageHeader)));
        return found;
      }

      await tester.pumpWidget(together(shown, onRead: () => reads++));
      await tester.pumpAndSettle();
      final back = tester.getRect(find.byType(FrostCompactBackButton));
      Future<void> frames() async {
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 30));
          expectNoCrossfade(tester);
          expect(tester.getRect(find.byType(FrostCompactBackButton)), back);
        }
      }

      shown.value = true;
      await tester.pump();
      expectNoCrossfade(tester);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.widget<FadeTransition>(itemFade('Read')).opacity.value, inExclusiveRange(0, 1));
      await frames();
      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(itemFade('Read')).opacity.value, 1);
      expect(spoken('Read'), isTrue);

      final read = control('Read').hitTestable();
      expect(read, findsOneWidget);
      await tester.tap(read);
      expect(reads, 1);
      FocusScope.of(tester.element(read)).requestFocus();
      for (var i = 0; i < 4 && FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FrostToolbarControl>()?.label != 'Read'; i++) {
        FocusManager.instance.primaryFocus!.nextFocus();
        await tester.pump();
      }
      expect(FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FrostToolbarControl>()?.label, 'Read');
      final tapPoint = tester.getCenter(read);

      shown.value = false;
      await tester.pump();
      expectNoCrossfade(tester);
      await tester.pump(const Duration(milliseconds: 60));
      expect(tester.widget<FadeTransition>(itemFade('Read')).opacity.value, inExclusiveRange(0, 1));
      expect(spoken('Read'), isFalse);
      await tester.tapAt(tapPoint);
      expect(reads, 1);
      await frames();
      await tester.pumpAndSettle();
      expectNoCrossfade(tester);
      expect(control('Read'), findsNothing);
      semantics.dispose();
      expect(tester.getRect(find.byType(FrostCompactBackButton)), back);
    });

    testWidgets('an action leaving and coming back during its exit stays on screen', (tester) async {
      viewport(tester, 390);
      final shown = ValueNotifier(true);
      addTearDown(shown.dispose);
      await tester.pumpWidget(together(shown));
      await tester.pumpAndSettle();
      shown.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      shown.value = true;
      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(itemFade('Read')).opacity.value, 1);
      expect(control('Read').hitTestable(), findsOneWidget);
    });

    testWidgets('reduced motion shows and removes the action at once', (tester) async {
      viewport(tester, 390);
      final shown = ValueNotifier(false);
      addTearDown(shown.dispose);
      await tester.pumpWidget(together(shown, reduced: true));
      await tester.pumpAndSettle();
      shown.value = true;
      await tester.pump();
      expect(tester.widget<FadeTransition>(itemFade('Read')).opacity.value, 1);
      shown.value = false;
      await tester.pump();
      expect(control('Read'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('an action added beside another keeps the row crossfade', (tester) async {
      for (final (width, folds) in [(390.0, false), (170.0, true)]) {
        viewport(tester, width);
        final shown = ValueNotifier(false);
        addTearDown(shown.dispose);
        await tester.pumpWidget(
          frostTestApp(
            Align(
              alignment: Alignment.topCenter,
              child: ValueListenableBuilder(
                valueListenable: shown,
                builder: (_, value, _) => FrostPageHeader(
                  onBack: () {},
                  actions: [
                    FrostToolbarItem.action(icon: testIcons.refresh, label: 'Stay', showsLabel: true, priority: FrostToolbarPriority.low, onPressed: () {}),
                    if (value) FrostToolbarItem.action(icon: testIcons.add, label: 'Added', priority: FrostToolbarPriority.high, onPressed: () {}),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Stay').hitTestable(), findsOneWidget);
        shown.value = true;
        await tester.pump();
        expect(find.text('Stay').hitTestable(), folds ? findsNothing : findsOneWidget);
        final finder = outgoingPaint();
        final painter = tester.widget<CustomPaint>(finder).foregroundPainter!;
        final size = tester.getSize(finder);
        expect((Canvas canvas) => painter.paint(canvas, size), paintsExactlyCountTimes(#drawImageRect, 1));
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpWidget(const SizedBox());
      }
    });

    Finder more_() => find.byWidgetPredicate((w) => w is FrostToolbarControl && w.label == 'More').first;
    Finder faded(String text) => find.ancestor(of: find.text(text), matching: find.descendant(of: find.byType(FrostToolbar), matching: find.byWidgetPredicate((w) => w is FadeTransition && w.opacity is AnimationController)));

    for (final text in ['Title', 'A very long title that cannot fit beside the buttons of this narrow row at all']) {
      testWidgets('buttons stay still with no old frame, ${text.length} chars', (tester) async {
        viewport(tester, 390);
        final shown = ValueNotifier(false);
        addTearDown(shown.dispose);
        var backs = 0;
        await tester.pumpWidget(
          header(
            shown,
            text: text,
            onBack: () => backs++,
            // A high-priority action cannot fold, so only the title changes.
            actions: [FrostToolbarItem.action(icon: testIcons.add, label: 'More', priority: FrostToolbarPriority.high, onPressed: () {})],
          ),
        );
        await tester.pumpAndSettle();
        final back = tester.getRect(find.byType(FrostCompactBackButton));
        final more = tester.getRect(more_());

        Future<void> frames() async {
          for (var i = 0; i < 12; i++) {
            await tester.pump(const Duration(milliseconds: 30));
            expectNoCrossfade(tester);
            expect(tester.getRect(find.byType(FrostCompactBackButton)), back);
            expect(tester.getRect(more_()), more);
          }
        }

        shown.value = true;
        await tester.pump();
        expectNoCrossfade(tester);
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.widget<FadeTransition>(faded(text)).opacity.value, inExclusiveRange(0, 1));
        await frames();
        expect(tester.widget<FadeTransition>(faded(text)).opacity.value, 1);
        expect(tester.getTopLeft(find.text(text)).dx, greaterThanOrEqualTo(back.right));

        shown.value = false;
        await tester.pump();
        expectNoCrossfade(tester);
        await tester.pump(const Duration(milliseconds: 60));
        expect(find.text(text), findsOneWidget);
        expect(tester.widget<FadeTransition>(faded(text)).opacity.value, inExclusiveRange(0, 1));
        await frames();
        await tester.pumpAndSettle();
        expect(find.text(text), findsNothing);

        await tester.tap(find.byType(FrostCompactBackButton));
        expect(backs, 1);
      });
    }

    testWidgets('a title returning during its exit fades back in', (tester) async {
      viewport(tester, 390);
      final shown = ValueNotifier(true);
      addTearDown(shown.dispose);
      await tester.pumpWidget(header(shown));
      await tester.pumpAndSettle();
      shown.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      shown.value = true;
      await tester.pumpAndSettle();
      expect(tester.widget<FadeTransition>(faded('Title')).opacity.value, 1);
    });

    testWidgets('reduced motion shows and removes the title at once', (tester) async {
      viewport(tester, 390);
      final shown = ValueNotifier(false);
      addTearDown(shown.dispose);
      await tester.pumpWidget(header(shown, reduced: true));
      await tester.pumpAndSettle();
      shown.value = true;
      await tester.pump();
      expect(tester.widget<FadeTransition>(faded('Title')).opacity.value, 1);
      shown.value = false;
      await tester.pump();
      expect(find.text('Title'), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a title that folds an action keeps the row crossfade', (tester) async {
      viewport(tester, 240);
      final shown = ValueNotifier(false);
      addTearDown(shown.dispose);
      await tester.pumpWidget(
        header(
          shown,
          text: 'A very long title that takes the room of the labelled action',
          actions: [
            FrostToolbarItem.action(icon: testIcons.refresh, label: 'Refresh', showsLabel: true, priority: FrostToolbarPriority.low, onPressed: () {}),
            FrostToolbarItem.action(icon: testIcons.add, label: 'Add', priority: FrostToolbarPriority.high, onPressed: () {}),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Refresh').hitTestable(), findsOneWidget);
      shown.value = true;
      await tester.pump();
      expect(find.text('Refresh').hitTestable(), findsNothing);
      final finder = outgoingPaint();
      final painter = tester.widget<CustomPaint>(finder).foregroundPainter!;
      final size = tester.getSize(finder);
      expect((Canvas canvas) => painter.paint(canvas, size), paintsExactlyCountTimes(#drawImageRect, 1));
      await tester.pump(const Duration(seconds: 1));
    });
  });

  testWidgets('toolbar folds crossfade after layout, settle through resize, discard snapshots and reduce immediately', (tester) async {
    tester.view.physicalSize = const Size(1800, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final reduced in [false, true]) {
      final width = ValueNotifier(1600.0);
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: Center(
                child: ValueListenableBuilder(
                  valueListenable: width,
                  builder: (_, w, _) => SizedBox(
                    width: w,
                    child: FrostToolbar(
                      title: const Text('Collection heading'),
                      middle: const SizedBox(height: 40),
                      collapsedMiddle: const Icon(Icons.search),
                      trailing: [
                        FrostToolbarItem.action(icon: testIcons.refresh, label: 'Refresh collection', showsLabel: true, onPressed: () {}),
                        FrostToolbarItem.picker(
                          choices: const [
                            FrostPickerOption(value: 0, label: 'Latest'),
                            FrostPickerOption(value: 1, label: 'Popular'),
                            FrostPickerOption(value: 2, label: 'History'),
                          ],
                          value: 0,
                          onChanged: (_) {},
                          label: 'Mode',
                        ),
                        FrostToolbarItem.custom(
                          builder: (_) => const SizedBox(height: 36, child: Text('Custom')),
                          minWidth: 120,
                          overflowEntry: FrostMenuAction('Custom entry', onSelected: () {}),
                        ),
                        FrostToolbarItem.action(icon: testIcons.add, label: 'High', priority: FrostToolbarPriority.high, onPressed: () {}),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          density: FrostDensity.compact,
        ),
      );
      void Function(Canvas) outgoing() {
        final finder = find.descendant(
          of: find.byType(FrostLayoutCrossfade),
          matching: find.byWidgetPredicate((w) => w is CustomPaint && w.foregroundPainter?.runtimeType.toString() == '_OutgoingFramePainter'),
        );
        final painter = tester.widget<CustomPaint>(finder).foregroundPainter!;
        final size = tester.getSize(finder);
        return (canvas) => painter.paint(canvas, size);
      }

      expect(outgoing(), paintsNothing);
      expect(find.text('Refresh collection').hitTestable(), findsOneWidget);
      // Below every fold threshold near here, so the small resizes after the
      // fold starts hold the same layout.
      width.value = 790;
      await tester.pump();
      // Geometry changes in this very layout, before any fade tick.
      expect(find.text('Refresh collection').hitTestable(), findsNothing);
      expect(tester.getSize(find.byType(FrostToolbar)).width, 790);
      expect(find.byType(FrostLayoutCrossfade), findsOneWidget);
      List<FrostMaterialRevealTransition> transitions() => tester
          .widgetList<FrostMaterialRevealTransition>(
            find.descendant(of: find.byType(FrostLayoutCrossfade), matching: find.byType(FrostMaterialRevealTransition)),
          )
          .where((w) => w.opacity is AnimationController || w.opacity is ReverseAnimation || w.opacity is CurvedAnimation)
          .toList();
      if (reduced) {
        expect(outgoing(), paintsNothing);
        expect(transitions().first.opacity.value, 1);
      } else {
        expect(outgoing(), paintsExactlyCountTimes(#drawImageRect, 1));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 90));
        expect(transitions().first.opacity.value, 0);
        await tester.pump(const Duration(milliseconds: 45));
        expect(transitions().where((w) => w.opacity.value > 0 && w.opacity.value < 1).length, greaterThan(0));
        expect(outgoing(), paints..something((method, arguments) => method == #drawImageRect && (arguments[1] as Rect).size == (arguments[2] as Rect).size));
        final held = transitions().first.opacity.value;
        width.value = 789;
        await tester.pump();
        for (var i = 0; i < 6; i++) {
          width.value = 788.0 - i;
          await tester.pump(const Duration(milliseconds: 20));
          expect(transitions().first.opacity.value, held);
          expect(tester.getSize(find.byType(FrostToolbar)).width, width.value);
        }
        // Further discrete changes replace, rather than stack, old snapshots.
        for (final w in [400.0, 1600.0, 800.0]) {
          width.value = w;
          await tester.pump(const Duration(milliseconds: 20));
          expect(outgoing(), paintsExactlyCountTimes(#drawImageRect, 1));
        }
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 200));
        await tester.pump();
        expect(outgoing(), paintsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
      width.dispose();
    }
  });
}
