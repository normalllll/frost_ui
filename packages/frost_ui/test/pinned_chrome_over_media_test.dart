import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/back_to_first_button.dart';
import 'package:frost_ui/src/navigation/toolbar_menu_button.dart' show FrostToolbarControl;
import 'package:frost_ui/src/primitives/_click_feedback.dart' show FrostInteractionDecoration;
import 'package:frost_ui/src/primitives/_on_media_chrome_scope.dart' show FrostChromeOverMedia;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

final ValueListenable<({int index, int sequence})> _reselection = ValueNotifier((index: 0, sequence: 0));
void _noop() {}

void main() {
  void viewport(WidgetTester tester) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
  }

  Widget page(
    ScrollController scroll, {
    bool overMedia = true,
    Brightness brightness = Brightness.light,
    TargetPlatform platform = TargetPlatform.android,
    Widget? middle,
  }) => frostTestApp(
    brightness: brightness,
    platform: platform,
    FrostShellNavigationScope(
      ownsBackControl: false,
      canGoBack: true,
      goBack: _noop,
      primaryReselection: _reselection,
      routeDepth: 2,
      backToFirst: FrostShellBackToFirst(label: 'Back to first', icon: testIcons.add, onPressed: _noop),
      child: FrostPinnedChrome(
        overMedia: overMedia,
        chrome: FrostPageHeader(
          title: const FrostText('Name'),
          middle: middle,
          actions: [
            FrostToolbarItem.action(icon: testIcons.add, label: 'More', onPressed: _noop),
            FrostToolbarItem.action(icon: testIcons.refresh, label: 'Refresh', showsLabel: true, onPressed: _noop),
          ],
        ),
        body: CustomScrollView(
          controller: scroll,
          slivers: const [
            FrostChromeSpacer(),
            SliverToBoxAdapter(child: SizedBox(height: 2000)),
          ],
        ),
      ),
    ),
  );

  Finder paint(Finder button) => find.descendant(of: button, matching: find.byType(FrostInteractionDecoration)).first;
  ShapeDecoration plate(WidgetTester tester, Finder button) => tester.widget<FrostInteractionDecoration>(paint(button)).decoration as ShapeDecoration;
  Color? ink(WidgetTester tester, Finder button) => IconTheme.of(tester.element(find.descendant(of: button, matching: find.byType(FrostIcon)).first)).color;
  final back = find.byType(FrostCompactBackButton), first = find.byType(FrostBackToFirstButton);
  Finder action(String label) => find.byWidgetPredicate((w) => w is FrostToolbarControl && w.label == label).first;

  Future<ScrollController> shown(WidgetTester tester, {bool overMedia = true, Brightness brightness = Brightness.light, TargetPlatform platform = TargetPlatform.android}) async {
    viewport(tester);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(page(scroll, overMedia: overMedia, brightness: brightness, platform: platform));
    await tester.pumpAndSettle();
    return scroll;
  }

  void expectMedia(WidgetTester tester, Finder button) {
    final tokens = FrostThemeTokens.of(tester.element(button));
    expect(plate(tester, button).shape, isA<CircleBorder>());
    expect(plate(tester, button).color, tokens.onMediaScrim);
    expect(ink(tester, button), tokens.onMediaInk);
    final size = tester.getSize(paint(button));
    expect(size.width, size.height);
  }

  void expectOrdinary(WidgetTester tester, Finder button) {
    final tokens = FrostThemeTokens.of(tester.element(button));
    expect(plate(tester, button).shape, isNot(isA<CircleBorder>()));
    expect(plate(tester, button).color!.a, 0);
    expect(ink(tester, button), tokens.textPrimary);
  }

  testWidgets('declared over media, icon buttons paint as media circles', (tester) async {
    await shown(tester);
    expectMedia(tester, back);
    expectMedia(tester, first);
    expectMedia(tester, action('More'));
  });

  testWidgets('undeclared chrome keeps ordinary buttons', (tester) async {
    await shown(tester, overMedia: false);
    expectOrdinary(tester, back);
    expectOrdinary(tester, first);
    expectOrdinary(tester, action('More'));
  });

  for (final platform in [TargetPlatform.android, TargetPlatform.windows]) {
    testWidgets('full glass restores ordinary paint without moving or rebuilding, $platform', (tester) async {
      final scroll = await shown(tester, platform: platform);
      final element = tester.element(back), rect = tester.getRect(paint(back)), firstRect = tester.getRect(paint(first)), moreRect = tester.getRect(paint(action('More')));
      final state = tester.state(paint(back));

      scroll.jumpTo(12);
      await tester.pumpAndSettle();
      expectMedia(tester, back);

      scroll.jumpTo(24);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final midway = (tester.widget<DecoratedBox>(find.descendant(of: paint(back), matching: find.byType(DecoratedBox)).first).decoration as ShapeDecoration).color!.a;
      final scrim = FrostThemeTokens.of(tester.element(back)).onMediaScrim.a;
      expect(midway, inExclusiveRange(0, scrim));
      await tester.pumpAndSettle();

      expectOrdinary(tester, back);
      expectOrdinary(tester, first);
      expectOrdinary(tester, action('More'));
      expect(tester.element(back), same(element));
      expect(tester.state(paint(back)), same(state));
      expect(tester.getRect(paint(back)).center, rect.center);
      expect(tester.getRect(paint(first)).center, firstRect.center);
      expect(tester.getRect(paint(action('More'))).center, moreRect.center);

      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      expectMedia(tester, back);
    });
  }

  for (final brightness in Brightness.values) {
    testWidgets('media buttons stay readable on white and black media, $brightness', (tester) async {
      await shown(tester, brightness: brightness);
      final decoration = plate(tester, back), foreground = ink(tester, back)!;
      for (final media in [Colors.white, Colors.black]) {
        final background = Color.alphaBlend(decoration.color!, media);
        final (a, b) = (foreground.computeLuminance(), background.computeLuminance());
        final contrast = (a > b ? a + .05 : b + .05) / (a > b ? b + .05 : a + .05);
        expect(contrast, greaterThanOrEqualTo(4.5), reason: '$media');
      }
    });
  }

  testWidgets('text and a search field in the chrome keep their ordinary look', (tester) async {
    await shown(tester);
    final tokens = FrostThemeTokens.of(tester.element(back));
    expect(DefaultTextStyle.of(tester.element(find.text('Name'))).style.color ?? tester.widget<Text>(find.text('Name')).style?.color, isNot(tokens.onMediaInk));
    expect(plate(tester, action('Refresh')).shape, isNot(isA<CircleBorder>()));

    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    bool? activeInField;
    await tester.pumpWidget(
      page(
        scroll,
        middle: Builder(
          builder: (context) {
            activeInField = FrostChromeOverMedia.activeOf(context);
            return const SizedBox(height: 32);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(activeInField, isFalse);
  });
}
