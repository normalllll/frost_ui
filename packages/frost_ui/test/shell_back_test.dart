import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart' show FrostHitKind;
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'package:frost_ui/src/primitives/_on_media_chrome_scope.dart' show FrostOnMediaChromeScope;
import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const _body = ValueKey('back-test-body');
Finder _back() => find.byKey(const ValueKey('frost-shell-back'));
bool _enabled(WidgetTester tester) => switch (tester.widget(_back())) {
  FrostButtonControl(:final onPressed) => onPressed != null,
  FrostButton(:final onPressed) => onPressed != null,
  _ => false,
};

Widget _shell({required bool canBack, required VoidCallback onBack, bool expanded = false, Widget? child, FrostNavigationPlacement? placement}) => FrostShell(
  navigationPlacement: placement,
  destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
  selectedIndex: 0,
  atDestinationRoot: !canBack,
  onDestinationSelected: (_) {},
  canGoBack: canBack,
  onBack: onBack,
  showsMobileNavigation: true,
  initiallyExpanded: expanded,
  brand: const FrostShellBrand(expanded: Text('Brand')),
  child:
      child ??
      const Column(
        children: [
          FrostPageHeader(title: Text('Page')),
          Expanded(child: SizedBox(key: _body)),
        ],
      ),
);

void _expectFeedbackShape(WidgetTester tester, Finder button, {bool media = false}) {
  // The fill and state wash are one shape decoration; only the content is clipped.
  expect(find.descendant(of: button, matching: find.byType(ClipPath)), findsOneWidget);
  final size = tester.getSize(find.descendant(of: button, matching: find.byType(FrostInteractionDecoration)));
  final expected = media ? const CircleBorder() : FrostRadius.shape(tester.element(button), FrostRadius.forHeight(size.height));
  expect(expected.getOuterPath(Offset.zero & size).contains(Offset.zero), isFalse);
  final decorations = find.descendant(of: button, matching: find.byType(FrostInteractionDecoration));
  expect(decorations, findsOneWidget);
  for (final decoration in tester.widgetList<FrostInteractionDecoration>(decorations)) {
    expect((decoration.decoration as ShapeDecoration).shape, expected);
  }
  // Check the interpolated decoration actually passed to the render object too.
  final painted = find.descendant(of: button, matching: find.byType(DecoratedBox));
  expect(tester.widgetList<DecoratedBox>(painted).map((w) => w.decoration).whereType<ShapeDecoration>().every((d) => d.shape == expected), isTrue);
}

void main() {
  for (final mode in ['caption', 'toolbar', 'media']) {
    testWidgets('$mode Back keeps its shared shape while hovered and pressed', (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var calls = 0;
      final caption = mode == 'caption';
      final media = mode == 'media';
      final header = FrostPageHeader(title: const Text('Page'), onBack: () => calls++);
      await tester.pumpWidget(
        frostTestApp(
          caption
              ? FrostWindowCaptionScope(
                  window: FakeWindow(),
                  child: _shell(canBack: true, onBack: () => calls++),
                )
              : Align(
                  alignment: Alignment.topLeft,
                  child: media ? FrostOnMediaChromeScope(child: header) : header,
                ),
          platform: caption ? TargetPlatform.windows : TargetPlatform.android,
          density: FrostDensity.compact,
        ),
      );
      final back = caption ? _back() : find.byType(FrostCompactBackButton);
      final rect = tester.getRect(back);
      _expectFeedbackShape(tester, back, media: media);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: rect.center);
      await mouse.moveTo(rect.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      _expectFeedbackShape(tester, back, media: media);
      final press = await tester.startGesture(rect.center);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 70));
      _expectFeedbackShape(tester, back, media: media);
      expect(tester.getRect(back), rect);
      await press.cancel();
      await mouse.removePointer();
      await tester.pumpAndSettle();
      expect(calls, 0);
      if (caption) {
        final native = tester.widgetList<IconButton>(find.descendant(of: find.byType(FrostCaptionButtons), matching: find.byType(IconButton)));
        expect(native, hasLength(3));
        for (final button in native) {
          for (final state in [WidgetState.hovered, WidgetState.pressed]) {
            expect(button.style!.shape!.resolve({state}), const RoundedRectangleBorder());
          }
        }
      }
      expect(tester.takeException(), isNull);
    });
  }

  for (final platform in TargetPlatform.values) {
    for (final width in [320.0, 720.0, 1440.0]) {
      testWidgets('Back ownership follows layout on $platform width=$width', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final pointer = platform == TargetPlatform.windows || platform == TargetPlatform.macOS || platform == TargetPlatform.linux;
        final horizontal = width >= 480 && width >= 900 * (pointer ? 1 : 1.3);
        var canBack = false, calls = 0;
        late StateSetter update;
        final window = platform == TargetPlatform.windows ? FakeWindow() : null;
        await tester.pumpWidget(
          frostTestApp(
            StatefulBuilder(
              builder: (_, set) {
                update = set;
                return FrostWindowCaptionScope(
                  window: window,
                  child: _shell(canBack: canBack, onBack: () => calls++),
                );
              },
            ),
            platform: platform,
            density: FrostDensity.compact,
          ),
        );
        final pageBack = find.byType(FrostCompactBackButton);
        expect(_back(), horizontal ? findsOneWidget : findsNothing);
        expect(pageBack, findsNothing);
        expect(tester.widget<FrostShellNavigationScope>(find.byType(FrostShellNavigationScope)).ownsBackControl, horizontal);
        final position = horizontal ? tester.getRect(_back()) : null;
        if (horizontal) {
          expect(_enabled(tester), isFalse);
          expect(position!.center.dx, 30);
          expect(position.top, 0, reason: 'Back sits in the top row, with or without window buttons');
          expect(position.size, Size(60, pointer ? 40 : 44), reason: 'the row is as high as the control target');
          if (window != null) {
            expect(position.left, 0);
            final control = tester.widget<FrostButtonControl>(_back());
            expect(control.geometry!.cornerRadius, isNull);
            expect(position.right, lessThanOrEqualTo(tester.getRect(find.text('Brand')).left));
          }
          await tester.tap(_back());
          expect(calls, 0);
        } else {
          expect(tester.getRect(find.byType(FrostPageHeader)).top, window != null ? 40 : 0);
        }
        update(() => canBack = true);
        await tester.pump();
        expect(pageBack, horizontal ? findsNothing : findsOneWidget, reason: 'first frame uses the layout-owned control');
        final active = horizontal ? _back() : pageBack;
        if (horizontal) {
          expect(tester.getRect(active), position);
          expect(_enabled(tester), isTrue);
        }
        await tester.tap(active);
        expect(calls, 1);
        if (window != null && horizontal) {
          expect(window.calls.last.where((r) => r.kind == FrostHitKind.caption).any((r) => r.rect.contains(position!.center)), isFalse);
        }
        update(() => canBack = false);
        await tester.pump();
        expect(pageBack, findsNothing);
        if (horizontal) expect(_enabled(tester), isFalse);
        expect(tester.takeException(), isNull);
      });
    }
  }
  testWidgets('Back survives sidebar spring and switches to the page when touch navigation becomes bottom', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var calls = 0;
    await tester.pumpWidget(
      frostTestApp(
        FrostWindowCaptionScope(
          window: FakeWindow(),
          child: _shell(canBack: true, onBack: () => calls++),
        ),
        platform: TargetPlatform.android,
      ),
    );
    final rect = tester.getRect(_back());
    await tester.tap(findFrostTooltip('L.expandNavigation'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(tester.getRect(_back()), rect);
    await tester.pumpAndSettle();
    for (final width in [1200.0, 390.0, 1440.0]) {
      tester.view.physicalSize = Size(width, 900);
      await tester.pump();
      expect(_back(), width >= 600 ? findsOneWidget : findsNothing);
      expect(find.byType(FrostCompactBackButton), width >= 600 ? findsNothing : findsOneWidget);
      if (width >= 600) expect(tester.getRect(_back()), rect);
      expect(tester.takeException(), isNull);
    }
    final focus = find.descendant(of: _back(), matching: find.byType(Focus)).last;
    tester.widget<Focus>(focus).focusNode!.requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(calls, 1);
  });
  testWidgets('fixed Back is outside scrolling content and sits at the right edge in RTL', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      frostTestApp(
        Directionality(
          textDirection: TextDirection.rtl,
          child: _shell(
            canBack: true,
            onBack: () {},
            child: ListView.builder(
              controller: scroll,
              itemCount: 100,
              itemBuilder: (_, index) => SizedBox(height: 48, child: Text('Item $index')),
            ),
          ),
        ),
      ),
    );
    final rect = tester.getRect(_back());
    expect(rect.center.dx, 1440 - 30);
    await tester.drag(find.byWidgetPredicate((w) => w is ListView && w.controller == scroll), const Offset(0, -300));
    await tester.pumpAndSettle();
    expect(scroll.offset, greaterThan(0));
    expect(tester.getRect(_back()), rect);
    expect(tester.takeException(), isNull);
  });
  testWidgets('compact desktop SplitView uses page Back before the outer route and cleans up', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var detail = true, showSplit = true, localCalls = 0, outerCalls = 0;
    late StateSetter update;
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, setState) {
            update = setState;
            return _shell(
              placement: FrostNavigationPlacement.bottom,
              canBack: false,
              onBack: () => outerCalls++,
              child: showSplit
                  ? FrostSplitView(
                      primary: const Text('Master'),
                      secondary: detail ? const Column(children: [FrostPageHeader(title: Text('Local detail'))]) : null,
                      onCloseSecondary: () {
                        localCalls++;
                        update(() => detail = false);
                      },
                    )
                  : const Text('Replacement'),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(FrostCompactBackButton), findsOneWidget);
    expect(find.byType(FrostCompactBackButton), findsOneWidget);
    expect(find.byType(FrostCompactBackButton), findsOneWidget);
    await tester.tap(find.byType(FrostCompactBackButton));
    await tester.pumpAndSettle();
    expect(localCalls, 1);
    expect(outerCalls, 0);
    expect(find.text('Master'), findsOneWidget);
    expect(find.byType(FrostCompactBackButton), findsNothing);
    update(() => detail = true);
    await tester.pumpAndSettle();
    expect(find.byType(FrostCompactBackButton), findsOneWidget);
    update(() => showSplit = false);
    await tester.pumpAndSettle();
    expect(find.byType(FrostCompactBackButton), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final nested in [false, true]) {
    testWidgets('covered compact SplitView cannot steal page Back nested=$nested', (tester) async {
      tester.view.physicalSize = const Size(390, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final navigator = GlobalKey<NavigatorState>();
      var outerCanBack = false, localCalls = 0, outerCalls = 0, detail = true;
      late StateSetter update;
      Widget split() => FrostSplitView(
        primary: const Text('Master'),
        secondary: detail ? const FrostPageHeader(title: Text('Local detail')) : null,
        onCloseSecondary: () {
          localCalls++;
          update(() => detail = false);
        },
      );
      await tester.pumpWidget(
        frostTestApp(
          StatefulBuilder(
            builder: (_, setState) {
              update = setState;
              return _shell(
                placement: FrostNavigationPlacement.bottom,
                canBack: outerCanBack,
                onBack: () {
                  outerCalls++;
                  navigator.currentState!.pop();
                },
                child: Navigator(
                  key: navigator,
                  onGenerateRoute: (_) => MaterialPageRoute<void>(
                    builder: (_) => nested ? Navigator(onGenerateRoute: (_) => MaterialPageRoute<void>(builder: (_) => split())) : split(),
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      navigator.currentState!.push(MaterialPageRoute<void>(builder: (_) => const FrostPageHeader(title: Text('Other page'))));
      update(() => outerCanBack = true);
      await tester.pumpAndSettle();
      expect(find.byType(FrostCompactBackButton), findsOneWidget);
      await tester.tap(find.byType(FrostCompactBackButton));
      await tester.pumpAndSettle();
      expect(outerCalls, 1);
      expect(localCalls, 0);
      update(() => outerCanBack = false);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(FrostCompactBackButton));
      await tester.pumpAndSettle();
      expect(localCalls, 1);
      expect(find.byType(FrostCompactBackButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('root flags do not resize destination navigation, page State or scrolling', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final scroll = ScrollController();
    var root = true;
    late StateSetter update;
    final page = ListView.builder(
      key: const ValueKey('retained-list'),
      controller: scroll,
      itemCount: 100,
      itemBuilder: (_, index) => SizedBox(height: 48, child: Text('Item $index')),
    );
    await tester.pumpWidget(
      frostTestApp(
        StatefulBuilder(
          builder: (_, set) {
            update = set;
            return _shell(
              canBack: !root,
              onBack: () {},
              child: FrostShellDestination(child: page),
            );
          },
        ),
        platform: TargetPlatform.android,
      ),
    );
    final state = tester.state(find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable)));
    scroll.jumpTo(300);
    await tester.pump();
    final before = tester.getSize(find.byType(ListView)).height;
    update(() => root = false);
    await tester.pump();
    expect(tester.widget<FrostShellNavigationScope>(find.byType(FrostShellNavigationScope)).canGoBack, isTrue);
    for (var frame = 0; frame < 50; frame++) {
      await tester.pump(const Duration(milliseconds: 20));
      final height = tester.getSize(find.byType(ListView)).height;
      expect(tester.state(find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable))), same(state));
      expect(scroll.offset, 300);
      expect(height, before);
    }
    await tester.pumpAndSettle();
    expect(find.text('Home').hitTestable(), findsOneWidget);
    update(() => root = true);
    await tester.pumpAndSettle();
    expect(tester.state(find.descendant(of: find.byType(ListView), matching: find.byType(Scrollable))), same(state));
    expect(scroll.offset, 300);
    expect(find.text('Home').hitTestable(), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    scroll.dispose();
  });
  testWidgets('standalone page keeps its own Back without a shell', (tester) async {
    var calls = 0;
    await tester.pumpWidget(frostTestApp(FrostPageHeader(title: const Text('Standalone'), onBack: () => calls++)));
    await tester.tap(find.byType(FrostCompactBackButton));
    expect(calls, 1);
  });
}
