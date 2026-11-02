import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

Finder get _cancel => find.text('L.cancel');
Finder get _field => find.byType(FrostTextField);
Finder get _header => find.byType(FrostPageHeader);

void main() {
  late TextEditingController controller;
  late FocusNode focus, before;
  late FrostPageHeaderSearchController search;
  late List<String> calls;
  setUp(() {
    controller = TextEditingController(text: 'cat');
    focus = FocusNode(debugLabel: 'search');
    before = FocusNode(debugLabel: 'before');
    search = FrostPageHeaderSearchController();
    calls = [];
  });
  tearDown(() {
    controller.dispose();
    focus.dispose();
    before.dispose();
    search.dispose();
  });

  void viewport(WidgetTester tester, double width) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = Size(width, 844);
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  Widget page({bool reduceMotion = false, List<FrostToolbarItem>? actions}) => Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: Column(
        children: [
          FrostPageHeader(
            title: const FrostText('Browse'),
            searchController: search,
            middle: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: calls.add),
            actions: actions ?? [FrostToolbarItem.action(icon: testIcons.more, label: 'Filter', onPressed: () => calls.add('filter'))],
          ),
          Focus(focusNode: before, child: const SizedBox(width: 40, height: 40)),
        ],
      ),
    ),
  );

  Future<Rect> focusSearch(WidgetTester tester) async {
    before.requestFocus();
    await tester.pump();
    final rest = tester.getRect(_field);
    await tester.tap(_field);
    await tester.pumpAndSettle();
    return rest;
  }

  testWidgets('a narrow row expands the focused field over itself and Cancel restores it', (tester) async {
    viewport(tester, 390);
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(frostTestApp(page()));
    final header = tester.getRect(_header);
    final state = tester.state(find.byType(EditableText));
    expect(_cancel, findsNothing);
    final rest = await focusSearch(tester);

    expect(search.expanded, isTrue);
    expect(focus.hasFocus, isTrue);
    expect(tester.state(find.byType(EditableText)), same(state), reason: 'editing State moves with the field');
    expect(tester.getRect(_header), header, reason: 'the header keeps its height');
    final field = tester.getRect(_field), cancel = tester.getRect(_cancel);
    expect(field.left, lessThan(rest.left));
    final browse = tester.getRect(find.text('Browse'));
    expect(field.left, browse.left - FrostGap.hitInset, reason: 'the field bleeds past the content edge like the plates around it');
    expect(field.width, greaterThan(rest.width));
    expect(cancel.left, greaterThan(field.right));
    // Cancel's text ends on the content edge the row starts on.
    expect(header.right - cancel.right, closeTo(browse.left - header.left, .01));
    expect(tester.getCenter(_cancel).dy, closeTo(tester.getCenter(_field).dy, .5));
    // The covered row leaves hit testing, traversal and semantics.
    expect(find.semantics.byLabel('Browse'), findsNothing);
    expect(find.semantics.byLabel('Filter'), findsNothing);
    expect(find.semantics.byLabel('L.cancel'), findsOneWidget);
    await tester.tap(find.text('Browse'), warnIfMissed: false);
    expect(calls, isEmpty);
    expect(focus.hasFocus, isTrue);

    await tester.tap(_cancel);
    await tester.pumpAndSettle();
    expect(search.expanded, isFalse);
    expect(_cancel, findsNothing);
    expect(tester.getRect(_field), rest);
    expect(controller.text, 'cat', reason: 'collapsing keeps the query');
    expect(focus.hasFocus, isFalse);
    expect(before.hasFocus, isTrue, reason: 'focus returns to where it was before the search');
    expect(tester.state(find.byType(EditableText)), same(state));
    expect(find.semantics.byLabel('Filter'), findsOneWidget);
    tester.semantics.tap(find.semantics.byLabel('Filter'));
    expect(calls, ['filter']);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Tab never reaches the covered row or Cancel', (tester) async {
    viewport(tester, 390);
    await tester.pumpWidget(frostTestApp(page()));
    await focusSearch(tester);
    final toolbar = find.byType(FrostToolbar);
    for (var i = 0; i < 6; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final primary = FocusManager.instance.primaryFocus!.context!;
      expect(
        find.ancestor(of: find.byElementPredicate((e) => e == primary), matching: toolbar),
        findsNothing,
        reason: 'Tab $i',
      );
      expect(find.ancestor(of: find.byElementPredicate((e) => e == primary), matching: find.byWidgetPredicate((w) => w is Opacity)), findsNothing);
    }
    expect(search.expanded, isTrue, reason: 'leaving the field does not collapse it');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Escape collapses, also while suggestions show; submitting does not', (tester) async {
    viewport(tester, 390);
    await tester.pumpWidget(frostTestApp(page()));
    await focusSearch(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, ['cat']);
    expect(search.expanded, isTrue, reason: 'the App decides what a submitted query does');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(search.expanded, isFalse);
    expect(before.hasFocus, isTrue);
    expect(controller.text, 'cat');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the App collapses through the controller, for example after navigating', (tester) async {
    viewport(tester, 390);
    await tester.pumpWidget(frostTestApp(page()));
    await focusSearch(tester);
    var notified = 0;
    search.addListener(() => notified++);
    search.collapse();
    await tester.pumpAndSettle();
    expect(search.expanded, isFalse);
    expect(notified, 1);
    expect(_cancel, findsNothing);
    expect(before.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system Back first restores the row, then leaves the page', (tester) async {
    viewport(tester, 390);
    await tester.pumpWidget(frostTestApp(const SizedBox()));
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(MaterialPageRoute<void>(builder: (_) => page()));
    await tester.pumpAndSettle();
    await focusSearch(tester);
    expect(search.expanded, isTrue);

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(search.expanded, isFalse);
    expect(_header, findsOneWidget, reason: 'the page stays');
    expect(controller.text, 'cat');

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(_header, findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a row with the expanded search width keeps its layout', (tester) async {
    viewport(tester, 1200);
    await tester.pumpWidget(frostTestApp(page()));
    final rest = await focusSearch(tester);
    expect(focus.hasFocus, isTrue);
    expect(search.expanded, isFalse);
    expect(_cancel, findsNothing);
    expect(tester.getRect(_field), rest);
    expect(find.text('Browse'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(focus.hasFocus, isTrue, reason: 'Escape keeps its ordinary meaning');
    expect(tester.takeException(), isNull);
  });

  testWidgets('the decision follows the room the row actually leaves, not the platform', (tester) async {
    // 800 wide with no actions leaves the field more than 520 beside the title.
    viewport(tester, 800);
    await tester.pumpWidget(frostTestApp(page(actions: const [])));
    await focusSearch(tester);
    expect(search.expanded, isFalse);
    // The same width with actions leaves less than 520: cover.
    await tester.pumpWidget(
      frostTestApp(
        page(
          actions: [
            for (final label in ['Sort', 'Filter', 'Layout', 'Select'])
              FrostToolbarItem.action(icon: testIcons.more, label: label, showsLabel: true, priority: FrostToolbarPriority.high, onPressed: () {}),
          ],
        ),
      ),
    );
    focus.unfocus();
    await tester.pump();
    await focusSearch(tester);
    expect(search.expanded, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion switches in one frame', (tester) async {
    viewport(tester, 390);
    await tester.pumpWidget(frostTestApp(page(reduceMotion: true)));
    before.requestFocus();
    await tester.pump();
    await tester.tap(_field);
    await tester.pump();
    await tester.pump();
    final field = tester.getRect(_field);
    expect(field.left, tester.getRect(find.text('Browse')).left - FrostGap.hitInset);
    expect(tester.widget<Opacity>(find.ancestor(of: _cancel, matching: find.byType(Opacity)).first).opacity, 1);
    await tester.tap(_cancel);
    await tester.pump();
    await tester.pump();
    expect(_cancel, findsNothing);
    expect(before.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a suggesting header search keeps its suggestions while the header is covered', (tester) async {
    viewport(tester, 390);
    await tester.pumpWidget(
      frostTestApp(
        Column(
          children: [
            FrostPageHeader(
              title: const FrostText('Browse'),
              searchController: search,
              middle: FrostSearchInput.suggesting(
                controller: controller,
                focusNode: focus,
                placeholder: 'Search',
                onSubmitted: calls.add,
                suggestions: [
                  FrostSearchSuggestionGroup(
                    items: [FrostSearchSuggestion(label: 'catgirl', onSelected: () => calls.add('catgirl'))],
                  ),
                ],
              ),
            ),
            const Expanded(child: Text('Landing')),
          ],
        ),
        platform: TargetPlatform.android,
      ),
    );
    final state = tester.state(find.byType(EditableText));
    expect(find.text('Landing'), findsOneWidget);
    focus.requestFocus();
    await tester.pumpAndSettle();
    expect(search.expanded, isTrue);
    expect(focus.hasFocus, isTrue);
    expect(tester.state(find.byType(EditableText)), same(state));
    expect(find.text('catgirl'), findsOneWidget);
    expect(tester.getRect(find.text('catgirl')).top, greaterThan(tester.getRect(_field).bottom));
    await tester.tap(find.text('catgirl'));
    await tester.pumpAndSettle();
    expect(calls, ['catgirl']);
    expect(search.expanded, isTrue);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(search.expanded, isFalse);
    expect(find.text('Landing'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right-to-left rows cover toward the start edge', (tester) async {
    viewport(tester, 390);
    await tester.pumpWidget(frostTestApp(Directionality(textDirection: TextDirection.rtl, child: page())));
    await focusSearch(tester);
    final field = tester.getRect(_field), cancel = tester.getRect(_cancel);
    expect(cancel.right, lessThan(field.left));
    final header = tester.getRect(_header);
    final browse = tester.getRect(find.text('Browse'));
    expect(cancel.left - header.left, closeTo(header.right - browse.right, .01));
    expect(field.right, browse.right + FrostGap.hitInset);
    expect(tester.takeException(), isNull);
  });
}
