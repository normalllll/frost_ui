import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    for (final width in [320.0, 480.0]) {
      testWidgets('split detail actions fit and remain usable at scale $scale primary $width', (tester) async {
        tester.view.physicalSize = const Size(640, 480);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        var calls = 0;
        await tester.pumpWidget(
          frostTestApp(
            MediaQuery(
              data: MediaQueryData(size: const Size(640, 480), textScaler: TextScaler.linear(scale)),
              child: Align(
                alignment: Alignment.centerRight,
                child: SizedBox(
                  width: 580,
                  child: FrostSplitView(
                    initialPrimaryWidth: width,
                    primary: const SizedBox.expand(),
                    onCloseSecondary: () {},
                    secondary: CustomScrollView(
                      slivers: [
                        FrostSliverContentColumn(
                          maxWidth: FrostMetrics.readingMaxWidth,
                          sliver: SliverToBoxAdapter(
                            child: Column(
                              children: [
                                FrostProfileHeader(
                                  avatar: const FrostAvatar.person(name: 'zhang', colorKey: 'zhang'),
                                  title: 'zhang',
                                  actions: [FrostButton(icon: testIcons.refresh, label: 'Test connection', onPressed: () => calls++)],
                                  moreAction: FrostButton.icon(icon: testIcons.more, label: 'More profile', onPressed: () => calls++),
                                ),
                                FrostSectionHeader(title: 'Commit identities', actionLabel: 'Add identity', onAction: () => calls++),
                                FrostSectionHeader(
                                  title: 'Repository operations',
                                  trailing: [
                                    FrostButton(label: 'Review changes', onPressed: () => calls++),
                                    FrostButton.icon(icon: testIcons.more, label: 'More section', onPressed: () => calls++),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        for (final label in ['Test connection', 'More profile', 'Add identity', 'Review changes', 'More section']) {
          final button = find.byWidgetPredicate((widget) => widget is FrostButton && widget.label == label);
          await tester.ensureVisible(button);
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }
        expect(calls, 5);
      });
    }
  }
}
