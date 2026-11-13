import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final density in FrostDensity.values) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('a section header keeps its height and title line with or without an action; $platform $density $scale', (tester) async {
          await tester.pumpWidget(
            frostTestApp(
              MediaQuery(
                data: MediaQueryData(size: const Size(1147, 717), textScaler: TextScaler.linear(scale)),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 600,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FrostSectionHeader(title: 'With action', actionLabel: 'View all', onAction: () {}),
                        const FrostSectionHeader(title: 'Without action'),
                        FrostSectionHeader(title: 'With trailing', trailing: [FrostButton.icon(label: 'Next', icon: testIcons.chevronRight, onPressed: () {})]),
                      ],
                    ),
                  ),
                ),
              ),
              density: density,
              platform: platform,
            ),
          );
          final headers = find.byType(FrostSectionHeader);
          final rects = [for (var i = 0; i < 3; i++) tester.getRect(headers.at(i))];
          final titles = [for (final t in ['With action', 'Without action', 'With trailing']) tester.getRect(find.text(t))];
          expect(rects[1].height, rects[0].height);
          expect(rects[2].height, rects[0].height);
          for (var i = 1; i < 3; i++) {
            expect(titles[i].top - rects[i].top, titles[0].top - rects[0].top);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
