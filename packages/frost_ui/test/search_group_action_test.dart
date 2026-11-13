import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/_popover_surface.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Finder _row(String text) => find.byWidgetPredicate((w) => w is FrostListRow && w.title == text);

/// Recent history with a clear action and saved tags with a manage action.
class _History extends StatefulWidget {
  const _History({required this.builder, required this.calls});
  final Widget Function(Widget content) builder;
  final List<String> calls;
  @override
  State<_History> createState() => _HistoryState();
}

class _HistoryState extends State<_History> {
  var _recent = ['cat', 'dog'];
  @override
  Widget build(BuildContext context) => widget.builder(
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FrostSearchSection(
          title: 'Recent',
          actionLabel: 'Clear',
          onAction: () {
            widget.calls.add('clear');
            setState(() => _recent = []);
          },
          children: [for (final query in _recent) FrostSearchSuggestionRow(label: query, onSelected: () => widget.calls.add(query))],
        ),
        FrostSearchSection(
          title: 'My tags',
          actionLabel: 'Manage',
          onAction: () => widget.calls.add('manage'),
          children: [FrostSearchSuggestionRow(label: 'landscape', onSelected: () => widget.calls.add('landscape'))],
        ),
      ],
    ),
  );
}

void main() {
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

  Future<void> pump(WidgetTester tester, Widget child, {Size size = const Size(800, 600)}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
    await tester.pumpWidget(frostTestApp(child));
    focus.requestFocus();
    await tester.pumpAndSettle();
  }

  String hint(WidgetTester tester) => tester.getSemantics(find.byType(EditableText)).getSemanticsData().hint;

  testWidgets('anchored group actions are clickable without taking focus or closing the panel', (tester) async {
    final calls = <String>[];
    await pump(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 480,
          child: _History(
            calls: calls,
            builder: (content) =>
                FrostSearchInput.suggesting(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: calls.add, content: content),
          ),
        ),
      ),
    );
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Clear'), findsOneWidget);
    expect(find.text('Manage'), findsOneWidget);
    // The title stays on the group's first line; the action shares its row.
    expect(tester.getCenter(find.text('Clear')).dy, closeTo(tester.getCenter(find.text('Recent')).dy, 1));
    // The action text ends on the content edge that the title starts on.
    final panel = tester.getRect(find.byType(FrostPopoverSurface));
    expect(panel.right - tester.getRect(find.text('Clear')).right, closeTo(tester.getRect(find.text('Recent')).left - panel.left, .01));

    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    expect(calls, isEmpty, reason: 'the title text is not the action');

    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(calls, ['clear']);
    expect(focus.hasFocus, isTrue);
    expect(find.byType(FrostPopoverSurface), findsOneWidget);
    // A group without items shows neither its title nor its action.
    expect(find.text('Recent'), findsNothing);
    expect(find.text('Clear'), findsNothing);
    expect(_row('landscape'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('arrow keys reach each group action before its items and Enter runs it', (tester) async {
    final calls = <String>[];
    final semantics = tester.ensureSemantics();
    await pump(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 480,
          child: _History(
            calls: calls,
            builder: (content) =>
                FrostSearchInput.suggesting(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: calls.add, content: content),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(hint(tester), contains('Clear, Recent'));
    expect(hint(tester), contains('1 / 5'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(hint(tester), contains('cat'));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(hint(tester), contains('Manage, My tags'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, ['manage']);
    expect(focus.hasFocus, isTrue);
    expect(find.byType(FrostPopoverSurface), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(hint(tester), contains('Clear, Recent'));
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(calls, ['manage', 'clear']);
    expect(focus.hasFocus, isTrue);
    // The highlight moves to a surviving entry instead of a removed one.
    expect(hint(tester), contains('/ 2'));
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('inline page suggestions show the group action', (tester) async {
    final calls = <String>[];
    await pump(
      tester,
      _History(
        calls: calls,
        builder: (content) => FrostSearchInput.suggesting(
          controller: controller,
          focusNode: focus,
          placeholder: 'Search',
          onSubmitted: calls.add,
          content: content,
          placement: FrostSuggestionPlacement.inline,
        ),
      ),
      size: const Size(390, 844),
    );
    expect(find.byType(FrostPopoverSurface), findsNothing);
    expect(find.text('Clear'), findsOneWidget);
    await tester.tap(find.text('Manage'));
    await tester.pumpAndSettle();
    expect(calls, ['manage']);
    expect(focus.hasFocus, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('caption search dropdown shows the group action', (tester) async {
    final calls = <String>[];
    await pump(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 360,
          height: 32,
          child: _History(
            calls: calls,
            builder: (content) => FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: calls.add, content: content),
          ),
        ),
      ),
    );
    expect(find.text('Clear'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();
    expect(calls, ['clear']);
    expect(focus.hasFocus, isTrue);
    expect(find.text('Manage'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a group without an action keeps its plain title above the first item', (tester) async {
    await pump(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 480,
          child: FrostSearchInput.suggesting(
            controller: controller,
            focusNode: focus,
            placeholder: 'Search',
            onSubmitted: (_) {},
            content: FrostSearchSection(
              title: 'Recent',
              actionLabel: 'Clear',
              children: [FrostSearchSuggestionRow(label: 'cat', onSelected: () {})],
            ),
          ),
        ),
      ),
    );
    expect(find.text('Recent'), findsOneWidget);
    expect(find.text('Clear'), findsNothing, reason: 'an action needs both a label and a callback');
    expect(tester.getRect(find.text('Recent')).bottom, lessThan(tester.getRect(find.text('cat')).top));
    expect(tester.takeException(), isNull);
  });
}
