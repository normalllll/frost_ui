import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

class _Stack extends StatefulWidget {
  const _Stack({super.key});
  @override
  State<_Stack> createState() => _StackState();
}

class _StackState extends State<_Stack> {
  int depth = 1;
  void go(int value) => setState(() => depth = value);

  Widget _page(String title) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      FrostPageHeader(title: FrostText(title)),
      const Expanded(child: SizedBox.expand()),
    ],
  );

  @override
  Widget build(BuildContext context) => Navigator(
    pages: [
      MaterialPage<void>(key: const ValueKey('root'), child: _page('Root')),
      if (depth > 0) MaterialPage<void>(key: const ValueKey('a'), child: _page('Page A')),
    ],
    onDidRemovePage: (_) => go(depth - 1),
  );
}

double _size(WidgetTester tester, String title) => tester.renderObject<RenderParagraph>(find.text(title)).text.style!.fontSize!;

void main() {
  // Under a shell no header paints its title (see shell_page_title_test.dart and
  // root_page_title_test.dart); a header outside one does.
  for (final width in [390.0]) {
    Future<_StackState> pump(WidgetTester tester) async {
      tester.view.physicalSize = Size(width, 717);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey<_StackState>();
      await tester.pumpWidget(frostTestApp(_Stack(key: key)));
      await tester.pumpAndSettle();
      return key.currentState!;
    }

    testWidgets('a page popped to the root keeps its title size until it has gone (width $width)', (tester) async {
      final stack = await pump(tester);
      final resting = _size(tester, 'Page A');
      stack.go(0);
      await tester.pump();
      var frames = 0;
      while (find.text('Page A').evaluate().isNotEmpty) {
        expect(_size(tester, 'Page A'), resting);
        await tester.pump(const Duration(milliseconds: 16));
        expect(++frames, lessThan(200));
      }
      expect(frames, greaterThan(1), reason: 'the exit must be observed');
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the root page title keeps its root size after the pop', (tester) async {
    tester.view.physicalSize = const Size(390, 717);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final key = GlobalKey<_StackState>();
    await tester.pumpWidget(frostTestApp(_Stack(key: key)));
    await tester.pumpAndSettle();
    final detail = _size(tester, 'Page A');
    key.currentState!.go(0);
    await tester.pumpAndSettle();
    expect(find.text('Page A'), findsNothing);
    expect(_size(tester, 'Root'), greaterThan(detail));
    expect(tester.takeException(), isNull);
  });
}
