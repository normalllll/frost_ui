import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

// Two columns of 420 with the wide section gap (32) need 872.
const _minimum = 420.0;

Widget _columns(double width, {double scale = 1, int itemCount = 5, Object Function(int)? itemKey, List<String>? labels}) => frostTestApp(
  MediaQuery(
    data: MediaQueryData(size: const Size(1400, 900), textScaler: TextScaler.linear(scale)),
    child: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: width,
        height: 900,
        child: CustomScrollView(
          slivers: [
            FrostSliverList.columns(
              minColumnWidth: _minimum,
              maxColumns: 2,
              dividers: true,
              itemCount: labels?.length ?? itemCount,
              itemKey: itemKey,
              itemBuilder: (context, index) => FrostListRow(
                title: labels?[index] ?? 'Row $index',
                // Every other row is taller: a two-line subtitle and an avatar.
                subtitle: index.isEven ? FrostRowSubtitle('Detail\nSecond line') : null,
                leading: index == 0 ? const FrostLeading.custom(FrostAvatar(initials: 'A', semanticLabel: 'Avatar')) : null,
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);

void _wide(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Finder _hairlines() => find.descendant(of: find.byType(FrostDivider), matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget));

void main() {
  testWidgets('two columns from 872 of width, one below; never more than maxColumns', (tester) async {
    _wide(tester);
    for (final (width, columns) in [(871.0, 1), (872.0, 2), (1400.0, 2)]) {
      await tester.pumpWidget(_columns(width));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final row0 = tester.getRect(find.text('Row 0')), row1 = tester.getRect(find.text('Row 1'));
      expect(row1.left > row0.right, columns == 2, reason: 'width $width');
      // One hairline between lines: 5 items make 3 lines in two columns.
      expect(_hairlines(), findsNWidgets(columns == 2 ? 2 : 4), reason: 'width $width');
    }
  });

  testWidgets('the column minimum grows with text scale', (tester) async {
    _wide(tester);
    await tester.pumpWidget(_columns(1400, scale: 2));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text('Row 1')).top, greaterThan(tester.getRect(find.text('Row 0')).bottom));
  });

  testWidgets('a line is as tall as its tallest row, with rows centred, and divides from the text column', (tester) async {
    _wide(tester);
    await tester.pumpWidget(_columns(1000));
    await tester.pumpAndSettle();
    final tall = tester.getRect(find.ancestor(of: find.text('Row 0'), matching: find.byType(FrostListRow)).first);
    final short = tester.getRect(find.ancestor(of: find.text('Row 1'), matching: find.byType(FrostListRow)).first);
    expect(tall.height, greaterThan(short.height));
    expect(short.center.dy, moreOrLessEquals(tall.center.dy, epsilon: 0.5));
    // The cells sit side by side with the section gap between them.
    expect(short.left - tall.right, moreOrLessEquals(32, epsilon: 0.5));
    expect(tester.getRect(_hairlines().first).top, greaterThanOrEqualTo(tall.bottom - 0.5));
    // The hairline spans the line from the first row's text, past its avatar.
    final line = tester.renderObject<RenderBox>(_hairlines().first);
    final edge = line.globalToLocal(tester.getTopLeft(find.text('Row 0'))).dx;
    expect(edge, greaterThan(32));
    expect(line.size.width, moreOrLessEquals(1000, epsilon: 0.5));
    expect(line, paints..line(p1: Offset(edge, .5), p2: Offset(line.size.width, .5), strokeWidth: 0));
  });

  testWidgets('keyed lines keep their rows when the order changes and build no duplicate anchors', (tester) async {
    _wide(tester);
    var labels = ['a', 'b', 'c', 'd'];
    await tester.pumpWidget(_columns(1000, labels: labels, itemKey: (index) => labels[index]));
    labels = ['c', 'd', 'a', 'b'];
    await tester.pumpWidget(_columns(1000, labels: labels, itemKey: (index) => labels[index]));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.getRect(find.text('c')).top, lessThan(tester.getRect(find.text('a')).top));
    expect(tester.getRect(find.text('d')).left, greaterThan(tester.getRect(find.text('c')).left));
  });
}
