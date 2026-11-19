import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/feedback/progress.dart';

import 'support.dart';

const _state = FrostVideoState(playing: true, position: Duration(seconds: 65), duration: Duration(seconds: 3605));
const _live = FrostVideoState(playing: true, position: Duration.zero, duration: Duration.zero, live: true);

Widget _frame({
  FrostVideoState state = _state,
  VoidCallback? play,
  ValueChanged<Duration>? seek,
  VoidCallback? fullscreen,
  Widget Function(BuildContext, Duration)? preview,
  Widget Function(BuildContext, Size)? decoration,
}) => frostTestApp(
  MediaQuery(
    data: const MediaQueryData(size: Size(800, 600)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SizedBox(
          width: 800,
          height: 300,
          child: FrostVideoFrame(
            video: const ColoredBox(color: Color(0xFFFFFFFF)),
            state: state,
            onPlayPause: play ?? () {},
            onSeek: seek ?? (_) {},
            onFullscreenToggle: fullscreen ?? () {},
            seekPreviewBuilder: preview,
            trackDecorationBuilder: decoration,
          ),
        ),
      ),
    ),
  ),
);

Rect _thumb(WidgetTester tester) {
  final circles = find.descendant(
    of: find.byType(FrostSlider),
    matching: find.byWidgetPredicate((w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).shape == BoxShape.circle),
  );
  return tester.getRect(circles.first);
}

void main() {
  testWidgets('a live frame has no slider or total, shows the live label and keeps its controls', (tester) async {
    final semantics = tester.ensureSemantics();
    var plays = 0, fulls = 0;
    final seeks = <Duration>[];
    await tester.pumpWidget(_frame(state: _live, play: () => plays++, fullscreen: () => fulls++, seek: seeks.add));
    expect(find.byType(FrostSlider), findsNothing);
    expect(find.textContaining(' / '), findsNothing);
    expect(find.text('L.live'), findsOneWidget);
    await tester.tap(find.byWidgetPredicate((w) => w is FrostMediaButton && w.label == 'L.pause'));
    await tester.tap(find.byWidgetPredicate((w) => w is FrostMediaButton && w.label == 'L.fullscreen'));
    expect(plays, 1);
    expect(fulls, 1);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    expect(seeks, isEmpty);
    expect(tester.getSemantics(find.byType(FrostVideoFrame)).value, contains('L.live'));
    semantics.dispose();
  });

  testWidgets('a seek preview follows the thumb while dragging and ends with one seek', (tester) async {
    final seeks = <Duration>[], positions = <Duration>[];
    await tester.pumpWidget(
      _frame(
        seek: seeks.add,
        preview: (context, position) {
          positions.add(position);
          return const SizedBox(key: ValueKey('preview'), width: 80, height: 40);
        },
      ),
    );
    expect(find.byKey(const ValueKey('preview')), findsNothing);
    expect(positions, isEmpty);
    final rect = tester.getRect(find.byType(FrostSlider));
    final gesture = await tester.startGesture(Offset(rect.left + rect.width * .2, rect.center.dy), kind: PointerDeviceKind.mouse);
    final seen = <Duration>[];
    for (final fraction in [.3, .5, .7]) {
      await gesture.moveTo(Offset(rect.left + rect.width * fraction, rect.center.dy));
      await tester.pump(const Duration(milliseconds: 400));
      final last = positions.last;
      if (seen.isEmpty || seen.last != last) seen.add(last);
      final preview = tester.getRect(find.byKey(const ValueKey('preview'))), thumb = _thumb(tester), frame = tester.getRect(find.byType(FrostVideoFrame));
      expect(preview.bottom, lessThan(thumb.top));
      expect(preview.center.dx, closeTo(thumb.center.dx, 2));
      expect(frame.contains(preview.topLeft) && frame.contains(preview.bottomRight), isTrue);
    }
    expect(seen.length, 3);
    expect(seen[0] < seen[1] && seen[1] < seen[2], isTrue);
    expect(seeks, isEmpty);
    await gesture.up();
    await tester.pump();
    expect(find.byKey(const ValueKey('preview')), findsNothing);
    expect(seeks, hasLength(1));
    expect(seeks.single, seen.last);
  });

  testWidgets('a preview at the slider end stays inside the frame', (tester) async {
    await tester.pumpWidget(_frame(preview: (_, _) => const SizedBox(key: ValueKey('preview'), width: 120, height: 40)));
    final rect = tester.getRect(find.byType(FrostSlider));
    final gesture = await tester.startGesture(Offset(rect.left + rect.width * .5, rect.center.dy), kind: PointerDeviceKind.mouse);
    await gesture.moveTo(Offset(rect.right, rect.center.dy));
    await tester.pump(const Duration(milliseconds: 400));
    final preview = tester.getRect(find.byKey(const ValueKey('preview'))), frame = tester.getRect(find.byType(FrostVideoFrame));
    expect(preview.right, lessThanOrEqualTo(frame.right));
    await gesture.up();
  });

  testWidgets('a track decoration is laid out to the track and sits under the thumb', (tester) async {
    Size? received;
    await tester.pumpWidget(
      _frame(
        decoration: (context, size) {
          received = size;
          return const SizedBox.expand(key: ValueKey('decoration'));
        },
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    final track = tester.getRect(
      find.descendant(of: find.byType(FrostSlider), matching: find.byWidgetPredicate((w) => w is CustomPaint && w.painter is FrostProgressPainter)),
    );
    final decoration = tester.getRect(find.byKey(const ValueKey('decoration')));
    expect(received!.width, closeTo(track.width, .01));
    expect(decoration, track);
    final thumb = _thumb(tester);
    expect(thumb.top, lessThanOrEqualTo(decoration.top));
    expect(thumb.bottom, greaterThanOrEqualTo(decoration.bottom));
  });

  testWidgets('a live frame builds neither a decoration nor a preview', (tester) async {
    var built = 0;
    await tester.pumpWidget(
      _frame(
        state: _live,
        preview: (_, _) {
          built++;
          return const SizedBox();
        },
        decoration: (_, _) {
          built++;
          return const SizedBox();
        },
      ),
    );
    expect(built, 0);
  });
}
