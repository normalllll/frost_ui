import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/_tab_metrics.dart';
import 'support.dart';

void main() {
  for (final width in [590.0, 600.0, 900.0, 1200.0]) {
    for (final rtl in [false, true]) {
      testWidgets('tab actual widths at $width start direction rtl=$rtl', (tester) async {
        final controller = TabController(length: 2, vsync: tester);
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          frostTestApp(
            MediaQuery(
              data: MediaQueryData(size: Size(width, 600)),
              child: Directionality(
                textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: FrostTabBar(
                      controller: controller,
                      scrollable: width >= 600,
                      tabs: [
                        const FrostTab(label: 'One'),
                        FrostTab(label: 'Two', icon: testIcons.info),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        final labels = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_TabLabel');
        final firstTarget = labels.first;
        final secondTarget = labels.last;
        final first = tester.getRect(firstTarget), second = tester.getRect(secondTarget);
        final bar = tester.getRect(find.byType(FrostTabBar));
        if (width < 600) {
          expect(first.width, width / 2);
          expect(second.width, width / 2);
        } else {
          expect(first.width, tester.getSize(find.text('One')).width + 2 * frostTabInset);
          expect(second.width, tester.getSize(find.text('Two')).width + 2 * frostTabInset + FrostControlSize.regular.iconSize + frostTabIconGap);
          expect(rtl ? first.right : first.left, rtl ? bar.right : bar.left);
          expect(rtl ? second.right : second.left, rtl ? first.left : first.right);
          expect(first.width + second.width, lessThan(bar.width));
        }
        controller.index = 1;
        await tester.pumpAndSettle();
        expect(tester.getSize(firstTarget).width, first.width);
        expect(tester.getSize(secondTarget).width, second.width);
        expect(tester.takeException(), isNull);
      });
    }
  }
  test('library source has no Material row or divider constructors or themes', () {
    final constructors = RegExp(r'\b(ListTile|ListTileTheme|ListTileThemeData|Divider|DividerThemeData)\s*(?:\.\w+)?\s*\(');
    final errors = <String>[];
    for (final file in Directory('lib').listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'))) {
      final source = file.readAsStringSync();
      if (constructors.hasMatch(source)) errors.add(file.path);
    }
    expect(errors, isEmpty);
  });
}
