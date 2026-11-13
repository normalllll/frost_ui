import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _kind = ValueKey('kind'), _content = ValueKey('content');

void main() {
  late TextEditingController editing;
  late FocusNode focus;
  late List<String> picked;
  setUp(() {
    editing = TextEditingController(text: 'query');
    focus = FocusNode();
    picked = [];
  });
  tearDown(() {
    editing.dispose();
    focus.dispose();
  });

  Future<void> pump(WidgetTester tester, {double width = 1147, double scale = 1, TextDirection direction = TextDirection.ltr}) async {
    tester.view.physicalSize = Size(width, 717);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final search = FrostCaptionSearch(
      controller: editing,
      focusNode: focus,
      placeholder: 'Find',
      onSubmitted: (_) {},
      content: const SizedBox(key: _content, height: 200),
      actions: [
        FrostToolbarMenuButton(
          key: _kind,
          label: 'Kind',
          valueLabel: 'Illust',
          entries: [
            FrostMenuAction('Novel', onSelected: () => picked.add('novel')),
            FrostMenuAction('User', onSelected: () => picked.add('user')),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: Directionality(
              textDirection: direction,
              child: FrostWindowCaptionScope(
                window: FakeWindow(),
                child: FrostShell(
                  destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
                  selectedIndex: 0,
                  atDestinationRoot: true,
                  onDestinationSelected: (_) {},
                  canGoBack: false,
                  onBack: () {},
                  showsMobileNavigation: true,
                  brand: const FrostShellBrand(expanded: Text('Application')),
                  titleBarSearch: search,
                  titleBarSearchPlacement: FrostCaptionSearchPlacement.end,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder field() => find.byType(FrostSearchInput);
  Finder submit() => find.byWidgetPredicate((widget) => widget is FrostButton && widget.label == 'L.search');

  for (final direction in TextDirection.values) {
    testWidgets('a control shows only while expanded, before submit ($direction)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, direction: direction);
      expect(find.byKey(_kind), findsNothing);
      final rest = tester.getRect(field());

      focus.requestFocus();
      await tester.pumpAndSettle();
      final kind = tester.getRect(find.byKey(_kind)), send = tester.getRect(submit());
      expect(direction == TextDirection.ltr ? kind.right <= send.left : kind.left >= send.right, isTrue);
      expect(tester.getRect(field()).width, greaterThan(rest.width));
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('choosing from a control keeps the search open and returns focus to the field', (tester) async {
    await pump(tester);
    focus.requestFocus();
    await tester.pumpAndSettle();
    final open = tester.getRect(field());
    expect(find.byKey(_content), findsOneWidget);

    await tester.tap(find.byKey(_kind));
    await tester.pumpAndSettle();
    expect(find.byKey(_content), findsOneWidget, reason: 'the dropdown stays while the menu is open');
    expect(tester.getRect(field()), open);

    await tester.tap(find.text('Novel'));
    await tester.pumpAndSettle();
    expect(picked, ['novel']);
    expect(focus.hasFocus, isTrue);
    expect(find.byKey(_content), findsOneWidget);
    expect(tester.getRect(field()), open);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the keyboard reaches a control without closing the search', (tester) async {
    await pump(tester);
    focus.requestFocus();
    await tester.pumpAndSettle();
    final open = tester.getRect(field());
    var reached = false;
    for (var i = 0; i < 4 && !reached; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      final primary = FocusManager.instance.primaryFocus?.context;
      reached = primary != null && find.descendant(of: find.byKey(_kind), matching: find.byElementPredicate((element) => identical(element, primary))).evaluate().isNotEmpty;
    }
    expect(reached, isTrue);
    expect(tester.getRect(field()), open);
    expect(find.byKey(_content), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tap elsewhere with focus on a control collapses the search', (tester) async {
    await pump(tester);
    final rest = tester.getRect(field());
    focus.requestFocus();
    await tester.pumpAndSettle();
    for (var i = 0; i < 4 && focus.hasFocus; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
    }
    expect(find.byKey(_kind), findsOneWidget);

    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(find.byKey(_kind), findsNothing);
    expect(find.byKey(_content), findsNothing);
    expect(tester.getRect(field()), rest);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a control does not show on a resting icon', (tester) async {
    await pump(tester, width: 420);
    expect(find.byKey(_kind), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a control does not overflow large text', (tester) async {
    await pump(tester, scale: 2);
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
