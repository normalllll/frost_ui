// Arrows and chevrons point the way the text reads under icon sets whose
// glyphs mirror themselves in right-to-left text and sets whose glyphs do not.
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/controls/_calendar.dart';
import 'package:frost_ui/src/foundation/icon_data.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

Widget _direction(TextDirection direction, Widget child) => Directionality(textDirection: direction, child: child);

/// Every direction glyph on screen with the way it is painted: whether it
/// points right once the icon has applied its own right-to-left mirroring.
List<({double x, bool pointsRight})> _painted(WidgetTester tester) {
  const pointsRightByCode = {
    0xe100: false, // back
    0xe101: true, // forward
    0xe102: false, // chevron left
    0xe103: true, // chevron right
  };
  final result = <({double x, bool pointsRight})>[];
  for (final element in find.byType(FrostIcon).evaluate()) {
    final icon = (element.widget as FrostIcon).icon;
    if (icon is! FrostGlyphIcon) continue;
    final natural = pointsRightByCode[icon.data.codePoint];
    if (natural == null) continue;
    final mirrored = find
        .descendant(of: find.byWidget(element.widget), matching: find.byType(Transform))
        .evaluate()
        .any((transform) => (transform.widget as Transform).transform.storage[0] < 0);
    result.add((x: tester.getCenter(find.byWidget(element.widget)).dx, pointsRight: mirrored ? !natural : natural));
  }
  result.sort((a, b) => a.x.compareTo(b.x));
  return result;
}

void main() {
  for (final mirrors in [true, false]) {
    final set = directionalTestIcons(mirrors: mirrors);
    final kind = mirrors ? 'self-mirroring icons' : 'plain icons';
    Widget app(TextDirection direction, Widget child) => frostTestApp(icons: set, _direction(direction, Scaffold(body: child)));

    group('trailing chevrons with $kind', () {
      for (final (name, child) in <(String, Widget)>[
        ('FrostModule', FrostModule(title: 'Module', onPressed: () {})),
        ('FrostDisclosure', const FrostDisclosure(title: 'More', child: SizedBox())),
        (
          'FrostSectionHeader.collapsible',
          FrostSectionHeader.collapsible(title: 'Section', expanded: false, onExpansionChanged: (_) {}, child: const SizedBox()),
        ),
        ('FrostListRow', FrostListRow(title: 'Row', accessory: FrostRowAccessory.chevron)),
      ]) {
        for (final direction in TextDirection.values) {
          testWidgets('$name points the way the text reads in ${direction.name}', (tester) async {
            await tester.pumpWidget(app(direction, Center(child: child)));
            final painted = _painted(tester);
            expect(painted, hasLength(1));
            expect(painted.single.pointsRight, direction == TextDirection.ltr);
          });
        }
      }

      for (final direction in TextDirection.values) {
        testWidgets('a submenu entry points the way the text reads in ${direction.name}', (tester) async {
          await tester.pumpWidget(
            app(
              direction,
              Center(
                child: FrostMenuAnchor(
                  entries: [
                    FrostMenuSubmenu('Mode', entries: [FrostMenuAction('Popular', onSelected: () {})]),
                  ],
                  builder: (context, focus, toggle) => TextButton(focusNode: focus, onPressed: toggle, child: const Text('Open')),
                ),
              ),
            ),
          );
          await tester.tap(find.text('Open'));
          await tester.pumpAndSettle();
          final painted = _painted(tester);
          expect(painted, hasLength(1));
          expect(painted.single.pointsRight, direction == TextDirection.ltr);
        });
      }
    });

    group('previous and next arrows with $kind', () {
      void pointAwayFromTheMiddle(WidgetTester tester) {
        final painted = _painted(tester);
        expect(painted, hasLength(2));
        expect(painted.first.pointsRight, isFalse);
        expect(painted.last.pointsRight, isTrue);
      }

      for (final direction in TextDirection.values) {
        testWidgets('FrostShelf in ${direction.name}', (tester) async {
          await tester.pumpWidget(
            app(direction, FrostShelf(title: 'Shelf', itemCount: 30, itemExtent: 100, height: 60, itemBuilder: (context, index) => Text('$index'))),
          );
          await tester.pump();
          pointAwayFromTheMiddle(tester);
        });

        testWidgets('FrostCalendar in ${direction.name}', (tester) async {
          await tester.pumpWidget(
            app(
              direction,
              Center(
                child: FrostCalendar(firstDate: DateTime(2026), lastDate: DateTime(2026, 12, 31), today: DateTime(2026, 10, 16), onSelected: (_) {}),
              ),
            ),
          );
          await tester.pump();
          pointAwayFromTheMiddle(tester);
        });

        testWidgets('FrostPager in ${direction.name}', (tester) async {
          await tester.pumpWidget(app(direction, FrostPager(itemCount: 3, initialPage: 1, itemBuilder: (context, index) => Text('Page $index'))));
          final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
          addTearDown(mouse.removePointer);
          await mouse.addPointer(location: tester.getCenter(find.byType(FrostPager)));
          await tester.pumpAndSettle();
          pointAwayFromTheMiddle(tester);
        });
      }
    });

    group('back arrow with $kind', () {
      for (final direction in TextDirection.values) {
        for (final captioned in [false, true]) {
          testWidgets('the shell Back points toward the reading start in ${direction.name} with captioned=$captioned', (tester) async {
            tester.view.physicalSize = const Size(1200, 700);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await tester.pumpWidget(
              frostTestApp(
                icons: set,
                platform: captioned ? TargetPlatform.windows : TargetPlatform.android,
                FrostWindowCaptionScope(
                  window: captioned ? FakeWindow() : null,
                  child: Directionality(
                    textDirection: direction,
                    child: FrostShell(
                      destinations: [FrostNavDestination(icon: testIcons.image, label: 'Home')],
                      selectedIndex: 0,
                      atDestinationRoot: true,
                      canGoBack: true,
                      onBack: () {},
                      onDestinationSelected: (_) {},
                      showsMobileNavigation: true,
                      brand: const FrostShellBrand(expanded: SizedBox(width: 20, height: 20)),
                      child: const FrostShellDestination(child: SizedBox.expand()),
                    ),
                  ),
                ),
              ),
            );
            final painted = _painted(tester);
            expect(painted, hasLength(1));
            expect(painted.single.pointsRight, direction == TextDirection.rtl);
          });
        }
      }

      for (final direction in TextDirection.values) {
        testWidgets('FrostCompactBackButton points toward the reading start in ${direction.name}', (tester) async {
          await tester.pumpWidget(app(direction, Center(child: FrostCompactBackButton(onPressed: () {}))));
          final painted = _painted(tester);
          expect(painted, hasLength(1));
          expect(painted.single.pointsRight, direction == TextDirection.rtl);
        });
      }
    });
  }
}
