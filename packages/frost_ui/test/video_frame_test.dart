import 'dart:ui' show Tristate;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/feedback/progress.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:frost_ui/src/media/_video_bar.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'material_reveal_test.dart' show expectSafeLayers;
import 'support.dart';

const initial = FrostVideoState(playing: true, position: Duration(seconds: 65), duration: Duration(seconds: 3605), buffered: Duration(seconds: 1800));
Widget video({FrostVideoState state = initial, VoidCallback? play, ValueChanged<Duration>? seek, VoidCallback? mute, VoidCallback? fullscreen}) =>
    FrostVideoFrame(
      video: const ColoredBox(color: Color(0xFFFFFFFF)),
      state: state,
      onPlayPause: play ?? () {},
      onSeek: seek ?? (_) {},
      onMuteToggle: mute ?? () {},
      onFullscreenToggle: fullscreen ?? () {},
    );
Widget view(Widget child, {double width = 800, double scale = 1, bool reduced = false, TextDirection direction = TextDirection.ltr}) => frostTestApp(
  MediaQuery(
    data: MediaQueryData(size: Size(width, 600), textScaler: TextScaler.linear(scale), disableAnimations: reduced),
    child: Directionality(
      textDirection: direction,
      child: Center(
        child: SizedBox(width: width, height: 300, child: child),
      ),
    ),
  ),
);
Finder button(String label) => find.byWidgetPredicate((w) => w is FrostMediaButton && w.label == label);
Future<void> mount(WidgetTester tester, Widget child) async {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox());
  });
  await tester.pumpWidget(child);
}

void main() {
  testWidgets('App control slots receive finite width before horizontal overflow', (tester) async {
    BoxConstraints? received;
    await mount(
      tester,
      view(
        FrostVideoFrame(
          video: const SizedBox.expand(),
          state: initial,
          onPlayPause: () {},
          onSeek: (_) {},
          controls: [
            LayoutBuilder(
              builder: (context, constraints) {
                received = constraints;
                return const SizedBox(width: double.infinity, height: 30);
              },
            ),
          ],
        ),
        width: 320,
      ),
    );
    expect(received!.hasBoundedWidth, isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets('a missing mute callback leaves no slot, focus or semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    VoidCallback? mute;
    late StateSetter update;
    await mount(
      tester,
      view(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostVideoFrame(
              video: const SizedBox.expand(),
              state: const FrostVideoState(playing: false, position: Duration.zero, duration: Duration(seconds: 12)),
              onPlayPause: () {},
              onSeek: (_) {},
              onLoopToggle: () {},
              onMuteToggle: mute,
              onFullscreenToggle: () {},
            );
          },
        ),
      ),
    );
    final loop = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.loop');
    final fullscreen = button('L.fullscreen');
    expect(find.bySemanticsLabel('L.mute'), findsNothing);
    expect(tester.getRect(loop).right, tester.getRect(fullscreen).left);
    final fullBefore = tester.getRect(fullscreen);
    update(() => mute = () {});
    await tester.pump();
    expect(find.bySemanticsLabel('L.mute'), findsOneWidget);
    expect(tester.getRect(button('L.mute')).left, tester.getRect(loop).right);
    expect(tester.getRect(fullscreen), fullBefore);
    update(() => mute = null);
    await tester.pump();
    expect(find.bySemanticsLabel('L.mute'), findsNothing);
    expect(tester.getRect(loop).right, tester.getRect(fullscreen).left);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('optional loop uses shared selected media button and toggled semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    var looping = false;
    var calls = 0;
    await mount(
      tester,
      view(
        StatefulBuilder(
          builder: (context, update) => FrostVideoFrame(
            video: const SizedBox.expand(),
            state: FrostVideoState(playing: false, position: Duration.zero, duration: const Duration(seconds: 12), looping: looping),
            onPlayPause: () {},
            onSeek: (_) {},
            onLoopToggle: () => update(() {
              looping = !looping;
              calls++;
            }),
          ),
        ),
      ),
    );
    final loop = find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.loop');
    expect(tester.widget<FrostButton>(loop).selected, false);
    expect(
      tester.getSemantics(loop),
      matchesSemantics(label: 'L.loop', isButton: true, hasEnabledState: true, isEnabled: true, hasToggledState: true, isToggled: false, hasTapAction: true),
    );
    await tester.tap(loop);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 180));
    expect(calls, 1);
    expect(tester.widget<FrostButton>(loop).selected, true);
    expect(tester.getSemantics(loop).flagsCollection.isToggled, Tristate.isTrue);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  testWidgets('loop control is absent for existing default callers', (tester) async {
    await mount(tester, view(video()));
    expect(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'L.loop'), findsNothing);
  });
  testWidgets('idle controls fade after 2.5s; movement restores them', (tester) async {
    await mount(tester, view(video()));
    await tester.pump(const Duration(milliseconds: 2499));
    expect(button('L.pause'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 80));
    final fade = find.descendant(of: find.byType(FrostVideoBar).first, matching: find.byType(FadeTransition));
    final ancestor = find.ancestor(of: find.byType(FrostVideoBar), matching: find.byType(FrostMaterialRevealTransition)).first;
    expect(tester.widget<FrostMaterialRevealTransition>(ancestor).opacity.value, inExclusiveRange(0, 1));
    expect(fade, findsWidgets);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FrostVideoBar), findsNothing);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(10, 10));
    await mouse.moveTo(const Offset(400, 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.byType(FrostVideoBar), findsOneWidget);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  testWidgets('control surface and gradient share the reveal without filtering beneath opacity', (tester) async {
    await mount(tester, view(video()));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 80));
    final bar = find.byType(FrostVideoBar);
    final fade = tester.widget<FrostMaterialRevealTransition>(find.ancestor(of: bar, matching: find.byType(FrostMaterialRevealTransition)).first);
    final p = fade.opacity.value;
    expect(p, inExclusiveRange(0, 1));
    expect(find.descendant(of: bar, matching: find.byType(FrostSurface)), findsNothing);
    final gradient = tester
        .widgetList<CustomPaint>(find.descendant(of: bar, matching: find.byType(CustomPaint)))
        .map((w) => w.painter)
        .whereType<FrostVideoScrimPainter>()
        .single;
    expect(gradient.color.a, closeTo(.70 * p, 1e-9));
    expect(gradient.controlOpacity, closeTo(.60 * p, 1e-9));
    expectSafeLayers(tester);
    await tester.pump(const Duration(milliseconds: 200));
    expect(bar, findsNothing);
  });

  testWidgets('paused central play has a large onMedia base and buffering is mutually exclusive', (tester) async {
    var buffering = false;
    StateSetter? update;
    await mount(
      tester,
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return video(
              state: FrostVideoState(playing: false, position: Duration.zero, duration: const Duration(seconds: 60), buffering: buffering),
            );
          },
        ),
      ),
    );
    final large = find.byWidgetPredicate((w) => w is FrostButtonControl && w.iconStyle == FrostIconButtonStyle.onMedia && w.size == FrostControlSize.large);
    expect(large, findsNothing);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(FrostVideoBar), findsOneWidget);
    update!(() => buffering = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 299));
    expect(large, findsNothing);
    expect(find.byWidgetPredicate((w) => w is FrostActivityIndicator && w.semanticLabel == 'L.loading'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.byWidgetPredicate((w) => w is FrostActivityIndicator && w.semanticLabel == 'L.loading'), findsOneWidget);
    expect(large, findsNothing);
    update!(() => buffering = false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 170));
    await tester.pump(const Duration(milliseconds: 230));
    expect(large, findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('drag previews target time and seeks only on release; buffered painter is shared', (tester) async {
    final seeks = <Duration>[];
    await mount(tester, view(video(seek: seeks.add)));
    final slider = find.byType(FrostSlider), rect = tester.getRect(slider);
    final gesture = await tester.startGesture(Offset(rect.left + rect.width * .2, rect.center.dy), kind: PointerDeviceKind.mouse);
    await gesture.moveTo(Offset(rect.left + rect.width * .6, rect.center.dy));
    await tester.pump();
    expect(seeks, isEmpty);
    final control = tester.widget<FrostSlider>(slider);
    expect(control.value, greaterThan(1000));
    final preview = control.valueLabel!(control.value);
    expect(find.byWidgetPredicate((w) => w is FrostRollingText && w.text == '$preview / 1:00:05'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(FrostVideoBar), findsOneWidget);
    final painters = tester
        .widgetList<CustomPaint>(find.descendant(of: slider, matching: find.byType(CustomPaint)))
        .map((w) => w.painter)
        .whereType<FrostProgressPainter>();
    expect(painters.single.buffered, closeTo(1800 / 3605, .0001));
    final tokens = FrostThemeTokens.of(tester.element(slider));
    expect(painters.single.ink, tokens.accent);
    expect(painters.single.track, tokens.onMediaInk.withValues(alpha: .2));
    expect(painters.single.bufferedInk, tokens.onMediaInk.withValues(alpha: .4));
    await gesture.up();
    expect(seeks, hasLength(1));
    expect(seeks.single.inSeconds, greaterThan(1000));
    expect(tester.takeException(), isNull);
  });
  for (final direction in TextDirection.values) {
    testWidgets('all shortcuts and focused slider seek once with temporal LTR $direction', (tester) async {
      var play = 0, mute = 0, full = 0;
      final seeks = <Duration>[];
      await mount(
        tester,
        view(
          video(play: () => play++, mute: () => mute++, fullscreen: () => full++, seek: seeks.add),
          direction: direction,
        ),
      );
      await tester.tapAt(const Offset(400, 250));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyM);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      expect(play, 2);
      expect(mute, 1);
      expect(full, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(seeks.last, const Duration(seconds: 70));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(seeks.last, const Duration(seconds: 60));
      await tester.tapAt(tester.getCenter(find.byType(FrostSlider)));
      seeks.clear();
      await tester.pump();
      final node = tester
          .widget<Focus>(find.descendant(of: find.byType(FrostSlider), matching: find.byWidgetPredicate((w) => w is Focus && w.focusNode != null)).first)
          .focusNode!;
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      expect(seeks, [const Duration(seconds: 70)]);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(play, 3);
      final painter = tester
          .widgetList<CustomPaint>(find.descendant(of: find.byType(FrostSlider), matching: find.byType(CustomPaint)))
          .map((w) => w.painter)
          .whereType<FrostProgressPainter>()
          .single;
      expect(painter.direction, TextDirection.ltr);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('frame focus can hide; focused controls and hovered bar stay visible', (tester) async {
    await mount(tester, view(video()));
    await tester.tapAt(const Offset(400, 250));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump(const Duration(milliseconds: 2800));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byType(FrostVideoBar), findsNothing);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    await tester.tap(button('L.mute'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(FrostVideoBar), findsOneWidget);
    FocusManager.instance.primaryFocus!.unfocus();
    await tester.pump();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: tester.getCenter(find.byType(FrostVideoBar)));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(FrostVideoBar), findsOneWidget);
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });
  testWidgets('touch background toggles controls without toggling playback', (tester) async {
    var calls = 0;
    await mount(tester, view(video(play: () => calls++)));
    await tester.tapAt(const Offset(400, 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.byType(FrostVideoBar), findsNothing);
    expect(calls, 0);
    await tester.tapAt(const Offset(400, 250));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 230));
    expect(find.byType(FrostVideoBar), findsOneWidget);
    expect(calls, 0);
  });
  testWidgets('clock boundaries normalize invalid durations and positions', (tester) async {
    await mount(
      tester,
      view(
        video(
          state: const FrostVideoState(playing: false, position: Duration(seconds: 120), duration: Duration(seconds: -1), buffered: Duration(seconds: 200)),
        ),
      ),
    );
    final slider = tester.widget<FrostSlider>(find.byType(FrostSlider));
    expect(slider.value, 0);
    expect(slider.onChanged, isNull);
    expect(find.byWidgetPredicate((w) => w is FrostRollingText && w.text == '00:00 / 00:00'), findsOneWidget);
    await tester.pumpWidget(
      view(
        video(
          state: const FrostVideoState(playing: false, position: Duration(milliseconds: 3599999), duration: Duration(seconds: 3661)),
        ),
      ),
    );
    expect(find.byWidgetPredicate((w) => w is FrostRollingText && w.text == '59:59 / 1:01:01'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('adjustable semantics use localized seek and time; shortcuts outside frame do nothing', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    final seeks = <Duration>[];
    await mount(
      tester,
      view(
        Column(
          children: [
            const Material(child: TextField()),
            Expanded(
              child: video(play: () => calls++, seek: seeks.add),
            ),
          ],
        ),
      ),
    );
    final slider = tester.getSemantics(find.byType(FrostSlider));
    expect(slider.getSemanticsData().label, 'L.seek');
    expect(slider.getSemanticsData().value, '01:05');
    expect(slider.getSemanticsData().hasAction(SemanticsAction.increase), isTrue);
    tester.binding.performSemanticsAction(SemanticsActionEvent(type: SemanticsAction.increase, viewId: tester.view.viewId, nodeId: slider.id));
    expect(seeks, [const Duration(seconds: 70)]);
    await tester.tap(find.byType(EditableText));
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    expect(calls, 0);
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets('narrow controls stay in one scrollable row and gradient protects every baseline scale=$scale', (tester) async {
      await mount(tester, view(video(), width: 300, scale: scale));
      final bar = find.byType(FrostVideoBar), slider = tester.getRect(find.byType(FrostSlider));
      final time = find.byWidgetPredicate((w) => w is FrostRollingText && w.text == '01:05 / 1:00:05');
      expect(tester.getCenter(time).dy, greaterThan(slider.center.dy));
      if (scale == 2) {
        final scroll = find.descendant(of: bar, matching: find.byType(Scrollable));
        expect(tester.state<ScrollableState>(scroll).position.maxScrollExtent, greaterThan(0));
      }
      final paints = tester
          .widgetList<CustomPaint>(find.descendant(of: bar, matching: find.byType(CustomPaint)))
          .map((w) => w.painter)
          .whereType<FrostVideoScrimPainter>();
      final mask = paints.single.color.withValues(alpha: paints.single.controlOpacity), tokens = FrostThemeTokens.of(tester.element(bar));
      final backdrop = Color.alphaBlend(mask, const Color(0xFFFFFFFF));
      expect(colorContrast(tokens.onMediaInk, backdrop), greaterThanOrEqualTo(4.5));
      expect(colorContrast(tokens.onMediaInk, Color(backdrop.toARGB32())), greaterThanOrEqualTo(4.5));
      expect(mask.a, .60);
      expect(mask.a, greaterThan(.5));
      final rect = tester.getRect(bar), text = tester.getRect(time);
      expect(text.top, greaterThanOrEqualTo(rect.top));
      expect(text.bottom, lessThanOrEqualTo(rect.bottom));
      expect(frostVideoGradientExtent, 0);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('reduced motion only fades controls and unmount cancels idle timers', (tester) async {
    await mount(tester, view(video(), reduced: true));
    await tester.pump(const Duration(milliseconds: 2500));
    await tester.pump(const Duration(milliseconds: 30));
    final bar = find.byType(FrostVideoBar);
    final scales = tester.widgetList<ScaleTransition>(find.ancestor(of: bar, matching: find.byType(ScaleTransition)));
    expect(scales, isEmpty);
    final fade = tester.widget<FrostMaterialRevealTransition>(find.ancestor(of: bar, matching: find.byType(FrostMaterialRevealTransition)).first);
    expect(fade.opacity.value, inExclusiveRange(0, 1));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });
  testWidgets('player clock updates do not postpone the idle countdown', (tester) async {
    var position = const Duration(seconds: 1);
    StateSetter? update;
    await mount(
      tester,
      view(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return video(
              state: FrostVideoState(playing: true, position: position, duration: const Duration(minutes: 2)),
            );
          },
        ),
      ),
    );
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 500));
      update!(() => position += const Duration(milliseconds: 500));
      await tester.pump();
    }
    expect(find.byType(FrostVideoBar), findsNothing);
    expect(tester.takeException(), isNull);
  });

  group('control bar on a touch device', () {
    Widget touchVideo({EdgeInsets safe = EdgeInsets.zero, Widget? frame, bool root = false}) {
      final page = MediaQuery(
        data: MediaQueryData(size: const Size(800, 600), padding: safe),
        child: Center(
          child: SizedBox(width: root ? 700 : 800, height: 600, child: frame ?? video()),
        ),
      );
      // The touch-target root reads the density from the theme, so it sits under the app.
      return frostTestApp(platform: TargetPlatform.android, root ? FrostInputFeedback(child: page) : page);
    }

    testWidgets('neighbouring buttons reach touch width without moving and a direct hit stays on its button', (tester) async {
      var mute = 0, fullscreen = 0;
      await mount(
        tester,
        touchVideo(
          frame: video(mute: () => mute++, fullscreen: () => fullscreen++),
        ),
      );
      final muteRect = tester.getRect(button('L.mute')), fullRect = tester.getRect(button('L.fullscreen'));
      expect(muteRect.width, 30);
      expect(fullRect.left, muteRect.right);
      await tester.tapAt(Offset(fullRect.left + 1, fullRect.center.dy));
      await tester.pump();
      expect((mute, fullscreen), (0, 1));
    });

    testWidgets('the very first touch beside a button reaches it, in both margins and over the track', (tester) async {
      for (final inset in [-6.0, 36.0]) {
        var plays = 0;
        await tester.pumpWidget(touchVideo(frame: video(play: () => plays++), root: true));
        final play = tester.getRect(button('L.pause'));
        await tester.tapAt(Offset(play.left + inset, play.top + 1));
        await tester.pump();
        expect(plays, 1, reason: 'inset $inset');
        await tester.pumpWidget(const SizedBox());
      }
    });

    testWidgets('the rows keep clear of the safe area and the bar still reaches the frame edge', (tester) async {
      const safe = EdgeInsets.fromLTRB(59, 47, 59, 34);
      await mount(
        tester,
        touchVideo(
          safe: safe,
          frame: FrostVideoFrame(
            video: const SizedBox.expand(),
            state: initial,
            onPlayPause: () {},
            onSeek: (_) {},
            onFullscreenToggle: () {},
            topLeading: FrostMediaButton.icon(icon: testIcons.back, label: 'Back', onPressed: () {}),
            moreActions: [FrostMenuAction('Report', onSelected: () {})],
          ),
        ),
      );
      final play = tester.getRect(button('L.pause')), full = tester.getRect(button('L.fullscreen')), back = tester.getRect(button('Back'));
      expect(play.left, greaterThanOrEqualTo(safe.left));
      expect(play.bottom, lessThanOrEqualTo(600 - safe.bottom));
      expect(full.right, lessThanOrEqualTo(800 - safe.right));
      expect(back.left, greaterThanOrEqualTo(safe.left));
      expect(back.top, greaterThanOrEqualTo(safe.top));
      expect(tester.getBottomLeft(find.byType(FrostVideoBar)).dy, 600);
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('controls hide on their own after a seek drag or a tap on the bar', (tester) async {
    const idle = Duration(seconds: 12);
    await mount(tester, view(video()));
    final sliderCenter = tester.getCenter(find.byType(FrostSlider));
    await tester.timedDragFrom(sliderCenter, const Offset(120, 0), const Duration(milliseconds: 300));
    await tester.pump();
    await tester.pump(idle);
    await tester.pumpAndSettle();
    expect(find.byType(FrostVideoBar), findsNothing, reason: 'after a drag');

    await tester.tapAt(const Offset(400, 250));
    await tester.pumpAndSettle();
    expect(find.byType(FrostVideoBar), findsOneWidget);
    await tester.tap(button('L.mute'));
    await tester.pump();
    await tester.pump(idle);
    await tester.pumpAndSettle();
    expect(find.byType(FrostVideoBar), findsNothing, reason: 'after a button tap');
    expect(tester.takeException(), isNull);
  });

  testWidgets('More appears only with something to show', (tester) async {
    final more = find.bySemanticsLabel('L.more');
    final semantics = tester.ensureSemantics();
    Widget frame(double width, {List<FrostToolbarItem> actions = const [], List<FrostMenuEntry> entries = const []}) => view(
      FrostVideoFrame(video: const SizedBox.expand(), state: initial, onPlayPause: () {}, onSeek: (_) {}, actions: actions, moreActions: entries),
      width: width,
    );
    final action = FrostToolbarItem.action(label: 'Share', icon: testIcons.add, onPressed: () {});
    await mount(tester, frame(800, actions: [action]));
    expect(find.bySemanticsLabel('Share'), findsOneWidget);
    expect(more, findsNothing);
    await tester.pumpWidget(frame(400, actions: [action]));
    await tester.pump();
    expect(more, findsOneWidget);
    await tester.pumpWidget(frame(800, entries: [FrostMenuAction('Report', onSelected: () {})]));
    await tester.pump();
    expect(more, findsOneWidget);
    await tester.pumpWidget(frame(800));
    await tester.pump();
    expect(more, findsNothing);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });
  testWidgets('controls still hide after a drag that the video ended by losing its duration', (tester) async {
    var state = initial;
    late StateSetter update;
    await mount(
      tester,
      view(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return video(state: state);
          },
        ),
      ),
    );
    final rect = tester.getRect(find.byType(FrostSlider));
    final gesture = await tester.startGesture(Offset(rect.left + rect.width * .2, rect.center.dy));
    await gesture.moveTo(Offset(rect.left + rect.width * .6, rect.center.dy));
    await tester.pump();
    update(() => state = const FrostVideoState(playing: true, position: Duration.zero, duration: Duration.zero, buffered: Duration.zero));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.byType(FrostVideoBar), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
