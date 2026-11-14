import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/foundation/color_math.dart' show colorContrast;
import 'package:frost_ui/src/media/_cover_scrim.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/motion/page_transition.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

void main() {
  testWidgets('pointer DrillIn decelerates, clears outgoing detail early, and preserves media Hero geometry', (tester) async {
    final incoming = AnimationController(vsync: tester, duration: FrostMotion.page);
    final outgoing = AnimationController(vsync: tester, duration: FrostMotion.page);
    addTearDown(incoming.dispose);
    addTearDown(outgoing.dispose);
    Future<void> show({bool media = false, bool reduced = false}) => tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
            child: Builder(
              builder: (context) => frostOwnedPageTransition(context, incoming, outgoing, const SizedBox.expand(key: ValueKey('route-child')), media: media),
            ),
          ),
        ),
      ),
    );
    double scale() => tester.widget<Transform>(find.byType(Transform).last).transform.storage[0];
    double opacity() => tester
        .widget<FrostMaterialReveal>(find.ancestor(of: find.byKey(const ValueKey('route-child')), matching: find.byType(FrostMaterialReveal)).first)
        .opacity;
    await show();
    expect(scale(), .96);
    incoming.value = .5;
    await tester.pump();
    expect(scale(), closeTo(.995, .00001));
    expect(opacity(), closeTo(.875, .001));
    incoming.value = 1;
    outgoing.value = .25;
    await tester.pump();
    expect(opacity(), closeTo(.125, .001));
    expect(scale(), inExclusiveRange(1, 1.02));
    outgoing.value = .5;
    await tester.pump();
    expect(opacity(), 0);
    await show(reduced: true);
    expect(scale(), 1);
    expect(opacity(), .5);
    incoming.value = .5;
    outgoing.value = 0;
    await show(media: true);
    final mediaReveal = find.ancestor(of: find.byKey(const ValueKey('route-child')), matching: find.byType(FrostMaterialReveal)).first;
    expect(find.descendant(of: mediaReveal, matching: find.byType(Transform)), findsNothing);
    expect(shownContent(tester, find.byKey(const ValueKey('route-child'))), 0, reason: 'midway, a media page is still under its backdrop veil');
    expect(tester.takeException(), isNull);
  });

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('reduced page duration follows pointer capability: $platform', (tester) async {
      late BuildContext context;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (value) {
              context = value;
              return const SizedBox();
            },
          ),
          platform: platform,
        ),
      );
      final theme = FrostTheme.build(config: testConfig, brightness: Brightness.dark, platform: platform, locale: const Locale('en'), reducedMotion: true);
      final builder = theme.pageTransitionsTheme.builders[platform]!;
      expect(builder.transitionDuration, platform == TargetPlatform.windows ? const Duration(milliseconds: 100) : Duration.zero);
      expect(builder.reverseTransitionDuration, builder.transitionDuration);
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (value) => MediaQuery(
              data: MediaQuery.of(value).copyWith(disableAnimations: true),
              child: Builder(
                builder: (value) {
                  context = value;
                  return const SizedBox();
                },
              ),
            ),
          ),
          platform: platform,
        ),
      );
      final route = const FrostDetailPage(child: SizedBox()).createRoute(context) as PageRoute;
      expect(route.transitionDuration, platform == TargetPlatform.windows ? const Duration(milliseconds: 100) : Duration.zero);
      route.dispose();
    });
  }

  for (final solid in [false, true]) {
    testWidgets('cover gradient preserves upper artwork and readable lower ink solid=$solid', (tester) async {
      final capture = GlobalKey();
      await tester.pumpWidget(
        frostTestApp(
          FrostScope(
            reduceTransparency: solid,
            child: Align(
              alignment: Alignment.topLeft,
              child: RepaintBoundary(
                key: capture,
                child: const SizedBox(
                  width: 300,
                  child: FrostMediaCard(
                    aspectRatio: 2,
                    media: ColoredBox(color: Colors.white),
                    overlay: SizedBox(height: 17),
                    progress: .25,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.widgetList<CustomPaint>(find.byType(CustomPaint)).where((w) => w.painter is FrostCoverScrim), hasLength(1));
      await tester.runAsync(() async {
        final image = await (capture.currentContext!.findRenderObject()! as RenderRepaintBoundary).toImage();
        final pixels = (await image.toByteData())!.buffer.asUint8List();
        Color pixel(int x, int y) {
          final i = (y * image.width + x) * 4;
          return Color.fromARGB(pixels[i + 3], pixels[i], pixels[i + 1], pixels[i + 2]);
        }

        expect(pixel(150, 80), Colors.white, reason: 'Artwork above the lower 42% is unchanged');
        expect(colorContrast(Colors.white, pixel(150, 130)), greaterThanOrEqualTo(4.5));
        expect(pixel(150, 145).r, lessThan(pixel(150, 130).r), reason: 'The gradient continues smoothly to its 62% lower stop');
        image.dispose();
      });
      expect(tester.takeException(), isNull);
    });
  }
  test('App body and numeric families stay independent, including regional fallbacks', () {
    const fonts = FrostFonts(body: 'Body', numeric: 'Numbers');
    expect(fonts.resolve(platform: TargetPlatform.windows, locale: const Locale('zh', 'CN')).family, 'Body');
    final type = FrostTypography(
      platform: TargetPlatform.windows,
      base: const TextStyle(fontFamily: 'Body'),
      numeric: 'Numbers',
    );
    expect(type.style(FrostTextRole.body).fontFamily, 'Body');
    expect(type.style(FrostTextRole.footnote, numeric: true).fontFamily, 'Numbers');
    expect(type.style(FrostTextRole.footnote, numeric: true).fontFeatures, contains(const FontFeature.tabularFigures()));
    expect(
      FrostTypography(
        platform: TargetPlatform.windows,
        base: const TextStyle(fontFamily: 'Body'),
      ).style(FrostTextRole.footnote, numeric: true).fontFamily,
      'Body',
    );
    expect(const FrostFonts(body: 'Body', japanese: 'JP').resolve(platform: TargetPlatform.windows, locale: const Locale('ja')).family, 'JP');
  });
  test('all normal, selected and semantic text inks meet 4.5 after 8-bit compositing', () {
    for (final brightness in Brightness.values) {
      for (final tone in FrostTone.values) {
        final t = FrostPalettes.pink.palette(brightness, tone, FrostPalettes.pink.defaultAccent(brightness));
        final surfaces = [t.canvas, t.surface, t.surfaceRaised, t.surfaceInset, t.surfaceMuted, t.surfaceTint, t.hoverSurface, t.pressedSurface];
        for (final base in surfaces) {
          for (final ink in [t.textPrimary, t.textSecondary, t.textTertiary]) {
            expect(colorContrast(Color(Color.alphaBlend(ink, base).toARGB32()), base), greaterThanOrEqualTo(4.5));
          }
          for (final (ink, fill) in [
            (t.selectionInk, t.selectionFill),
            (t.positiveInk, t.positiveTint),
            (t.cautionInk, t.cautionTint),
            (t.negativeInk, t.negativeTint),
            (t.infoInk, t.infoTint),
          ]) {
            final background = Color(Color.alphaBlend(fill, base).toARGB32());
            expect(colorContrast(ink, background), greaterThanOrEqualTo(4.5), reason: '$brightness $tone $ink on $background');
          }
        }
      }
    }
  });
  testWidgets('standard media metadata inherits the shared small tertiary style', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 300,
            child: FrostMediaCard(
              aspectRatio: 16 / 9,
              media: ColoredBox(color: Colors.white),
              title: 'Standard card title',
              metadata: Text('Metadata'),
            ),
          ),
        ),
      ),
    );
    final paragraph = tester.renderObject<RenderParagraph>(find.text('Metadata'));
    expect(paragraph.text.style!.fontSize, 12);
    expect(paragraph.text.style!.color, FrostThemeTokens.of(tester.element(find.text('Metadata'))).textTertiary);
    expect(tester.takeException(), isNull);
  });
}
