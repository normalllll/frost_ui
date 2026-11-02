import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/lists/_list_input.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';

import 'support.dart';

void main() {
  final suggestions = [
    FrostSearchSuggestionGroup(
      items: [
        FrostSearchSuggestion(label: 'First', onSelected: () {}),
        FrostSearchSuggestion(label: 'Last', onSelected: () {}),
      ],
    ),
  ];

  void viewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  Finder list() => find.byWidgetPredicate((w) => w is FrostList);

  testWidgets('inline list takes the finite room below the field, above the page inset for the keyboard', (tester) async {
    viewport(tester);
    final controller = TextEditingController(text: 'raw'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            padding: EdgeInsets.only(top: 47),
            viewPadding: EdgeInsets.only(top: 47),
            viewInsets: EdgeInsets.only(bottom: 300),
          ),
          child: Builder(
            builder: (context) => Padding(
              padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top, bottom: MediaQuery.viewInsetsOf(context).bottom),
              child: FrostSearchInput.suggesting(
                controller: controller,
                focusNode: focus,
                placeholder: 'Search',
                onSubmitted: (_) {},
                suggestions: suggestions,
                placement: FrostSuggestionPlacement.inline,
              ),
            ),
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    expect(list(), findsNothing);
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.byType(FrostPopoverSurface), findsNothing);
    final field = tester.getRect(find.byType(FrostTextField));
    expect(field.top, 47);
    final rect = tester.getRect(list());
    expect(rect.top, field.bottom);
    expect(rect.bottom, 544);
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline list in an unbounded page flow fits its rows', (tester) async {
    viewport(tester);
    final controller = TextEditingController(text: 'raw'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        ListView(
          children: [
            FrostSearchInput.suggesting(
              controller: controller,
              focusNode: focus,
              placeholder: 'Search',
              onSubmitted: (_) {},
              suggestions: suggestions,
              placement: FrostSuggestionPlacement.inline,
            ),
            const Text('Below'),
          ],
        ),
        platform: TargetPlatform.android,
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final rect = tester.getRect(list());
    expect(rect.top, tester.getRect(find.byType(FrostTextField)).bottom);
    expect(rect.height, lessThan(200));
    expect(tester.getRect(find.text('Below')).top, rect.bottom);
    expect(tester.takeException(), isNull);
  });

  testWidgets('placement switches retain the same EditableText State, selection, composing and focus', (tester) async {
    viewport(tester);
    final controller = FrostTokenEditingController(text: 'sky cloud'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    var inline = false;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, setState) {
            update = setState;
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: 400,
                child: FrostSearchInput.suggesting(
                  controller: controller,
                  focusNode: focus,
                  placeholder: 'Search',
                  onSubmitted: (_) {},
                  suggestions: suggestions,
                  placement: inline ? FrostSuggestionPlacement.inline : FrostSuggestionPlacement.overlay,
                ),
              ),
            );
          },
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    controller.value = const TextEditingValue(text: 'sky cloud', selection: TextSelection.collapsed(offset: 5), composing: TextRange(start: 4, end: 9));
    await tester.pump();
    final editing = controller.value;
    final original = tester.state(find.byType(EditableText));
    for (final target in [true, false, true]) {
      update(() => inline = target);
      await tester.pump();
      expect(tester.state(find.byType(EditableText)), same(original));
      expect(controller.value, editing);
      expect(focus.hasFocus, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(FrostPopoverSurface), target ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('overlay search anchors to its field inside an offset nested Navigator', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1200, 900);
    addTearDown(tester.view.reset);
    final controller = TextEditingController(text: 'raw'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Row(
          children: [
            const SizedBox(width: 220),
            Expanded(
              child: Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 24, top: 20),
                        child: SizedBox(
                          width: 400,
                          child: FrostSearchInput.suggesting(
                            controller: controller,
                            focusNode: focus,
                            placeholder: 'Search',
                            onSubmitted: (_) {},
                            suggestions: suggestions,
                          ),
                        ),
                      ),
                      const Expanded(child: SizedBox.expand()),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    final field = tester.getRect(find.byType(FrostTextField));
    final panel = tester.getRect(find.byType(FrostPopoverSurface));
    expect(field.left, 244);
    expect(panel.left, field.left);
    expect(panel.width, field.width);
    expect(panel.top, greaterThanOrEqualTo(field.bottom));
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('empty inline suggestions without status show no list', (tester) async {
    viewport(tester);
    final controller = TextEditingController(), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostSearchInput.suggesting(
          controller: controller,
          focusNode: focus,
          placeholder: 'Search',
          onSubmitted: (_) {},
          suggestions: const [],
          placement: FrostSuggestionPlacement.inline,
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(list(), findsNothing);
    expect(find.byType(FrostPopoverSurface), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('status-only inline suggestions', () {
    late TextEditingController controller;
    late FocusNode focus;
    setUp(() {
      controller = TextEditingController();
      focus = FocusNode();
    });
    tearDown(() {
      controller.dispose();
      focus.dispose();
    });

    Future<void> pump(WidgetTester tester, {bool loading = false, String? message, List<FrostSearchSuggestionGroup> items = const []}) async {
      await tester.pumpWidget(
        frostTestApp(
          FrostSearchInput.suggesting(
            controller: controller,
            focusNode: focus,
            placeholder: 'Search',
            onSubmitted: (_) {},
            suggestions: items,
            loading: loading,
            message: message,
            placement: FrostSuggestionPlacement.inline,
          ),
          platform: TargetPlatform.android,
        ),
      );
    }

    Finder listInput() => find.byWidgetPredicate((w) => w is FrostListInput);
    Finder inList(Finder finder) => find.descendant(of: listInput(), matching: finder);

    testWidgets('loading alone shows the list with progress', (tester) async {
      viewport(tester);
      await pump(tester, loading: true);
      expect(listInput(), findsNothing, reason: 'an unfocused field shows no list');
      focus.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(listInput(), findsOneWidget);
      expect(inList(find.byType(FrostActivityIndicator)), findsOneWidget);
      expect(find.byType(FrostPopoverSurface), findsNothing);
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a message alone shows the list with the message line', (tester) async {
      viewport(tester);
      await pump(tester, message: 'No matching tags');
      focus.requestFocus();
      await tester.pumpAndSettle();
      expect(inList(find.text('No matching tags')), findsOneWidget);
      expect(inList(find.byType(FrostActivityIndicator)), findsNothing);
      // The line sits on the page content column, like suggestion rows.
      final field = tester.getRect(find.byType(FrostTextField));
      expect(tester.getRect(find.text('No matching tags')).top, field.bottom + FrostGap.group);
      expect(tester.getRect(find.text('No matching tags')).left, field.left);
      expect(find.byType(FrostPopoverSurface), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('loading with a message keeps both on one status line', (tester) async {
      viewport(tester);
      await pump(tester, loading: true, message: 'Searching tags');
      focus.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(inList(find.byType(FrostActivityIndicator)), findsOneWidget);
      expect(inList(find.text('Searching tags')), findsOneWidget);
      expect(tester.getCenter(find.text('Searching tags')).dx, greaterThan(tester.getCenter(inList(find.byType(FrostActivityIndicator))).dx));
      expect(tester.takeException(), isNull);
    });

    testWidgets('status follows retained suggestions, and Escape hides status-only lists', (tester) async {
      viewport(tester);
      await pump(
        tester,
        loading: true,
        items: [
          FrostSearchSuggestionGroup(
            items: [FrostSearchSuggestion(label: 'cat', onSelected: () {})],
          ),
        ],
      );
      focus.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(inList(find.text('cat')), findsOneWidget);
      expect(tester.getRect(inList(find.byType(FrostActivityIndicator))).top, greaterThan(tester.getRect(inList(find.text('cat'))).bottom));

      await pump(tester, message: 'No matching tags');
      await tester.pumpAndSettle();
      expect(inList(find.text('cat')), findsNothing);
      expect(inList(find.text('No matching tags')), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(listInput(), findsNothing);
      expect(focus.hasFocus, isTrue);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('inline list keeps Enter, Escape, separate Down reopen, announcements and input focus', (tester) async {
    viewport(tester);
    final controller = TextEditingController(text: 'raw'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    final calls = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        FrostSearchInput.suggesting(
          controller: controller,
          focusNode: focus,
          placeholder: 'Search',
          onSubmitted: calls.add,
          suggestions: [
            FrostSearchSuggestionGroup(
              items: [
                FrostSearchSuggestion(label: 'First', onSelected: () => calls.add('First')),
                FrostSearchSuggestion(label: 'Last', onSelected: () => calls.add('Last')),
              ],
            ),
          ],
          placement: FrostSuggestionPlacement.inline,
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, ['raw']);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    final semantics = tester.getSemantics(find.byType(EditableText));
    expect(semantics.getSemanticsData().hint, contains('Last 2 / 2'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, ['raw', 'Last']);
    expect(list(), findsNothing);
    expect(focus.hasFocus, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, ['raw', 'Last', 'raw']);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(list(), findsNothing);
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('adaptive placement anchors a panel on wide windows and lists inline on narrow ones, keeping the edit', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1280, 800);
    addTearDown(tester.view.reset);
    final controller = TextEditingController(text: 'raw'), focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            height: 600,
            child: FrostSearchInput.suggesting(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}, suggestions: suggestions),
          ),
        ),
      ),
    );
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(find.byType(FrostPopoverSurface), findsOneWidget);
    expect(find.text('First'), findsOneWidget);
    final editor = tester.state(find.byType(EditableText));

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byType(FrostPopoverSurface), findsNothing);
    expect(find.text('First'), findsOneWidget);
    expect(tester.state(find.byType(EditableText)), same(editor));
    expect(controller.text, 'raw');
    expect(focus.hasFocus, isTrue);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(find.byType(FrostPopoverSurface), findsOneWidget);
    expect(tester.state(find.byType(EditableText)), same(editor));
    expect(tester.takeException(), isNull);
  });
}
