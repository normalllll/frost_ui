import 'dart:ui' show Tristate, ImageByteFormat;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_field_chrome.dart';
import 'package:frost_ui/src/controls/_field_frame.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:frost_ui/src/primitives/_text_selection_chrome.dart';

import 'support.dart';

Widget app(
  Widget child, {
  Brightness brightness = Brightness.light,
  FrostTone tone = FrostTone.neutral,
  double scale = 1,
  TargetPlatform platform = TargetPlatform.windows,
}) => FrostScope(
  config: testConfig,
  child: MaterialApp(
    theme: FrostTheme.build(config: testConfig, brightness: brightness, tone: tone, platform: platform, locale: const Locale('en')),
    home: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(scale)),
      child: Center(child: SizedBox(width: 320, child: child)),
    ),
  ),
);

void main() {
  testWidgets('ordinary surfaces preserve field scopes and the search subtle default', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    for (final inherited in [null, FrostFieldAppearance.subtle]) {
      Widget content = FrostSurface(
        role: FrostSurfaceRole.panel,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
            if (inherited != null) const FrostTextField(placeholder: 'Inherited'),
          ],
        ),
      );
      if (inherited != null) content = FrostFieldScope(appearance: inherited, child: content);
      await tester.pumpWidget(app(content));
      await tester.pumpAndSettle();
      for (final frame in tester.elementList(find.byType(FrostFieldFrame))) {
        final chrome = FrostFieldChrome.resolve(frame, enabled: true, focused: false, invalid: false);
        expect(chrome.fill.a, lessThan(1));
        expect((chrome.edge.shape as OutlinedBorder).side.color.a, 0);
      }
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('refresh header keeps its extent and paints its own dots', (tester) async {
    await tester.pumpWidget(app(const Center(child: FrostRefreshDots())));
    expect(tester.getSize(find.byType(FrostRefreshDots)), const Size(24, 18));
    expect(tester.getSemantics(find.byType(FrostRefreshDots)).label, isNotEmpty);
    expect(tester.takeException(), isNull);
  });
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final size in FrostControlSize.values) {
      testWidgets('tab visuals and padding targets $platform $size', (tester) async {
        final c = FrostTabController(length: 2, vsync: tester);
        addTearDown(c.dispose);
        await tester.pumpWidget(
          app(
            FrostTabBar(
              controller: c,
              size: size,
              showDivider: false,
              tabs: const [
                FrostTab(label: 'One'),
                FrostTab(label: 'Two'),
              ],
            ),
            platform: platform,
          ),
        );
        final touch = platform == TargetPlatform.android;
        final visualHeight = size.visualHeight(touch: touch);
        final minimum = FrostControlSize.minimumHitHeight(touch: touch);
        final expected = visualHeight > minimum ? visualHeight : minimum;
        final bar = tester.getRect(find.byType(FrostTabBar));
        expect(bar.height, expected);
        final target = tester.getRect(find.text('Two'));
        await tester.tapAt(Offset(target.center.dx, bar.top + 1));
        await tester.pumpAndSettle();
        expect(c.index, 1, reason: 'Transparent padding must activate the tab');
        expect(tester.takeException(), isNull);
      });
    }
  }
  for (final brightness in Brightness.values) {
    for (final tone in FrostTone.values) {
      testWidgets('field appearances and bright-media readability $brightness $tone', (tester) async {
        for (final scale in [1.0, 2.0, 3.0]) {
          for (final appearance in FrostFieldAppearance.values) {
            await tester.pumpWidget(
              app(
                FrostTextField(appearance: appearance, label: 'Name', help: 'Required information', placeholder: 'Input'),
                brightness: brightness,
                tone: tone,
                scale: scale,
              ),
            );
            await tester.pumpAndSettle();
            final field = find.byType(FrostFieldFrame), context = tester.element(field);
            final t = FrostThemeTokens.of(context);
            final chrome = FrostFieldChrome.resolve(context, enabled: true, focused: false, invalid: false);
            if (appearance == FrostFieldAppearance.subtle) {
              expect((chrome.edge.shape as OutlinedBorder).side.color.a, 0);
              expect(chrome.fill.a, lessThan(t.fill.a));
            } else if (appearance == FrostFieldAppearance.onMedia) {
              expect(chrome.fill.a, closeTo(.76, .001));
              for (final focused in [false, true]) {
                final active = FrostFieldChrome.resolve(context, enabled: true, focused: focused, invalid: false);
                final brightest = Color.alphaBlend(active.fill, Colors.white);
                expect(colorContrast(t.textPrimary, brightest), greaterThanOrEqualTo(4.5));
                expect(colorContrast(Color.alphaBlend(t.textSecondary, brightest), brightest), greaterThanOrEqualTo(4.5));
              }
              expect(tester.widget<TextField>(find.byType(TextField)).style!.color, Colors.white);
              // Outside-the-editor labels also own a media-safe backing.
              expect(find.descendant(of: find.byType(FrostFieldScope), matching: find.byType(DecoratedBox)), findsWidgets);
            } else {
              expect(chrome.fill.a, 1);
              expect((chrome.edge.shape as OutlinedBorder).side.width, 1);
            }
            final editor = tester.widget<TextField>(find.byType(TextField));
            expect(editor.decoration!.border, InputBorder.none);
            expect(editor.selectionControls, desktopTextSelectionControls);
            expect(editor.contextMenuBuilder, frostTextSelectionMenu);
            expect(tester.takeException(), isNull, reason: '$appearance at $scale');
          }
        }
      });

      testWidgets('solid brand badge retains accent and destructive tinted text remains readable $brightness $tone', (tester) async {
        await tester.pumpWidget(
          app(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const FrostBadge(label: 'Live', tone: FrostBadgeTone.accent, style: FrostBadgeStyle.solid, textRole: FrostTextRole.callout),
                FrostButton.tinted(label: 'Delete', role: FrostButtonRole.destructive, onPressed: () {}),
              ],
            ),
            brightness: brightness,
            tone: tone,
          ),
        );
        await tester.pumpAndSettle();
        final badge = find.byType(FrostBadge), t = FrostThemeTokens.of(tester.element(badge));
        final paints = tester
            .renderObjectList<RenderDecoratedBox>(find.descendant(of: badge, matching: find.byType(DecoratedBox)))
            .map((box) => box.decoration)
            .whereType<ShapeDecoration>();
        final fill = paints.firstWhere((d) => d.color != null).color!;
        expect(fill, t.accent);
        final live = tester.renderObject<RenderParagraph>(find.text('Live'));
        expect(live.text.style!.color, Colors.white);
        expect(live.text.style!.fontSize, 11);
        final button = find.byType(FrostButton), ink = tester.renderObject<RenderParagraph>(find.text('Delete')).text.style!.color!;
        final bg = Color.alphaBlend(t.negativeTint, t.surface);
        expect(colorContrast(ink, bg), greaterThanOrEqualTo(4.5));
        expect(tester.getSemantics(button).getSemanticsData().flagsCollection.isButton, true);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('selected and pill buttons keep toggle semantics and ordinary type size', (tester) async {
    var selected = false;
    late StateSetter set;
    await tester.pumpWidget(
      app(
        StatefulBuilder(
          builder: (context, update) {
            set = update;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FrostButton(label: 'Select', selected: selected, shape: FrostButtonShape.pill, onPressed: () => set(() => selected = !selected)),
                FrostButton.quiet(label: 'Quiet', onPressed: () {}),
                FrostButton.outlined(label: 'Ordinary', onPressed: () {}),
              ],
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('Select'));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.byWidgetPredicate((w) => w is FrostButton && w.label == 'Select')).getSemanticsData().flagsCollection.isToggled,
      Tristate.isTrue,
    );
    final size = tester.renderObject<RenderParagraph>(find.text('Quiet')).text.style!.fontSize;
    expect(size, tester.renderObject<RenderParagraph>(find.text('Ordinary')).text.style!.fontSize);
    expect(
      tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).map((w) => w.decoration).whereType<ShapeDecoration>().any((d) => d.shape is StadiumBorder),
      true,
    );
    expect(tester.takeException(), isNull);
  });

  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('Frost tabs fit complete secondary labels and follow controller $direction $scale', (tester) async {
        final c = FrostTabController(length: 3, vsync: tester);
        addTearDown(c.dispose);
        await tester.pumpWidget(
          app(
            Directionality(
              textDirection: direction,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FrostTabBar(
                    controller: c,
                    showDivider: false,
                    size: FrostControlSize.compact,
                    tabs: const [
                      FrostTab(label: 'Overview'),
                      FrostTab(label: 'Comments', secondaryLabel: '12k'),
                      FrostTab(label: 'Details'),
                    ],
                  ),
                  SizedBox(
                    height: 160,
                    child: FrostTabView(controller: c, children: const [Text('Page one'), Text('Page two'), Text('Page three')]),
                  ),
                ],
              ),
            ),
            scale: scale,
          ),
        );
        expect(find.byType(TabBar), findsNothing);
        await tester.ensureVisible(find.text('Comments'));
        await tester.tap(find.text('Comments'));
        await tester.pumpAndSettle();
        expect(c.index, 1);
        expect(tester.renderObject<RenderParagraph>(find.text('Comments')).didExceedMaxLines, false);
        expect(tester.renderObject<RenderParagraph>(find.text('12k')).didExceedMaxLines, false);
        await tester.sendKeyEvent(direction == TextDirection.ltr ? LogicalKeyboardKey.arrowRight : LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(c.index, 2);
        c.index = 0;
        await tester.pumpAndSettle();
        await tester.drag(find.byType(FrostTabView), Offset(direction == TextDirection.ltr ? -280 : 280, 0));
        await tester.pumpAndSettle();
        expect(c.index, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('local media capsule protects text on a white cover and clamps watched progress', (tester) async {
    final capture = GlobalKey();
    await tester.pumpWidget(
      app(
        RepaintBoundary(
          key: capture,
          child: const FrostMediaCard(
            aspectRatio: 16 / 9,
            media: ColoredBox(color: Colors.white),
            overlay: Text('Playback 100k'),
            progress: 1.2,
          ),
        ),
        scale: 3,
      ),
    );
    final text = tester.renderObject<RenderParagraph>(find.text('Playback 100k'));
    expect(text.text.style!.color, Colors.white);
    expect(text.didExceedMaxLines, false);
    final boundary = capture.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
    final pixels = (await tester.runAsync(() => image.toByteData(format: ImageByteFormat.rawRgba)))!;
    final textTop = text.localToGlobal(Offset.zero, ancestor: boundary).dy.ceil();
    final textStart = text.localToGlobal(Offset.zero, ancestor: boundary).dx.floor();
    Color backgroundAt(int x, int y) {
      final offset = (y * image.width + x) * 4;
      return Color.fromARGB(255, pixels.getUint8(offset), pixels.getUint8(offset + 1), pixels.getUint8(offset + 2));
    }

    expect(colorContrast(Colors.white, backgroundAt(textStart - 2, textTop + text.size.height ~/ 2)), greaterThanOrEqualTo(4.5));
    expect(backgroundAt(4, 60), Colors.white, reason: 'Artwork above the lower gradient stays unshaded');
    image.dispose();
    expect(find.bySemanticsLabel('100%'), findsNothing); // progress is a value, not a duplicate label.
    final fractions = tester.widgetList<FractionallySizedBox>(find.byType(FractionallySizedBox));
    expect(fractions.any((w) => w.widthFactor == 1), true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('media field menus and nested standard fields restore page ink', (tester) async {
    late Color pageInk;
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) {
            pageInk = FrostThemeTokens.of(context).textPrimary;
            return FrostFieldScope(
              appearance: FrostFieldAppearance.onMedia,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const FrostTextField(appearance: FrostFieldAppearance.standard, placeholder: 'Normal'),
                  SizedBox(
                    height: 160,
                    child: Builder(
                      builder: (context) => frostSelectionMenu(context, const TextSelectionToolbarAnchors(primaryAnchor: Offset(100, 60)), [
                        ContextMenuButtonItem(type: ContextMenuButtonType.copy, onPressed: () {}),
                      ]),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    final editor = tester.widget<TextField>(find.byType(TextField));
    expect(editor.style!.color, pageInk);
    expect(tester.renderObject<RenderParagraph>(find.text('Copy')).text.style!.color, isNot(Colors.white));
    expect(tester.takeException(), isNull);
  });

  testWidgets('page header upgrades a semantic title without enlarging its actions', (tester) async {
    await tester.pumpWidget(
      app(
        FrostPageHeader(
          title: const FrostText('Page title'),
          actions: [FrostToolbarItem.action(icon: testIcons.info, label: 'Action', onPressed: () {})],
        ),
      ),
    );
    final title = tester.renderObject<RenderParagraph>(find.text('Page title'));
    expect(title.text.style!.fontSize, FrostTypography.of(tester.element(find.text('Page title'))).style(FrostTextRole.title1).fontSize);
    expect(tester.takeException(), isNull);
  });
}
