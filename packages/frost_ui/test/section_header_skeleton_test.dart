import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/feedback/_skeleton_geometry.dart';
import 'support.dart';

void main() {
  Future<List<Rect>> bones(WidgetTester tester, {required bool pathTitle}) async {
    await tester.pumpWidget(
      frostTestApp(
        Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: Column(
              children: [FrostSectionHeader(title: r'D:\work', pathTitle: pathTitle)],
            ).frostSkeleton(true),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    return tester.renderObject<RenderFrostSkeletonText>(find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_TextBone')).bones;
  }

  testWidgets('a path title header lays out under a skeleton with the bone height of a plain title', (tester) async {
    final plain = await bones(tester, pathTitle: false);
    final path = await bones(tester, pathTitle: true);
    expect(plain, hasLength(1));
    expect(path, hasLength(1));
    expect(path.single.height, plain.single.height);
    expect(path.single.width, greaterThan(0));
  });
}
