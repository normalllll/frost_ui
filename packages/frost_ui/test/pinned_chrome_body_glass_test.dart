import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

const _width = 400.0;

void main() {
  testWidgets('each body under a pinned bar keeps its own glass while two are side by side', (tester) async {
    final pages = PageController();
    addTearDown(pages.dispose);
    final lists = [ScrollController(), ScrollController()];
    addTearDown(() {
      for (final list in lists) {
        list.dispose();
      }
    });
    var active = 0;
    late StateSetter rebuild;
    await tester.pumpWidget(
      frostTestApp(
        Material(
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: _width,
              height: 600,
              child: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return FrostPinnedChrome(
                    extent: 56,
                    chrome: const SizedBox.expand(),
                    body: PageView(
                      controller: pages,
                      children: [
                        for (var index = 0; index < 2; index++)
                          FrostKeepAlive(
                            child: FrostChromeActiveBody(
                              active: index == active,
                              child: ListView.builder(
                                controller: lists[index],
                                itemExtent: 80,
                                itemCount: 40,
                                itemBuilder: (context, item) => Text('$index-$item'),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final clips = find.byWidgetPredicate((widget) => widget.runtimeType.toString() == '_BodyGlassClip');
    Rect? shown(Finder clip) {
      final box = tester.renderObject<RenderBox>(clip);
      final layer = box.debugLayer;
      final local = layer is ClipRectLayer ? layer.clipRect! : Offset.zero & box.size;
      return MatrixUtils.transformRect(box.getTransformTo(null), local);
    }

    expect(clips, findsNothing, reason: 'nothing is under the bar yet');

    lists[0].jumpTo(200);
    await tester.pumpAndSettle();
    expect(clips, findsOneWidget);
    expect(shown(clips)!.left, 0);
    expect(shown(clips)!.right, _width);

    // Half way to the second body, which is still at its top.
    pages.jumpTo(_width / 2);
    await tester.pump();
    expect(clips, findsOneWidget, reason: 'the body at its top has no glass');
    expect(shown(clips)!.left, 0);
    expect(shown(clips)!.right, _width / 2, reason: 'the glass ends where its body ends');

    // The second body lands and becomes the one on screen.
    pages.jumpTo(_width);
    rebuild(() => active = 1);
    await tester.pumpAndSettle();
    expect(clips, findsOneWidget, reason: 'the first body keeps its glass off screen');
    expect(tester.renderObject<RenderBox>(clips).debugLayer, isNull);

    // On the way back the first body's glass is there from the first frame.
    pages.jumpTo(_width * .75);
    await tester.pump();
    expect(clips, findsOneWidget);
    expect(shown(clips)!.left, 0);
    expect(shown(clips)!.right, _width * .25);

    // Both scrolled: each half has its own glass.
    lists[1].jumpTo(200);
    await tester.pump();
    await tester.pump();
    expect(clips, findsNWidgets(2));
    final spans = [for (final element in clips.evaluate()) shown(find.byElementPredicate((candidate) => candidate == element))!]
      ..sort((a, b) => a.left.compareTo(b.left));
    expect(spans[0].left, 0);
    expect(spans[0].right, _width * .25);
    expect(spans[1].left, _width * .25);
    expect(spans[1].right, _width);
    expect(tester.takeException(), isNull);
  });
}
