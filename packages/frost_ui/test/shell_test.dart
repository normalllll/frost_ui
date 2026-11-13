import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart' show FrostHitKind;
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'package:frost_ui/src/primitives/_click_feedback.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';
import 'window_caption_test.dart' show FakeWindow;

const home = FrostNavDestination(icon: FrostIconData.glyph(Icons.home), label: 'Home');
const pageKey = ValueKey('sheet-content');

Widget shell({bool expanded = false, Widget? child, Widget? brand, FrostSidebarAlignment alignment = FrostSidebarAlignment.automatic}) => FrostShell(
  sidebarAlignment: alignment,
  destinations: const [home],
  selectedIndex: 0,
  atDestinationRoot: true,
  onDestinationSelected: (_) {},
  canGoBack: true,
  onBack: () {},
  showsMobileNavigation: true,
  initiallyExpanded: expanded,
  brand: brand == null ? null : FrostShellBrand(expanded: brand),
  child: FrostShellDestination(child: child ?? const SizedBox.expand(key: pageKey)),
);

void main() {
  testWidgets('sheet clips painted content at its upper corner', (tester) async {
    tester.view.physicalSize = const Size(800, 200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      frostTestApp(
        RepaintBoundary(
          key: boundaryKey,
          child: shell(
            child: const ColoredBox(color: Color(0xFFFF0000), child: SizedBox.expand()),
          ),
        ),
      ),
    );
    final boundary = boundaryKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    // Outside the lg corner the red child must never paint; inside it must.
    final top = tester.getTopLeft(find.byType(FrostContentViewport)).dy.round();
    expect(bytes![((top + 1) * 800 + 61) * 4 + 1], greaterThan(100));
    expect(bytes[((top + 20) * 800 + 80) * 4], 255);
    expect(bytes[((top + 20) * 800 + 80) * 4 + 1], 0);
  });
  testWidgets('compact desktop tiles use a 36-high row', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(frostTestApp(shell(expanded: true), density: FrostDensity.compact));
    final click = find.descendant(of: find.byType(FrostNavItem), matching: find.byType(FrostClickSurface));
    expect(tester.getSize(click).height, 36);
  });
  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    for (final caption in [false, true]) {
      testWidgets('brand shows only in a title row with window buttons on $platform, caption=$caption', (tester) async {
        tester.view.physicalSize = const Size(1400, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          frostTestApp(
            FrostWindowCaptionScope(
              window: caption ? FakeWindow() : null,
              child: shell(expanded: true, brand: const Text('Capability brand'), alignment: FrostSidebarAlignment.top),
            ),
            platform: platform,
          ),
        );
        // The brand is in a title row with window buttons; a top bar without a window carries none.
        expect(find.text('Capability brand'), caption ? findsOneWidget : findsNothing);
        expect(findFrostTooltip('L.back'), findsOneWidget);
        if (!caption) {
          final back = tester.getRect(findFrostTooltip('L.back'));
          final first = tester.getRect(find.byType(FrostNavItem).first);
          expect(first.top, greaterThanOrEqualTo(back.bottom), reason: 'Back is in the top bar, not above the destinations');
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('sidebar spring starts without a jump and preserves content state across layout switches', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var initializations = 0;
    await tester.pumpWidget(
      frostTestApp(
        shell(child: _StateProbe(onInit: () => initializations++)),
        platform: TargetPlatform.android,
      ),
    );
    final before = tester.getTopLeft(find.byType(_StateProbe)).dx;
    await tester.tap(findFrostTooltip('L.expandNavigation'));
    await tester.pump();
    expect(tester.getTopLeft(find.byType(_StateProbe)).dx, before);
    await tester.pump(const Duration(milliseconds: 60));
    final during = tester.getTopLeft(find.byType(_StateProbe)).dx;
    expect(during, greaterThan(before));
    expect(during, lessThan(176));
    tester.view.physicalSize = const Size(500, 900);
    await tester.pump();
    expect(tester.getTopLeft(find.byType(_StateProbe)).dx, 0);
    expect(initializations, 1);
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.5]) {
    testWidgets('mobile ink, hit area and text growth scale=$scale', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        frostTestApp(
          Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale), padding: const EdgeInsets.only(bottom: 24)),
              child: shell(),
            ),
          ),
          platform: TargetPlatform.android,
        ),
      );
      expect(find.byType(FrostCaptionButtons), findsNothing);
      expect(find.byWidgetPredicate((w) => w is FrostSurface && (w.role == FrostSurfaceRole.base || w.role == FrostSurfaceRole.panel)), findsNothing);
      final bar = find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.chrome);
      final item = find.descendant(of: bar, matching: find.byType(FrostClickSurface));
      final tokens = FrostThemeTokens.of(tester.element(item));
      expect(tester.widget<Scaffold>(find.byType(Scaffold)).backgroundColor, tokens.canvas);
      expect(tester.getSize(item).height, greaterThanOrEqualTo(64));
      expect(tester.getSize(item).width, greaterThanOrEqualTo(44));
      expect(tester.getSize(bar).height, tester.getSize(item).height + 24);
      final icon = tester.widget<FrostIcon>(find.descendant(of: item, matching: find.byType(FrostIcon)));
      expect(icon.size, 24);
      expect(icon.color, tokens.selectionInk);
      final text = tester.widget<Text>(find.text('Home'));
      expect(text.style!.color, tokens.selectionInk);
      expect(text.style!.fontWeight, FontWeight.w500);
      expect(text.overflow, isNot(TextOverflow.ellipsis));
      expect(
        find.descendant(
          of: item,
          matching: find.byWidgetPredicate(
            (w) => w is DecoratedBox && w.decoration is ShapeDecoration && (w.decoration as ShapeDecoration).color == tokens.selectionFill,
          ),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });
  }
  for (final expanded in [false, true]) {
    testWidgets('tile geometry, selection and tooltip expanded=$expanded', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        frostTestApp(
          shell(
            expanded: expanded,
            child: const Scaffold(
              body: Column(children: [FrostPageHeader(title: Text('Page'))]),
            ),
          ),
        ),
      );
      final item = find.byType(FrostNavItem);
      final click = find.descendant(of: item, matching: find.byType(FrostClickSurface));
      final box = tester.getRect(click);
      final context = tester.element(click);
      final tokens = FrostThemeTokens.of(context);
      expect(box.height, expanded ? FrostDensity.of(context).targetHeight : 40);
      expect(box.width, expanded ? 160 : 40);
      expect(box.center.dx, expanded ? 88 : 30);
      expect(
        tester.widget<FrostClickFeedbackVisual>(find.descendant(of: click, matching: find.byType(FrostClickFeedbackVisual)).first).shape,
        FrostRadius.shape(context, expanded ? FrostRadius.sm : FrostRadius.md),
      );
      final fill = find.descendant(
        of: item,
        matching: find.byWidgetPredicate(
          (w) => w is DecoratedBox && w.decoration is BoxDecoration && (w.decoration as BoxDecoration).color == tokens.selectionFill,
        ),
      );
      expect(fill, findsOneWidget);
      expect(tester.widget<FrostIcon>(find.descendant(of: item, matching: find.byType(FrostIcon))).color, tokens.selectionInk);
      expect(find.descendant(of: item, matching: find.byType(FrostTooltip)), findsOneWidget);
      expect(find.byType(FrostCompactBackButton), findsNothing);
      expect(findFrostTooltip('L.back'), findsOneWidget);
      // Inset has no panel material wrapping its navigation items.
      final surfaces = find.ancestor(of: item, matching: find.byType(FrostSurface));
      expect(surfaces.evaluate().map((e) => (e.widget as FrostSurface).role), [FrostSurfaceRole.base]);
    });
  }
  for (final caption in [false, true]) {
    testWidgets('shell first frame caption=$caption: sheet, drag regions, single toggle and shell-owned back', (tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final window = FakeWindow();
      await tester.pumpWidget(
        frostTestApp(
          FrostWindowCaptionScope(
            window: caption ? window : null,
            child: shell(expanded: true, brand: const Text('Brand')),
          ),
        ),
      );
      final rect = tester.getRect(find.byKey(pageKey));
      expect(rect, Rect.fromLTRB(176, 40, 1400, 892));
      expect(findFrostTooltip('L.collapseNavigation'), findsOneWidget);
      expect(findFrostTooltip('L.back'), findsOneWidget);
      final scope = tester.widget<FrostShellNavigationScope>(find.byType(FrostShellNavigationScope));
      expect(scope.ownsBackControl, isTrue);
      final sheets = find.byWidgetPredicate((w) => w is FrostSurface && w.role == FrostSurfaceRole.panel);
      expect(sheets, findsOneWidget);
      final surface = tester.widget<FrostSurface>(sheets);
      expect(surface.borderRadius, BorderRadius.circular(FrostRadius.lg));
      expect(find.descendant(of: sheets, matching: find.byType(FrostKeyline)), findsWidgets);
      expect(find.descendant(of: sheets, matching: find.byType(ClipPath)), findsWidgets);
      if (caption) {
        expect(tester.getSize(find.byType(FrostCaptionButtons)).height, 40);
        final toggle = tester.getCenter(findFrostTooltip('L.collapseNavigation'));
        final brand = tester.getCenter(find.text('Brand'));
        final regions = window.calls.last.where((r) => r.kind == FrostHitKind.caption);
        expect(regions.any((r) => r.rect.contains(toggle)), isFalse);
        expect(regions.any((r) => r.rect.contains(brand)), isTrue);
        expect(regions.any((r) => r.rect.contains(const Offset(500, 20))), isTrue);
      } else {
        expect(find.byType(FrostCaptionButtons), findsNothing);
        expect(tester.getCenter(findFrostTooltip('L.collapseNavigation')).dy, greaterThan(800));
      }
      await tester.pump();
      expect(tester.getRect(find.byKey(pageKey)), rect);
      expect(tester.takeException(), isNull);
    });
  }
}

class _StateProbe extends StatefulWidget {
  const _StateProbe({required this.onInit});
  final VoidCallback onInit;
  @override
  State<_StateProbe> createState() => _StateProbeState();
}

class _StateProbeState extends State<_StateProbe> {
  @override
  void initState() {
    super.initState();
    widget.onInit();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.expand();
}
