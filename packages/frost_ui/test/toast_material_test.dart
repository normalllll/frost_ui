import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/desktop.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_layout_identity.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';
import 'package:frost_ui/src/motion/layout_crossfade.dart' show FrostTimedLayoutCrossfade;
import 'package:material_ui/material_ui.dart';

import 'support.dart';

Widget shell({FrostNavigationPlacement? placement, Widget? body}) => FrostShell(
  navigationPlacement: placement,
  destinations: [
    FrostNavDestination(icon: testIcons.image, label: 'Home'),
    FrostNavDestination(icon: testIcons.search, label: 'Search'),
  ],
  selectedIndex: 0,
  canGoBack: false,
  onBack: () {},
  showsMobileNavigation: true,
  atDestinationRoot: true,
  onDestinationSelected: (_) {},
  child: FrostShellDestination(child: body ?? const SizedBox.expand(key: ValueKey('content'))),
);

void viewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
}

void main() {
  for (final brightness in Brightness.values) {
    for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
      testWidgets('toast raised fill is opaque over red in all tones: $brightness $platform', (tester) async {
        for (final tone in FrostTone.values) {
          await tester.pumpWidget(
            FrostScope(
              config: testConfig,
              child: MaterialApp(
                theme: FrostTheme.build(config: testConfig, brightness: brightness, platform: platform, locale: const Locale('en'), tone: tone),
                builder: (_, child) => FrostToastHost(child: child!),
                home: const ColoredBox(color: Color(0xFFFF0000)),
              ),
            ),
          );
          FrostToast.info('Neutral notice');
          await tester.pumpAndSettle();
          final context = tester.element(find.text('Neutral notice'));
          final surface = FrostSurfaceScope.maybeOf(context)!;
          expect(surface.isGlass, false);
          expect(surface.background, FrostThemeTokens.of(context).surfaceRaised);
          expect(surface.background.a, 1, reason: 'No red backdrop can recolour the resting notification.');
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        }
      });
    }
  }
  for (final direction in TextDirection.values) {
    for (final scale in [1.0, 3.0]) {
      testWidgets('info and error share trailing actions or aligned wrapping: $direction scale=$scale', (tester) async {
        await tester.pumpWidget(
          FrostScope(
            config: testConfig,
            child: MaterialApp(
              theme: FrostTheme.build(config: testConfig, brightness: Brightness.light, platform: TargetPlatform.windows, locale: const Locale('en')),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                child: Directionality(
                  textDirection: direction,
                  child: FrostToastHost(child: child!),
                ),
              ),
              home: shell(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        FrostToast.actionableInfo('Removed', actionLabel: 'Undo', onAction: () {});
        await tester.pumpAndSettle();
        final button = find.widgetWithText(FrostButton, 'Undo');
        final message = tester.getRect(find.text('Removed'));
        final action = tester.getRect(button);
        expect(buttonControl(tester, button).variant, FrostButtonVariant.standard);
        if (scale == 1) {
          expect(action.center.dy, closeTo(message.center.dy, .01));
          expect(direction == TextDirection.ltr ? action.left >= message.right : action.right <= message.left, true);
        } else {
          expect(action.top, greaterThanOrEqualTo(message.bottom));
          expect(direction == TextDirection.ltr ? action.left : action.right, closeTo(direction == TextDirection.ltr ? message.left : message.right, .01));
        }
        expect(tester.takeException(), isNull);
        await tester.tap(button);
        await tester.pumpAndSettle();
        FrostToast.error('Removed', actionLabel: 'Retry', onAction: () {});
        await tester.pumpAndSettle();
        final retry = tester.getRect(find.widgetWithText(FrostButton, 'Retry'));
        expect(retry.top, action.top);
        final alignLeft = scale == 1 ? direction == TextDirection.rtl : direction == TextDirection.ltr;
        expect(alignLeft ? retry.left : retry.right, alignLeft ? action.left : action.right);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      });
    }
  }
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('toast stays in actual content, including navigation reserve: $platform', (tester) async {
      viewport(tester, platform == TargetPlatform.windows ? const Size(1000, 800) : const Size(411, 900));
      await tester.pumpWidget(frostTestApp(shell(), platform: platform));
      await tester.pumpAndSettle();
      FrostToast.info('Content notice');
      await tester.pumpAndSettle();
      final content = tester.getRect(find.byKey(const ValueKey('content')));
      final text = tester.getRect(find.text('Content notice'));
      expect(content.contains(text.topLeft), true);
      expect(content.contains(text.bottomRight), true);
      if (platform == TargetPlatform.android) {
        expect(text.top, greaterThan(content.center.dy));
        expect(content.bottom, lessThan(900), reason: 'The destination owns an actual bottom bar.');
      } else {
        expect(content.left, greaterThan(0), reason: 'The sidebar remains outside the toast viewport.');
      }
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('content viewport and queue survive sidebar/bottom reflow', (tester) async {
    viewport(tester, const Size(950, 800));
    var placement = FrostNavigationPlacement.sidebar;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return shell(placement: placement);
          },
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    FrostToast.actionableInfo('Undo stays live', actionLabel: 'Undo', onAction: () {});
    await tester.pumpAndSettle();
    update(() => placement = FrostNavigationPlacement.bottom);
    await tester.pumpAndSettle();
    final content = tester.getRect(find.byKey(const ValueKey('content')));
    expect(content.contains(tester.getRect(find.text('Undo stays live')).bottomRight), true);
    expect(find.text('Undo'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('touch queue retains distinct actions, merges passive duplicates and starts timers on display', (tester) async {
    await tester.pumpWidget(frostTestApp(const Scaffold(), platform: TargetPlatform.android));
    var actions = 0;
    FrostToast.info('First');
    FrostToast.actionableInfo('Second', actionLabel: 'Undo', onAction: () => actions++);
    FrostToast.info('First');
    await tester.pumpAndSettle();
    expect(find.text('First  ×2'), findsOneWidget);
    expect(find.text('Second'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Second'), findsOneWidget);
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(actions, 1);
    expect(find.text('Second'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('desktop capacity queues overflow without discarding a notice', (tester) async {
    await tester.pumpWidget(frostTestApp(const Scaffold()));
    for (var i = 0; i < 6; i++) {
      FrostToast.info('Event $i');
    }
    await tester.pumpAndSettle();
    expect(find.text('Event 5'), findsNothing);
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Event 5'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('screen reader action does not expire and remains a live region', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(data: MediaQuery.of(context).copyWith(accessibleNavigation: true), child: shell()),
        ),
        platform: TargetPlatform.android,
      ),
    );
    await tester.pumpAndSettle();
    FrostToast.actionableInfo('Removed item', actionLabel: 'Undo', onAction: () {});
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 20));
    expect(find.text('Undo'), findsOneWidget);
    final live = find.ancestor(of: find.text('Removed item'), matching: find.byWidgetPredicate((w) => w is Semantics && w.properties.liveRegion == true));
    expect(live, findsWidgets);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('title strip hover uses four percent and touch clears it without a mouse exit', (tester) async {
    final tabs = FrostTabsController<String>(initial: 'First')..open('Second', activate: false);
    addTearDown(tabs.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Column(
          children: [
            SizedBox(
              height: 44,
              child: FrostTabStrip(
                controller: tabs,
                label: (_, t) => FrostTabLabel(title: t),
                closeTooltip: 'Close',
                newTabTooltip: 'New',
                newTabIcon: testIcons.image,
                onNewTab: () {},
              ),
            ),
            Expanded(
              child: GestureDetector(key: const ValueKey('touch'), behavior: HitTestBehavior.opaque, onTap: () {}),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('First')));
    await mouse.down(tester.getCenter(find.text('First')));
    await tester.pumpAndSettle();
    final pressed = tester.widget<AnimatedContainer>(find.ancestor(of: find.text('First'), matching: find.byType(AnimatedContainer)).first);
    final tokens = FrostThemeTokens.of(tester.element(find.text('First')));
    expect((pressed.decoration! as ShapeDecoration).color, Color.alphaBlend(tokens.fill.withValues(alpha: .08), tokens.surfaceRaised));
    await mouse.up();
    await mouse.moveTo(tester.getCenter(find.text('Second')));
    await tester.pumpAndSettle();
    Color fill() =>
        (tester.widget<AnimatedContainer>(find.ancestor(of: find.text('Second'), matching: find.byType(AnimatedContainer)).first).decoration!
                as ShapeDecoration)
            .color!;
    expect(fill().a, closeTo(.04, .002));
    await tester.tap(find.byKey(const ValueKey('touch')));
    await tester.pumpAndSettle();
    expect(fill().a, 0);
    await mouse.removePointer();
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reduced dialog enter and exit finish at the shared short fade', (tester) async {
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: Builder(
              builder: (context) => FrostButton(
                label: 'Open',
                onPressed: () => showFrostDialog<void>(
                  context: context,
                  builder: (context) => FrostDialog(
                    title: 'Dialog',
                    content: FrostButton(label: 'Close', onPressed: () => Navigator.pop(context)),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(FrostMotion.reducedFade + const Duration(milliseconds: 1));
    final route = ModalRoute.of(tester.element(find.text('Dialog')))!;
    expect(route.animation!.status, AnimationStatus.completed);
    expect(route.transitionDuration, FrostMotion.reducedFade);
    expect(route.reverseTransitionDuration, FrostMotion.reducedFade);
    await tester.tap(find.text('Close'));
    await tester.pump();
    await tester.pump(FrostMotion.reducedFade + const Duration(milliseconds: 1));
    expect(find.text('Dialog'), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('an open modal does not mask a newly enabled system motion preference', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => FrostButton(
            label: 'Open',
            onPressed: () => showFrostDialog<void>(
              context: context,
              builder: (_) => FrostDialog(title: 'Live system preference', content: const SizedBox(height: 40)),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    expect(MediaQuery.disableAnimationsOf(tester.element(find.text('Live system preference'))), true);
    expect(find.ancestor(of: find.text('Live system preference'), matching: find.byType(ScaleTransition)), findsNothing);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
    testWidgets('enabling reduced motion stops an in-flight toast: $platform', (tester) async {
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await tester.pumpWidget(frostTestApp(const Scaffold(), platform: platform));
      FrostToast.info('Changing preference');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 40));
      final before = tester.getTopLeft(find.text('Changing preference'));
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pump();
      final end = tester.getTopLeft(find.text('Changing preference'));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.getTopLeft(find.text('Changing preference')), end);
      expect((before - end).distance, greaterThan(1));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
  testWidgets('tab content switches immediately before and after enabling reduced motion', (tester) async {
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final tabs = FrostTabsController<String>(initial: 'First')..open('Second', activate: false);
    addTearDown(tabs.dispose);
    await tester.pumpWidget(frostTestApp(FrostTabHost<String>(controller: tabs, builder: (_, tab) => Text(tab))));
    tabs.activate(1);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
    await tester.pump();
    expect(find.text('First'), findsNothing);
    expect(find.text('Second'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('reflow reveals incoming coordinates only after outgoing pixels have faded', (tester) async {
    var identity = 0;
    final geometry = FrostLayoutIdentity()..update(0, viewport: 0);
    addTearDown(geometry.dispose);
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return FrostLayoutCrossfade(
              layoutIdentity: geometry,
              child: Align(alignment: identity == 0 ? Alignment.topLeft : Alignment.bottomRight, child: const Text('Same retained content')),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    update(() => identity = 1);
    geometry.update(1, viewport: 0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 40));
    Animation<double> incoming() => tester
        .widget<FrostMaterialRevealTransition>(
          find.descendant(of: find.byType(FrostLayoutCrossfade), matching: find.byType(FrostMaterialRevealTransition)).first,
        )
        .opacity;
    expect(incoming().value, 0, reason: 'The old coordinates own the first half; no doubled text.');
    await tester.pump(const Duration(milliseconds: 60));
    expect(incoming().value, greaterThan(0));
    await tester.pumpAndSettle();
    expect(incoming().value, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
  for (final reduced in [false, true]) {
    testWidgets('actual shell switches destinations at once and fades only reflow, keeping retained pages: reduced=$reduced', (tester) async {
      viewport(tester, const Size(1000, 800));
      var selected = 0;
      var placement = FrostNavigationPlacement.sidebar;
      late StateSetter update;
      final text = TextEditingController(text: 'Retained input');
      addTearDown(text.dispose);
      final retainedPages = [FrostShellDestination(child: FrostTextField(controller: text)), const FrostShellDestination(child: Text('Second destination'))];
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: StatefulBuilder(
                builder: (_, set) {
                  update = set;
                  return FrostShell(
                    navigationPlacement: placement,
                    destinations: [
                      FrostNavDestination(
                        icon: testIcons.image,
                        label: 'Home',
                        builder: (_, child) => KeyedSubtree(key: const ValueKey('home-destination'), child: child),
                      ),
                      FrostNavDestination(
                        icon: testIcons.search,
                        label: 'Search',
                        builder: (_, child) => KeyedSubtree(key: const ValueKey('search-destination'), child: child),
                      ),
                    ],
                    selectedIndex: selected,
                    atDestinationRoot: true,
                    onDestinationSelected: (index) => update(() => selected = index),
                    canGoBack: false,
                    onBack: () {},
                    showsMobileNavigation: true,
                    child: IndexedStack(index: selected, children: retainedPages),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final fieldState = tester.state(find.byType(EditableText));
      Animation<double> fade() => tester
          .widget<FrostMaterialRevealTransition>(
            find.descendant(of: find.byType(FrostTimedLayoutCrossfade).first, matching: find.byType(FrostMaterialRevealTransition)).first,
          )
          .opacity;
      await tester.tap(find.byKey(const ValueKey('search-destination')));
      await tester.pump();
      expect(selected, 1);
      expect(find.text('Second destination'), findsOneWidget, reason: 'The selected page shows on its first frame.');
      expect(find.byType(FrostTimedLayoutCrossfade), findsOneWidget, reason: 'Only the layout reflow owns a fade.');
      expect(fade().value, 1);
      expect(
        find
            .ancestor(of: find.text('Second destination'), matching: find.byType(FrostMaterialRevealTransition))
            .evaluate()
            .every((element) => (element.widget as FrostMaterialRevealTransition).opacity.value == 1),
        isTrue,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-destination')));
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(EditableText)), same(fieldState));
      expect(text.text, 'Retained input');
      update(() => placement = FrostNavigationPlacement.bottom);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 40));
      expect(fade().value, reduced ? 1 : 0, reason: 'The real shell uses geometric fade-through, not overlapping coordinates.');
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(EditableText)), same(fieldState));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
