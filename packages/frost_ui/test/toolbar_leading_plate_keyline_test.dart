import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _reference = ValueKey('reference');
Finder get _field => find.byKey(_reference);
Finder get _segments => find.byWidgetPredicate((widget) => widget is FrostPicker<int>).hitTestable();

Widget _page({
  TextDirection direction = TextDirection.ltr,
  List<FrostToolbarItem> after = const [],
  FrostToolbarPriority priority = FrostToolbarPriority.normal,
}) => Directionality(
  textDirection: direction,
  child: Scaffold(
    body: FrostContentColumn(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FrostToolbar(
            controls: [
              FrostToolbarItem.picker<int>(
                label: 'Kind',
                priority: priority,
                value: 0,
                onChanged: (_) {},
                choices: const [
                  FrostPickerOption(value: 0, label: 'Illust & Manga'),
                  FrostPickerOption(value: 1, label: 'Novels'),
                ],
              ),
              ...after,
            ],
          ),
          FrostTextField(key: _reference, label: 'Name', controller: TextEditingController()),
        ],
      ),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget page, double width) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(frostTestApp(page));
  await tester.pumpAndSettle();
}

void main() {
  for (final direction in TextDirection.values) {
    testWidgets('a segmented first control starts on the content keyline in ${direction.name}', (tester) async {
      await _pump(tester, _page(direction: direction), 1100);
      final segments = tester.getRect(_segments);
      final field = tester.getRect(_field);
      if (direction == TextDirection.ltr) {
        expect(segments.left, field.left);
      } else {
        expect(segments.right, field.right);
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a first control compacted to a menu keeps its label on the keyline in ${direction.name}', (tester) async {
      final items = [
        for (var i = 0; i < 6; i++)
          FrostToolbarItem.picker<int>(
            label: 'Filter $i',
            value: 0,
            onChanged: (_) {},
            choices: const [
              FrostPickerOption(value: 0, label: 'Everything here'),
              FrostPickerOption(value: 1, label: 'Only some'),
            ],
          ),
      ];
      await _pump(tester, _page(direction: direction, after: items, priority: FrostToolbarPriority.high), 390);
      final label = find.text('Illust & Manga').hitTestable();
      expect(label, findsOneWidget);
      final text = tester.getRect(label), field = tester.getRect(find.text('Name'));
      if (direction == TextDirection.ltr) {
        expect(text.left, field.left);
      } else {
        expect(text.right, field.right);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
