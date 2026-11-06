import 'dart:async';

import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/primitives/_on_media_chrome_scope.dart' show FrostMediaControlsScope, FrostOnMediaChromeScope, frostWithoutOnMediaChrome;

import 'shell_placement_layers_test.dart' show presentation, destinations, viewport;
import 'support.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('a surfaced player menu restores page action ink and fill: $brightness', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          FrostMediaControlsScope(
            child: FrostOnMediaChromeScope(
              child: frostWithoutOnMediaChrome(FrostButton(label: 'Page action', onPressed: () {})),
            ),
          ),
          brightness: brightness,
        ),
      );
      final label = find.text('Page action');
      final tokens = FrostThemeTokens.of(tester.element(label));
      expect(DefaultTextStyle.of(tester.element(label)).style.color, tokens.textPrimary);
      final fills = tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).map((w) => w.decoration).whereType<ShapeDecoration>();
      expect(fills.any((d) => d.color == tokens.fill), isTrue);
      expect(tester.takeException(), isNull);
    });
  }
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('caption tabs use a labelled 24px App icon and shared gaps: $platform', (tester) async {
      final semantics = tester.ensureSemantics();
      viewport(tester, const Size(1366, 1024));
      final tabs = FrostTabsController<String>(initial: 'A')..open('B', activate: false);
      addTearDown(tabs.dispose);
      Widget app() => frostTestApp(
        FrostShell(
          destinations: destinations,
          selectedIndex: 0,
          atDestinationRoot: true,
          canGoBack: false,
          onBack: () {},
          onDestinationSelected: (_) {},
          showsMobileNavigation: true,
          tabs: presentation(tabs),
          brand: const FrostShellBrand(
            expanded: Text('App full title'),
            label: 'App spoken name',
            icon: SizedBox.square(dimension: 24, key: ValueKey('app-icon')),
          ),
          child: const FrostShellDestination(child: SizedBox.expand()),
        ),
        platform: platform,
      );
      for (final width in [1366.0, 960.0]) {
        tester.view.physicalSize = Size(width, 600);
        await tester.pumpWidget(app());
        await tester.pumpAndSettle();
        expect(find.text('App full title'), findsNothing);
        expect(find.bySemanticsLabel('App spoken name'), findsOneWidget);
        final icon = tester.getRect(find.byKey(const ValueKey('app-icon')));
        final back = tester.getRect(find.byKey(const ValueKey('frost-shell-back')));
        final firstTab = tester.getRect(find.ancestor(of: find.text('A'), matching: find.byType(Positioned)).first);
        expect(icon.size, const Size.square(24));
        expect(icon.left - back.right, FrostGap.related);
        expect(firstTab.left - icon.right, FrostGap.related);
      }
      tabs.close(1);
      await tester.pumpAndSettle();
      expect(find.text('App full title'), findsOneWidget);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('retained tabs switch on the first frame without rebuilding pages', (tester) async {
    final tabs = FrostTabsController<String>(initial: 'A')..open('B', activate: false);
    addTearDown(tabs.dispose);
    final builds = <String, int>{};
    late StateSetter updateParent;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            updateParent = set;
            return FrostTabHost<String>(
              controller: tabs,
              builder: (_, tab) {
                builds.update(tab, (v) => v + 1, ifAbsent: () => 1);
                return Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRect(
                      child: BackdropFilter(
                        key: ValueKey('glass-$tab'),
                        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                        child: const ColoredBox(color: Color(0x11777777)),
                      ),
                    ),
                    Center(child: Text(tab, key: ValueKey(tab))),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
    expect(builds, {'A': 1});
    tabs.activate(1);
    await tester.pump();
    expect(find.text('B'), findsOneWidget);
    expect(find.text('A'), findsNothing);
    final page = tester.element(find.byKey(const ValueKey('B')));
    final glass = tester.renderObject<RenderBackdropFilter>(find.byKey(const ValueKey('glass-B')));
    final retainedLayer = glass.debugLayer;
    for (var i = 0; i < 8; i++) {
      tabs.activate(i.isEven ? 0 : 1);
      updateParent(() {});
      await tester.pump();
      expect(find.text(i.isEven ? 'A' : 'B'), findsOneWidget);
    }
    expect(builds, {'A': 1, 'B': 1});
    expect(tester.element(find.byKey(const ValueKey('B'))), same(page));
    expect(glass.debugLayer, same(retainedLayer), reason: 'Switching keeps the existing blur layer rather than recreating its reveal/filter.');
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('tab swaps and destination changes show the target fully on their first frame', (tester) async {
    viewport(tester, const Size(1147, 717));
    final tabs = FrostTabsController<String>(initial: 'A')..open('B', activate: false);
    addTearDown(tabs.dispose);
    var aDestination = 0, bDestination = 1;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return ListenableBuilder(
              listenable: tabs,
              builder: (_, _) => FrostShell(
                destinations: destinations,
                selectedIndex: tabs.active == 'A' ? aDestination : bDestination,
                atDestinationRoot: true,
                onDestinationSelected: (_) {},
                canGoBack: false,
                onBack: () {},
                showsMobileNavigation: true,
                tabs: presentation(tabs),
                child: FrostTabHost<String>(
                  controller: tabs,
                  builder: (_, tab) =>
                      ColoredBox(key: ValueKey('page-$tab'), color: tab == 'A' ? const Color(0xFFCC2200) : const Color(0xFF0044CC), child: Text(tab)),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => aDestination = 1);
    await tester.pump();
    tabs.activate(1);
    await tester.pump();
    final page = find.byKey(const ValueKey('page-B'));
    final reveals = find.ancestor(of: page, matching: find.byType(FrostMaterialRevealTransition));
    expect(reveals, findsWidgets);
    for (final element in reveals.evaluate()) {
      expect(
        (element.widget as FrostMaterialRevealTransition).opacity.value,
        1,
        reason: 'The first target frame must be fully visible, including the outer Shell.',
      );
    }
    update(() => bDestination = 2);
    await tester.pump();
    expect(
      reveals.evaluate().every((e) => (e.widget as FrostMaterialRevealTransition).opacity.value == 1),
      isTrue,
      reason: 'A destination change has no motion of its own.',
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final same in [false, true]) {
    testWidgets('selecting a destination removes pushed pages on the same frame: same=$same', (tester) async {
      viewport(tester, const Size(1147, 717));
      late BuildContext pageContext;
      final selections = <int>[];
      await tester.pumpWidget(
        frostTestApp(
          FrostShell(
            destinations: [
              for (final index in [0, 1])
                FrostNavDestination(
                  icon: testIcons.image,
                  label: 'Destination $index',
                  builder: (_, child) => KeyedSubtree(key: ValueKey('destination-$index'), child: child),
                ),
            ],
            selectedIndex: 0,
            atDestinationRoot: false,
            onDestinationSelected: selections.add,
            canGoBack: true,
            onBack: () {},
            showsMobileNavigation: true,
            child: Navigator(
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (context) {
                  pageContext = context;
                  return const FrostShellDestination(child: Text('Root'));
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final navigator = Navigator.of(pageContext);
      for (final name in ['First', 'Second']) {
        unawaited(navigator.push(MaterialPageRoute<void>(builder: (_) => Text(name))));
        await tester.pumpAndSettle();
      }
      // A modal over the content region leaves the sidebar reachable.
      unawaited(showFrostDialog<void>(context: pageContext, builder: (_) => const Text('Modal')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(ValueKey('destination-${same ? 0 : 1}')));
      await tester.pump();
      expect(selections, [same ? 0 : 1]);
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsNothing);
      expect(find.text('Modal'), findsNothing);
      expect(navigator.canPop(), isFalse);
      expect(Navigator.of(pageContext, rootNavigator: true).canPop(), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('a pushed page keeps its route motion inside the shell', (tester) async {
    viewport(tester, const Size(1147, 717));
    late BuildContext pageContext;
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          destinations: destinations,
          selectedIndex: 0,
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          canGoBack: false,
          onBack: () {},
          showsMobileNavigation: true,
          child: Navigator(
            onGenerateRoute: (_) => MaterialPageRoute<void>(
              builder: (context) {
                pageContext = context;
                return const Text('Root');
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final route = MaterialPageRoute<void>(builder: (_) => const Text('Pushed'));
    unawaited(Navigator.of(pageContext).push(route));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(route.animation!.value, inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(route.animation!.value, 1);
    await tester.pumpWidget(const SizedBox());
  });

  for (final width in [1147.0, 360.0]) {
    testWidgets('caption search expands left, remains hittable and submits current/new tab: $width', (tester) async {
      viewport(tester, Size(width, 800));
      final controller = TextEditingController(text: 'Query');
      final focus = FocusNode();
      final tabs = FrostTabsController<String>(initial: 'A')..open('B', activate: false);
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      addTearDown(tabs.dispose);
      final submits = <String>[];
      await tester.pumpWidget(
        frostTestApp(
          FrostShell(
            destinations: destinations,
            selectedIndex: 0,
            atDestinationRoot: true,
            canGoBack: false,
            onBack: () {},
            showsMobileNavigation: true,
            onDestinationSelected: (_) {},
            tabs: presentation(tabs),
            brand: const FrostShellBrand(expanded: Text('Frost'), icon: SizedBox(width: 24)),
            navigationPlacement: FrostNavigationPlacement.sidebar,
            titleBarSearch: FrostCaptionSearch(
              controller: controller,
              focusNode: focus,
              placeholder: 'Search',
              onSubmitted: (q) => submits.add('current:$q'),
              onSubmittedInNewTab: (q) => submits.add('new:$q'),
              content: searchContent([
                FrostSearchSection(
                  title: 'History',
                  children: [FrostSearchSuggestionRow(label: 'Earlier', onSelected: () {})],
                ),
              ]),
            ),
            child: const FrostShellDestination(child: SizedBox.expand()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = find.byType(FrostCaptionSearch);
      final before = tester.getRect(field);
      expect(before.width, width == 1147 ? 360 : 44);
      if (width == 360) {
        await tester.tap(find.descendant(of: field, matching: find.byType(FrostButton)));
      } else {
        await tester.tap(find.byType(EditableText));
      }
      await tester.pumpAndSettle();
      final after = tester.getRect(field);
      expect(after.right, before.right);
      expect(after.width, width == 1147 ? 520 : greaterThan(before.width));
      expect(after.width, lessThanOrEqualTo(width));
      expect(focus.hasFocus, isTrue);
      expect(find.text('History'), findsOneWidget);
      // This point is outside the resting 240px slot. It must hit the editor,
      // not the underlying tab strip or brand.
      await tester.tapAt(after.centerLeft + const Offset(56, 0));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(tabs.active, 'A');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      expect(submits, ['current:Query', 'new:Query']);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(tester.getRect(field), before);
      expect(controller.text, 'Query');
      expect(focus.hasFocus, isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    for (final scale in [1.0, 2.0, 3.0]) {
      testWidgets('player never wraps; narrow actions use More; volume follows input: $platform $scale', (tester) async {
        var selected = 0;
        await tester.pumpWidget(
          frostTestApp(
            MediaQuery(
              data: MediaQueryData(textScaler: TextScaler.linear(scale)),
              child: Center(
                child: SizedBox(
                  width: 411,
                  height: 260,
                  child: FrostVideoFrame(
                    video: const ColoredBox(color: Colors.white),
                    state: const FrostVideoState(playing: false, position: Duration(seconds: 65), duration: Duration(seconds: 3605)),
                    onPlayPause: () {},
                    onSeek: (_) {},
                    onMuteToggle: () {},
                    onFullscreenToggle: () {},
                    topLeading: FrostMediaButton.icon(icon: testIcons.back, label: 'Back', onPressed: () {}),
                    actions: [
                      FrostToolbarItem.action(
                        icon: testIcons.image,
                        label: 'Quality',
                        priority: FrostToolbarPriority.high,
                        showsLabel: true,
                        onPressed: () => selected++,
                      ),
                    ],
                    moreActions: [FrostMenuAction('Settings', onSelected: () {})],
                  ),
                ),
              ),
            ),
            platform: platform,
          ),
        );
        await tester.pumpAndSettle();
        final play = find.byWidgetPredicate((w) => w is FrostMediaButton && w.label == 'L.play');
        final fullscreen = find.byWidgetPredicate((w) => w is FrostMediaButton && w.label == 'L.fullscreen');
        expect(tester.getCenter(play).dy, closeTo(tester.getCenter(fullscreen).dy, .01));
        expect(find.bySemanticsLabel('L.mute'), findsOneWidget);
        expect(find.text('Quality').hitTestable(), findsNothing);
        expect(find.byWidgetPredicate((w) => w is FrostRollingText && w.text == '01:05 / 1:00:05'), findsOneWidget);
        final more = find.bySemanticsLabel('L.more').first;
        await tester.tap(more);
        await tester.pumpAndSettle();
        expect(find.text('Quality').hitTestable(), findsOneWidget);
        await tester.tap(find.text('Quality').hitTestable());
        await tester.pumpAndSettle();
        expect(selected, 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }

  testWidgets('card cover alone zooms; overlay and footer keep geometry and footer is clickable', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      frostTestApp(
        Center(
          child: SizedBox(
            width: 260,
            child: FrostMediaCard(
              aspectRatio: 16 / 9,
              media: const FrostMediaImage(
                child: ColoredBox(key: ValueKey('image'), color: Colors.red),
              ),
              overlay: const Text('123 plays', key: ValueKey('stats')),
              progress: .25,
              topStart: const FrostBadge(label: 'Live', style: FrostBadgeStyle.solid),
              footer: const FrostText('Title', key: ValueKey('title')),
              onPressed: () => taps++,
            ),
          ),
        ),
      ),
    );
    final card = tester.getRect(find.byType(FrostMediaCard));
    final stats = tester.getRect(find.byKey(const ValueKey('stats')));
    final badge = tester.getRect(find.byType(FrostBadge));
    final title = tester.getRect(find.byKey(const ValueKey('title')));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer();
    await mouse.moveTo(card.center);
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byType(FrostMediaCard)), card);
    expect(tester.getRect(find.byKey(const ValueKey('stats'))), stats);
    expect(tester.getRect(find.byType(FrostBadge)), badge);
    expect(tester.getRect(find.byKey(const ValueKey('title'))), title);
    final image = tester.renderObject<RenderBox>(find.byKey(const ValueKey('image')));
    expect(image.getTransformTo(null).getMaxScaleOnAxis(), closeTo(1.03, .001));
    expect(
      tester.renderObject<RenderParagraph>(find.text('Title')).text.style!.color,
      FrostThemeTokens.of(tester.element(find.byType(FrostMediaCard))).textPrimary,
    );
    await tester.tap(find.text('Title'));
    expect(taps, 1);
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
