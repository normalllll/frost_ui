import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'package:material_ui/material_ui.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

class _AppWidget extends StatelessWidget {
  const _AppWidget({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => child;
}

void main() {
  group('toolbar slots', () {
    const text = Text('A title of some length', key: ValueKey('title'));
    Widget toolbar(FrostToolbar bar, {double width = 500}) => frostTestApp(
      Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: bar),
      ),
    );
    double titleWidth(WidgetTester tester) => tester.getSize(find.byKey(const ValueKey('title'))).width;

    testWidgets('wrapping the title in Padding, Semantics or an app widget does not change its room', (tester) async {
      await tester.pumpWidget(toolbar(const FrostToolbar(title: text)));
      final natural = titleWidth(tester);
      expect(natural, greaterThan(100));
      for (final wrapped in [
        const Padding(padding: EdgeInsets.zero, child: text),
        Semantics(label: 'Title', child: text),
        const _AppWidget(child: text),
        const FrostToolbarTitle(child: text),
      ]) {
        await tester.pumpWidget(toolbar(FrostToolbar(title: wrapped)));
        expect(titleWidth(tester), natural, reason: '${wrapped.runtimeType}');
      }
    });

    testWidgets('leading icons get one compact target whatever wraps them', (tester) async {
      const key = ValueKey('icon');
      Widget icon() => FrostButton.icon(key: key, icon: testIcons.add, label: 'Add', onPressed: () {});
      await tester.pumpWidget(toolbar(FrostToolbar(leadingIcons: [icon()])));
      final bare = tester.getRect(find.byKey(key));
      await tester.pumpWidget(toolbar(FrostToolbar(leadingIcons: [_AppWidget(child: icon())])));
      expect(tester.getRect(find.byKey(key)), bare);
    });

    testWidgets('a toolbar in a narrow panel of a wide window keeps the narrow middle minimum', (tester) async {
      _window(tester, const Size(1400, 900));
      const middle = ValueKey('middle');
      await tester.pumpWidget(
        toolbar(
          const FrostToolbar(
            title: SizedBox(key: ValueKey('title'), width: 370, height: 20),
            middle: SizedBox(key: middle, height: 32),
          ),
          width: 560,
        ),
      );
      expect(titleWidth(tester), 370, reason: 'the title keeps its width while the middle fits at 160');
    });
  });

  group('caption slots', () {
    const brand = SizedBox(key: ValueKey('brand'), width: 200, height: 20);
    Widget shell(FakeWindow window, {Widget? search}) => frostTestApp(
      FrostWindowCaptionScope(
        window: window,
        child: FrostShell(
          destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
          selectedIndex: 0,
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          canGoBack: false,
          onBack: () {},
          showsMobileNavigation: true,
          brand: const FrostShellBrand(expanded: brand),
          titleBarSearch: search,
          child: const SizedBox.expand(),
        ),
      ),
    );

    testWidgets('the brand gets the room it needs and a wrapped search keeps its width at 1920', (tester) async {
      _window(tester, const Size(1920, 1000));
      final window = FakeWindow();
      addTearDown(window.dispose);
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      final search = FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {});
      await tester.pumpWidget(shell(window, search: search));
      await tester.pumpAndSettle();
      final bare = tester.getRect(find.byType(FrostCaptionSearch));
      expect(bare.width, 360);
      final clip = tester.getRect(find.byKey(const ValueKey('brand')));
      expect(clip.width, 200);
      final painted = tester.renderObject<RenderBox>(find.byKey(const ValueKey('brand')));
      expect(painted.size.width, 200);
      await tester.pumpWidget(
        shell(
          window,
          search: Padding(padding: EdgeInsets.zero, child: search),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byType(FrostCaptionSearch)).width, 360);
    });
  });

  testWidgets('both title row slots are reported instead of dropping one', (tester) async {
    final controller = TextEditingController();
    final focus = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focus.dispose);
    await tester.pumpWidget(
      frostTestApp(
        FrostShell(
          destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home')],
          selectedIndex: 0,
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          canGoBack: false,
          onBack: () {},
          showsMobileNavigation: true,
          titleBarContent: const Text('Content'),
          titleBarSearch: FrostCaptionSearch(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: (_) {}),
          child: const SizedBox.expand(),
        ),
      ),
    );
    expect(tester.takeException(), isA<FlutterError>());
  });

  group('window shape', () {
    const content = ValueKey('content');
    Widget shell(FakeWindow window, {TextEditingController? controller, FocusNode? focus, void Function(bool, bool)? report}) => frostTestApp(
      FrostWindowCaptionScope(
        window: window,
        child: FrostShell(
          destinations: const [
            FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home'),
            FrostNavDestination(icon: FrostIconData.glyph(Icons.search), label: 'Find'),
          ],
          selectedIndex: 0,
          atDestinationRoot: true,
          onDestinationSelected: (_) {},
          canGoBack: true,
          onBack: () {},
          showsMobileNavigation: true,
          titleBarContent: controller == null ? null : FrostSearchInput(controller: controller, focusNode: focus!, placeholder: 'Search', onSubmitted: (_) {}),
          child: FrostShellDestination(
            child: Builder(
              builder: (context) {
                report?.call(FrostShell.titleContentInCaptionOf(context), FrostAutoScaffold.usesHorizontalLayoutOf(context));
                return const SizedBox.expand(key: content);
              },
            ),
          ),
        ),
      ),
    );

    for (final (size, sidebar) in [
      (const Size(500, 1400), false),
      (const Size(800, 1400), false),
      (const Size(1100, 900), true),
      (const Size(1400, 900), true),
    ]) {
      testWidgets('a pointer window of $size has ${sidebar ? 'a sidebar' : 'a bottom bar'}, window buttons and agreeing title content', (tester) async {
        _window(tester, size);
        final window = FakeWindow();
        addTearDown(window.dispose);
        final controller = TextEditingController();
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(focus.dispose);
        late bool inCaption, horizontal;
        await tester.pumpWidget(
          shell(
            window,
            controller: controller,
            focus: focus,
            report: (a, b) {
              inCaption = a;
              horizontal = b;
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(horizontal, sidebar);
        expect(find.byType(FrostCaptionButtons), findsOneWidget);
        expect(find.byType(FrostNavItem), sidebar ? findsWidgets : findsNothing);
        expect(inCaption, sidebar);
        expect(find.byType(FrostSearchInput), sidebar ? findsOneWidget : findsNothing);
        if (sidebar) expect(tester.getRect(find.byType(FrostSearchInput)).top, lessThan(40));
        // Nothing pinned above the content.
        expect(tester.getRect(find.byKey(content)).top, lessThanOrEqualTo(48));
      });
    }

    testWidgets('title content keeps its text and focus while it is out of the row', (tester) async {
      _window(tester, const Size(1400, 900));
      final window = FakeWindow();
      addTearDown(window.dispose);
      final controller = TextEditingController();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      bool? inCaption;
      await tester.pumpWidget(shell(window, controller: controller, focus: focus, report: (a, _) => inCaption = a));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'kept');
      final element = tester.element(find.byType(EditableText));
      tester.view.physicalSize = const Size(500, 1400);
      await tester.pumpAndSettle();
      expect(inCaption, isFalse);
      expect(find.byType(EditableText), findsNothing);
      expect(tester.element(find.byType(EditableText, skipOffstage: false)), same(element));
      tester.view.physicalSize = const Size(1400, 900);
      await tester.pumpAndSettle();
      expect(inCaption, isTrue);
      expect(tester.element(find.byType(EditableText)), same(element));
      expect(controller.text, 'kept');
      expect(focus.hasPrimaryFocus, isTrue);
    });

    testWidgets('outside a shell there is no title row', (tester) async {
      late bool inCaption;
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              inCaption = FrostShell.titleContentInCaptionOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(inCaption, isFalse);
    });
  });

  group('input capability', () {
    late FrostInputCapability input;
    var builds = 0;
    Widget app(TargetPlatform platform, {Widget? child}) => frostTestApp(
      FrostInputFeedback(
        child: Center(
          child: Builder(
            builder: (context) {
              input = FrostInputCapability.of(context);
              builds++;
              return child ?? const SizedBox(key: ValueKey('probe'), width: 200, height: 100);
            },
          ),
        ),
      ),
      platform: platform,
    );

    testWidgets('a pointer platform: touch makes hover unavailable', (tester) async {
      await tester.pumpWidget(app(TargetPlatform.windows));
      expect(input.hoverAvailable, isTrue);
      final before = builds;
      await tester.tapAt(const Offset(1, 1));
      await tester.pump();
      expect(builds, greaterThan(before), reason: 'a reader follows the input');
      expect(input.touch, isTrue);
      expect(input.hoverAvailable, isFalse);
      expect(input.mouseAvailable, isTrue, reason: 'the baseline does not follow the input');
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(input.hoverAvailable, isTrue);
      await mouse.removePointer();
    });

    testWidgets('a touch platform: a mouse makes hover available and changes no sizes', (tester) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        app(
          TargetPlatform.android,
          child: FrostButton(key: key, label: 'Go', onPressed: () {}),
        ),
      );
      final rect = tester.getRect(find.byKey(key));
      expect(input.mouseAvailable, isFalse);
      expect(input.hoverAvailable, isFalse);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(const Offset(5, 5));
      await tester.pump();
      expect(input.mouseAvailable, isTrue);
      expect(input.hoverAvailable, isTrue);
      expect(tester.getRect(find.byKey(key)), rect);
      await mouse.removePointer();
    });

    testWidgets('without FrostApp it reports the missing environment', (tester) async {
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) {
              FrostInputCapability.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    });
  });
}
