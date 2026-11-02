import 'dart:ui' as ui;
import 'dart:ui' show SemanticsAction;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/controls/_field_chrome.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:frost_ui/src/lists/_row_layout.dart';
import 'package:frost_ui/src/media/_video_bar.dart';

import 'support.dart';

Widget app(
  Widget child, {
  TargetPlatform platform = TargetPlatform.windows,
  double scale = 1,
  double width = 320,
  TextDirection direction = TextDirection.ltr,
}) => FrostScope(
  config: testConfig,
  child: MaterialApp(
    theme: FrostTheme.build(config: testConfig, brightness: Brightness.dark, platform: platform, locale: const Locale('en')),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Directionality(
        textDirection: direction,
        child: SingleChildScrollView(
          child: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('search entry is a subtle button, never an editor; keyboard and collapse keep its name', (tester) async {
    final semantics = tester.ensureSemantics();
    var calls = 0;
    final focus = FocusNode();
    addTearDown(focus.dispose);
    Widget entry() => FrostSearchEntry(placeholder: 'Search library', value: 'Landscape', shortcutLabel: 'Ctrl K', focusNode: focus, onPressed: () => calls++);
    await tester.pumpWidget(app(entry()));
    final node = tester.getSemantics(find.bySemanticsLabel(RegExp('Search')));
    expect(node.flagsCollection.isButton, isTrue);
    expect(node.flagsCollection.isTextField, isFalse);
    expect(node.label, contains('Landscape'));
    expect(find.byType(EditableText), findsNothing);
    expect(FrostFieldChrome.resolve(tester.element(find.byType(FrostFieldButton)), enabled: true, focused: false, invalid: false).fill.a, lessThan(1));
    await tester.tap(find.byType(FrostSearchEntry));
    focus.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    expect(calls, 2);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    expect(frostFocusRings(), findsOneWidget);
    expect(find.ancestor(of: frostFocusRings(), matching: find.byType(ClipPath)), findsNothing);
    await tester.pumpWidget(app(entry(), width: 44, scale: 3));
    await tester.pumpAndSettle();
    expect(find.text('Landscape'), findsNothing);
    expect(tester.getSemantics(find.bySemanticsLabel(RegExp('Search'))).label, contains('Landscape'));
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('disabled search has no activation and no editable semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(app(const FrostSearchEntry(placeholder: 'Search', onPressed: null)));
    expect(tester.getSemantics(find.bySemanticsLabel(RegExp('Search'))).getSemanticsData().hasAction(SemanticsAction.tap), isFalse);
    semantics.dispose();
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('natural layout $platform scale $scale', (tester) async {
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FrostSearchEntry(placeholder: 'Search for something long', shortcutLabel: 'Ctrl K', onPressed: () {}),
                FrostMediaRow(
                  media: const ColoredBox(color: Colors.white),
                  title: 'A long title that occupies at most two lines',
                  metadata: const ['Creator', 'Updated yesterday'],
                  overlay: const Text('12:48'),
                  progress: .4,
                  onPressed: () {},
                ),
                Wrap(
                  children: [
                    for (final size in FrostControlSize.values)
                      FrostTag(label: 'A label with detail', detail: '12', icon: testConfig.icons.add, size: size, onPressed: () {}),
                    const FrostTag(label: 'Topic label', style: FrostTagStyle.topic),
                  ],
                ),
                FrostListRow(title: 'Compact readable row', subtitle: FrostRowSubtitle('Natural height when text grows'), onPressed: () {}),
                SizedBox(
                  height: 340,
                  child: FrostVideoFrame(
                    video: const ColoredBox(color: Colors.white),
                    state: const FrostVideoState(playing: false, position: Duration(seconds: 30), duration: Duration(minutes: 2)),
                    onPlayPause: () {},
                    onSeek: (_) {},
                    controls: [
                      FrostMediaButton(label: 'Quality', onPressed: () {}),
                      FrostMediaButton.icon(icon: testConfig.icons.more, label: 'Settings', onPressed: () {}),
                    ],
                  ),
                ),
              ],
            ),
            platform: platform,
            scale: scale,
            width: 320,
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byType(FrostVideoBar), findsOneWidget);
      });
    }
  }

  testWidgets('media row has one action for cover and text and exposes context menu', (tester) async {
    var opens = 0, menu = 0;
    await tester.pumpWidget(
      app(
        FrostMediaRow(
          media: const ColoredBox(color: Colors.white),
          title: 'Media title',
          metadata: const ['Creator', 'History'],
          overlay: const Text('12:48'),
          progress: .5,
          onPressed: () => opens++,
          contextMenu: [FrostMenuAction('Queue', onSelected: () => menu++)],
        ),
      ),
    );
    await tester.tap(find.text('Media title'));
    await tester.tapAt(tester.getCenter(find.byType(FrostMediaCard)));
    expect(opens, 2);
    await tester.tap(find.text('Media title'), buttons: kSecondaryMouseButton);
    await tester.pumpAndSettle();
    expect(find.text('Queue'), findsOneWidget);
    await tester.tap(find.text('Queue'));
    await tester.pumpAndSettle();
    expect(menu, 1);
    expect(opens, 2);
  });

  testWidgets('pointer row paints 32, occupies and hits 36; touch keeps 44', (tester) async {
    var calls = 0;
    for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
      await tester.pumpWidget(
        app(
          FrostListRow(title: 'Row', onPressed: () => calls++),
          platform: platform,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(FrostListRow)).height, platform == TargetPlatform.windows ? 36 : 44);
      expect(tester.getSize(find.byType(FrostRowLayout)).height, platform == TargetPlatform.windows ? 32 : 44);
      await tester.tapAt(tester.getTopLeft(find.byType(FrostListRow)) + const Offset(20, 1));
    }
    expect(calls, 2);
  });

  testWidgets('video inserted controls keep their callbacks and do not toggle playback', (tester) async {
    var settings = 0, plays = 0;
    await tester.pumpWidget(
      app(
        SizedBox(
          height: 240,
          child: FrostVideoFrame(
            video: const ColoredBox(color: Colors.white),
            state: const FrostVideoState(playing: false, position: Duration.zero, duration: Duration.zero),
            onPlayPause: () => plays++,
            onSeek: (_) {},
            controls: [FrostMediaButton(label: 'Quality', onPressed: () => settings++)],
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Quality'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quality'));
    expect(settings, 1);
    expect(plays, 0);
  });

  testWidgets('media actions use glyph shadows without individual backing rectangles', (tester) async {
    await tester.pumpWidget(
      app(
        Row(
          children: [
            FrostMediaButton(label: 'Quality', onPressed: () {}),
            FrostMediaButton.icon(icon: testIcons.play, label: 'Play', onPressed: () {}),
          ],
        ),
      ),
    );
    final text = tester.widget<Text>(find.text('Quality'));
    expect(text.style!.color, Colors.white);
    expect(text.style!.shadows!.single.color.a, closeTo(.4, .001));
    expect(text.style!.shadows!.single.blurRadius, inInclusiveRange(2, 4));
    final icon = tester.element(find.byType(Icon));
    expect(IconTheme.of(icon).shadows, text.style!.shadows);
    expect(
      find.descendant(
        of: find.byType(FrostMediaButton),
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == const Color(0xC2000000),
        ),
      ),
      findsNothing,
    );
  });

  testWidgets('continuous gradient is readable over white/red with no jump at the old band edge', (tester) async {
    const painter = FrostVideoScrimPainter(Color(0xDB000000), controlOpacity: .60);
    const size = Size(200, 96);
    for (final cover in [Colors.white, const Color(0xFFFF4C65)]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(cover, BlendMode.src);
      canvas.translate(0, frostVideoGradientExtent);
      painter.paint(canvas, size);
      final picture = recorder.endRecording();
      final data = await tester.runAsync(() async {
        final image = await picture.toImage(200, 96);
        try {
          return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        } finally {
          image.dispose();
        }
      });
      final bytes = data!;
      Color pixel(int y) {
        final offset = (y * 200 + 100) * 4;
        return Color.fromARGB(bytes.getUint8(offset + 3), bytes.getUint8(offset), bytes.getUint8(offset + 1), bytes.getUint8(offset + 2));
      }

      expect((pixel(0).r - cover.r).abs(), lessThan(.02));
      expect((pixel(63).r - pixel(64).r).abs(), lessThan(.02));
      for (final y in [44, 64, 84, 95]) {
        expect(colorContrast(Colors.white, pixel(y)), greaterThanOrEqualTo(4.5));
      }
      expect(pixel(95).computeLuminance(), lessThan(pixel(64).computeLuminance()));
      picture.dispose();
    }
  });

  testWidgets('top player gradient protects every control baseline over white and bright red', (tester) async {
    const size = Size(200, 44);
    for (final cover in [Colors.white, Color(0xFFFF4C65)]) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)..drawColor(cover, BlendMode.src);
      const FrostVideoScrimPainter(Color(0xDB000000), controlOpacity: .60, top: true).paint(canvas, size);
      final picture = recorder.endRecording();
      final data = await tester.runAsync(() async {
        final image = await picture.toImage(200, 108);
        try {
          return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        } finally {
          image.dispose();
        }
      });
      Color pixel(int y) {
        final i = (y * 200 + 100) * 4;
        final b = data!;
        return Color.fromARGB(b.getUint8(i + 3), b.getUint8(i), b.getUint8(i + 1), b.getUint8(i + 2));
      }

      for (final y in [4, 20, 32, 43]) {
        expect(colorContrast(Colors.white, pixel(y)), greaterThanOrEqualTo(4.5));
      }
      expect((pixel(43).r - pixel(44).r).abs(), lessThan(.02));
      expect(pixel(107).computeLuminance(), greaterThan(pixel(44).computeLuminance()));
      picture.dispose();
    }
  });

  testWidgets('phone video keeps seek, clock and controls in one row without overlapping targets', (tester) async {
    await tester.pumpWidget(
      app(
        SizedBox(
          height: 411 * 9 / 16,
          child: FrostVideoFrame(
            video: const ColoredBox(color: Colors.white),
            state: const FrostVideoState(playing: false, position: Duration(minutes: 2, seconds: 49), duration: Duration(hours: 1, seconds: 57)),
            onPlayPause: () {},
            onSeek: (_) {},
            onMuteToggle: () {},
            onFullscreenToggle: () {},
            controls: [
              FrostMediaButton(label: 'Comments', onPressed: () {}),
              FrostMediaButton.icon(icon: testIcons.more, label: 'Settings', onPressed: () {}),
            ],
          ),
        ),
        platform: TargetPlatform.android,
        width: 411,
      ),
    );
    final bar = find.byType(FrostVideoBar);
    expect(tester.getSize(bar).height, lessThanOrEqualTo(96));
    final slider = tester.getRect(find.byType(FrostSlider));
    final actions = find.descendant(of: bar, matching: find.byType(FrostMediaButton));
    final centerY = tester.getCenter(actions.first).dy;
    for (final element in actions.evaluate()) {
      final rect = tester.getRect(find.byElementPredicate((e) => e == element));
      expect(rect.center.dy, closeTo(centerY, .01));
      expect(rect.center.dy, greaterThan(slider.center.dy));
      expect(rect.height, greaterThanOrEqualTo(44));
    }
    expect(
      find.byWidgetPredicate((w) => w is FrostButtonControl && w.iconStyle == FrostIconButtonStyle.onMedia && w.size == FrostControlSize.large),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('topics have a faint capsule and secondary ink, lighter than selectable parts', (tester) async {
    await tester.pumpWidget(
      app(
        Column(
          children: [
            FrostTag(label: 'Topic', style: FrostTagStyle.topic, onPressed: () {}),
            FrostTag(label: 'Part', onPressed: () {}),
          ],
        ),
      ),
    );
    final topic = find.byWidgetPredicate((w) => w is FrostTagButton && w.topic);
    final tokens = FrostThemeTokens.of(tester.element(topic));
    final decorations = tester
        .widgetList<DecoratedBox>(find.descendant(of: topic, matching: find.byType(DecoratedBox)))
        .map((w) => w.decoration)
        .whereType<ShapeDecoration>();
    final fill = decorations.firstWhere((d) => d.color == tokens.fillSubtle);
    expect(fill.color!.a, lessThan(tokens.fill.a));
    expect(DefaultTextStyle.of(tester.element(find.text('Topic'))).style.color, tokens.textSecondary);
    final shape = fill.shape;
    expect(shape, isA<OutlinedBorder>());
    expect(tester.widget<FrostTagButton>(topic).geometry.cornerRadius, 14);
  });

  testWidgets('search and media actions honor a disabled control scope', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      app(
        FrostControlScope(
          enabled: false,
          child: Column(
            children: [
              FrostSearchEntry(placeholder: 'Search', onPressed: () => calls++),
              FrostMediaButton(label: 'Quality', onPressed: () => calls++),
            ],
          ),
        ),
      ),
    );
    await tester.tap(find.text('Search'));
    await tester.tap(find.text('Quality'));
    expect(calls, 0);
  });

  testWidgets('touch media row opens a menu without its activation callback', (tester) async {
    var opens = 0;
    await tester.pumpWidget(
      app(
        FrostMediaRow(
          media: const ColoredBox(color: Colors.white),
          title: 'Media title',
          onPressed: () => opens++,
          contextMenu: [FrostMenuAction('Queue', onSelected: () {})],
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.longPress(find.text('Media title'));
    await tester.pumpAndSettle();
    expect(find.text('Queue'), findsOneWidget);
    expect(opens, 0);
  });

  testWidgets('media rows retain FrostList arrow and Enter activation', (tester) async {
    int? opened;
    await tester.pumpWidget(
      app(
        SizedBox(
          height: 220,
          child: FrostList<int>(
            items: const [1, 2],
            itemBuilder: (_, item, _) => FrostMediaRow(
              media: const ColoredBox(color: Colors.white),
              title: 'Media $item',
              onPressed: () => opened = item,
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(opened, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('live video slots retain identity in the single scrollable row', (tester) async {
    late StateSetter resize;
    var width = 700.0;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, set) {
            resize = set;
            return Center(
              child: SizedBox(
                width: width,
                height: 300,
                child: FrostVideoFrame(
                  video: const ColoredBox(color: Colors.white),
                  state: const FrostVideoState(playing: false, position: Duration.zero, duration: Duration(minutes: 10)),
                  onPlayPause: () {},
                  onSeek: (_) {},
                  controls: [FrostMediaButton(label: 'Quality', onPressed: () {})],
                ),
              ),
            );
          },
        ),
        width: 700,
      ),
    );
    final element = tester.element(find.byType(FrostMediaButton).last);
    final wide = tester.getSize(find.byType(FrostVideoBar)).height;
    resize(() => width = 220);
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(FrostVideoBar)).height, wide);
    expect(identical(tester.element(find.byType(FrostMediaButton).last), element), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('touching custom controls holds the bar and restarts idle after release', (tester) async {
    await tester.pumpWidget(
      app(
        SizedBox(
          height: 300,
          child: FrostVideoFrame(
            video: const ColoredBox(color: Colors.white),
            state: const FrostVideoState(playing: true, position: Duration.zero, duration: Duration(minutes: 10)),
            onPlayPause: () {},
            onSeek: (_) {},
            controls: [FrostMediaButton(label: 'Quality', onPressed: () {})],
          ),
        ),
        platform: TargetPlatform.android,
      ),
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.ensureVisible(find.text('Quality'));
    await tester.pump();
    final press = await tester.startGesture(tester.getCenter(find.text('Quality')), kind: PointerDeviceKind.touch);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byType(FrostVideoBar), findsOneWidget);
    await press.up();
    await tester.pump(const Duration(milliseconds: 2499));
    expect(find.byType(FrostVideoBar), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(FrostVideoBar), findsNothing);
  });
}
