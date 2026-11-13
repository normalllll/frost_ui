import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('sliver rows share the page scroll view and divide from each text column $direction', (tester) async {
      final built = <int>{};
      await tester.pumpWidget(
        frostTestApp(
          Directionality(
            textDirection: direction,
            child: Center(
              child: SizedBox(
                width: 400,
                height: 600,
                child: CustomScrollView(
                  slivers: [
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                    FrostSliverList(
                      itemCount: 500,
                      dividers: true,
                      itemBuilder: (context, index) {
                        built.add(index);
                        return FrostListRow(
                          title: 'Row $index',
                          subtitle: FrostRowSubtitle('Detail'),
                          leading: index.isEven ? const FrostLeading.custom(FrostAvatar(initials: 'A', semanticLabel: 'Avatar')) : null,
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(built.length, lessThan(40), reason: 'built lazily');
      final lines = find.descendant(of: find.byType(FrostDivider), matching: find.byWidgetPredicate((w) => w is LeafRenderObjectWidget));
      for (final index in [0, 1]) {
        final line = tester.renderObject<RenderBox>(lines.at(index));
        final text = tester.renderObject<RenderBox>(find.text('Row $index'));
        final edge = line.globalToLocal(text.localToGlobal(direction == TextDirection.ltr ? Offset.zero : Offset(text.size.width, 0))).dx;
        // Rows with a leading avatar start their text further in.
        if (direction == TextDirection.ltr) expect(edge, index.isEven ? greaterThan(0) : 0);
        expect(
          line,
          paints..line(
            p1: Offset(direction == TextDirection.ltr ? edge : 0, .5 / tester.view.devicePixelRatio),
            p2: Offset(direction == TextDirection.ltr ? line.size.width : edge, .5 / tester.view.devicePixelRatio),
            strokeWidth: 0,
          ),
          reason: 'row $index',
        );
      }
      // The divider sits between rows: none after the last.
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -100000));
      await tester.pumpAndSettle();
      expect(find.text('Row 499'), findsOneWidget);
      final last = tester.getRect(find.text('Row 499'));
      for (final element in find.byType(FrostDivider).evaluate()) {
        final box = element.renderObject! as RenderBox;
        expect(box.localToGlobal(Offset.zero).dy, lessThan(last.top));
      }
    });
  }

  for (final keyed in [false, true]) {
    testWidgets('row state follows ${keyed ? 'the item key' : 'the index'} when the order changes', (tester) async {
      await tester.pumpWidget(_keyedList(['a', 'b', 'c'], keyed: keyed));
      await tester.pumpWidget(_keyedList(['c', 'a', 'b'], keyed: keyed));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final (label, unkeyedBorn) in [('c', 'a'), ('a', 'b'), ('b', 'c')]) {
        expect(find.text('$label from ${keyed ? label : unkeyedBorn}'), findsOneWidget);
      }
      // Removing an item keeps the others' state.
      await tester.pumpWidget(_keyedList(['c', 'b'], keyed: keyed));
      await tester.pumpAndSettle();
      if (keyed) {
        expect(find.text('c from c'), findsOneWidget);
        expect(find.text('b from b'), findsOneWidget);
      }
      expect(find.byType(FrostDivider), findsOneWidget);
    });
  }
}

class _Marked extends StatefulWidget {
  const _Marked(this.label);
  final String label;
  @override
  State<_Marked> createState() => _MarkedState();
}

class _MarkedState extends State<_Marked> {
  // The label the state was first built for: it moves with the element.
  late final born = widget.label;
  @override
  Widget build(BuildContext context) => FrostListRow(title: '${widget.label} from $born');
}

Widget _keyedList(List<String> items, {required bool keyed}) => frostTestApp(
  SizedBox(
    width: 400,
    height: 600,
    child: CustomScrollView(
      slivers: [
        FrostSliverList(
          itemCount: items.length,
          dividers: true,
          itemKey: keyed ? (index) => items[index] : null,
          itemBuilder: (context, index) => _Marked(items[index]),
        ),
      ],
    ),
  ),
);
