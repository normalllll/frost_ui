import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

void main() {
  testWidgets('selecting a segment never changes the control width', (tester) async {
    Future<double> widthWith(String selected, {bool showSelectedIcon = false, bool icons = true}) async {
      await tester.pumpWidget(
        frostTestApp(
          Scaffold(
            body: Center(
              child: FrostSegmentedButton<String>(
                showSelectedIcon: showSelectedIcon,
                segments: [
                  ButtonSegment(value: 'long', icon: icons ? const Icon(Icons.image_outlined, size: 20) : null, label: const Text('A much longer label')),
                  const ButtonSegment(value: 'short', label: Text('Short')),
                ],
                selected: {selected},
                onSelectionChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return tester.getSize(find.byType(FrostSegmentedButton<String>)).width;
    }

    expect(await widthWith('long'), await widthWith('short'));
    // The check that selection adds is reserved on every segment.
    expect(await widthWith('short', showSelectedIcon: true, icons: false), await widthWith('long', showSelectedIcon: true, icons: false));
  });
}
