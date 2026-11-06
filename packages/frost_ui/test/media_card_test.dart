import 'dart:ui' show Tristate;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';
import 'package:frost_ui/src/media/media_card.dart';
import 'support.dart';

const _picture = FrostMediaImage(
  child: SizedBox(height: 120, child: ColoredBox(color: Colors.red)),
);
Finder get _card => find.byType(FrostMediaCard);
Finder get _surface => find.descendant(of: _card, matching: find.byType(FrostClickSurface)).first;
List<double> _scales(WidgetTester tester, Finder root) => tester
    .renderObjectList<RenderTransform>(
      find.descendant(of: root, matching: find.byElementPredicate((e) => e is RenderObjectElement && e.renderObject is RenderTransform)),
    )
    .map((r) => r.child!.getTransformTo(r).storage[0])
    .toList();
List<ShapeDecoration> _shapes(WidgetTester tester, Finder root) => tester
    .renderObjectList<RenderDecoratedBox>(find.descendant(of: root, matching: find.byType(DecoratedBox)))
    .map((w) => w.decoration)
    .whereType<ShapeDecoration>()
    .toList();

Widget _host(Widget child, {bool rtl = false, bool reduced = false}) => frostTestApp(
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
      child: Directionality(
        textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
        child: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(width: 200, child: child),
            ),
          ),
        ),
      ),
    ),
  ),
  density: FrostDensity.compact,
);

void main() {
  testWidgets('nested media frame has one physical stroke and RTL keeps check beside corner action', (tester) async {
    await tester.pumpWidget(
      _host(
        FrostMediaCard(
          media: const FrostMediaFrame(child: _picture),
          selected: true,
          topEnd: const SizedBox(key: ValueKey('end-slot'), width: 35, height: 30),
          onPressed: () {},
        ),
        rtl: true,
      ),
    );
    // The card owns the one stroke; the nested frame paints none.
    expect(innerStrokes(tester, _card).where((s) => s.draws > 0), hasLength(1));
    final circle = tester.getRect(find.byWidgetPredicate((w) => w is SizedBox && w.width == 20 && w.height == 20));
    final slot = tester.getRect(find.byKey(const ValueKey('end-slot')));
    expect(circle.left - slot.right, 8);
    expect(tester.takeException(), isNull);
  });
  testWidgets('thumbnail selection ring interpolates and honors reduced motion', (tester) async {
    for (final reduced in [false, true]) {
      late StateSetter update;
      var selected = false;
      await tester.pumpWidget(
        _host(
          StatefulBuilder(
            builder: (_, set) {
              update = set;
              return Align(
                alignment: Alignment.topLeft,
                child: FrostThumbnail(image: _picture, semanticLabel: 'Preview', selected: selected, onPressed: () {}),
              );
            },
          ),
          reduced: reduced,
        ),
      );
      update(() => selected = true);
      await tester.pump();
      await tester.pump(FrostMotion.hover ~/ 2);
      final ring = _shapes(tester, find.byType(FrostThumbnail)).map((s) => s.shape).whereType<OutlinedBorder>().singleWhere((s) => s.side.width == 2);
      if (reduced) {
        expect(ring.side.color.a, closeTo(.65, 1e-6));
      } else {
        expect(ring.side.color.a, inExclusiveRange(0, .65));
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    }
  });
  testWidgets('media card corners mirror, framing is physical and footer follows the media', (tester) async {
    for (final rtl in [false, true]) {
      await tester.pumpWidget(
        _host(
          const FrostMediaCard(
            media: _picture,
            topStart: SizedBox(key: ValueKey('ts'), width: 15, height: 10),
            topEnd: SizedBox(key: ValueKey('te'), width: 15, height: 10),
            bottomStart: SizedBox(key: ValueKey('bs'), width: 15, height: 10),
            bottomEnd: SizedBox(key: ValueKey('be'), width: 15, height: 10),
            footer: SizedBox(key: ValueKey('footer'), height: 30),
          ),
          rtl: rtl,
        ),
      );
      final origin = tester.getTopLeft(_surface);
      expect(tester.getSize(_surface), const Size(200, 158));
      for (final corner in ['ts', 'te', 'bs', 'be']) {
        final start = corner.endsWith('s');
        final top = corner.startsWith('t');
        final position = tester.getTopLeft(find.byKey(ValueKey(corner))) - origin;
        expect(position, Offset((start != rtl) ? (top && start ? 6 : 8) : (top && start ? 179 : 177), top ? (start ? 6 : 8) : 102));
      }
      expect(tester.getTopLeft(find.byKey(const ValueKey('footer'))).dy - origin.dy, 128);
      final stroke = innerStrokes(tester, _card).single;
      expect(stroke.draws, 1);
      expect((stroke.shape as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.sm);
      expect(stroke.width, closeTo(1 / tester.view.devicePixelRatio, 1e-9));
      expect(stroke.color, FrostThemeTokens.of(tester.element(_card)).mediaInnerStroke);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('media hover zooms only the image; card and footer remain still on press', (tester) async {
    await tester.pumpWidget(_host(FrostMediaCard(media: _picture, footer: const Text('Footer'), onPressed: () {})));
    final footerBefore = tester.getRect(find.text('Footer'));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_surface));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80));
    expect(_scales(tester, _surface).any((s) => s > 1 && s < 1.03), isTrue);
    await tester.pumpAndSettle();
    expect(_scales(tester, _surface), contains(closeTo(1.03, .0001)));
    expect(tester.getRect(find.text('Footer')), footerBefore);
    await mouse.down(tester.getCenter(_surface));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    expect(_scales(tester, _surface).every((s) => s >= 1), isTrue);
    expect(tester.getRect(find.text('Footer')), footerBefore);
    await mouse.up();
    await mouse.removePointer();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final footer in [false, true]) {
    testWidgets('hover leaves the text below the image in its own ink footer=$footer', (tester) async {
      await tester.pumpWidget(
        _host(
          FrostMediaCard(
            media: _picture,
            title: footer ? null : 'Sample work',
            footer: footer ? const FrostText('Sample work', role: FrostTextRole.subheadline) : null,
            onPressed: () {},
          ),
        ),
      );
      Color? ink() => tester.renderObject<RenderParagraph>(find.text('Sample work')).text.style?.color;
      final before = ink();
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: Offset.zero);
      await mouse.moveTo(tester.getCenter(_surface));
      await tester.pumpAndSettle();
      expect(_scales(tester, _surface), contains(closeTo(FrostMetrics.mediaHoverZoom, .0001)));
      expect(ink(), before);
      expect(ink(), isNot(FrostThemeTokens.of(tester.element(_card)).accentInk));
      await mouse.removePointer();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('selection circle never overlaps topEnd, ring and check animate, null removes selection semantics', (tester) async {
    final semantics = tester.ensureSemantics();
    late StateSetter update;
    bool? selected = false;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, set) {
            update = set;
            return FrostMediaCard(
              media: _picture,
              selected: selected,
              semanticLabel: 'Card',
              topEnd: const SizedBox(key: ValueKey('corner'), width: 35, height: 30),
              onPressed: () {},
            );
          },
        ),
      ),
    );
    final origin = tester.getTopLeft(_surface);
    final outline = tester
        .widgetList<CustomPaint>(find.descendant(of: _card, matching: find.byType(CustomPaint)))
        .map((w) => w.painter)
        .whereType<FrostMediaSelectionCirclePainter>()
        .singleWhere((p) => p.outline != null);
    expect(outline.fill, FrostThemeTokens.of(tester.element(_card)).onMediaScrim);
    expect(outline.outline, FrostThemeTokens.of(tester.element(_card)).onMediaInk);
    // Actual 1.5-width antialiased canvas geometry is covered by the circle antialias test.
    final circle = tester.getRect(find.byWidgetPredicate((w) => w is SizedBox && w.width == 20 && w.height == 20));
    final corner = tester.getRect(find.byKey(const ValueKey('corner')));
    expect(corner.left - circle.right, 8);
    expect(corner.right - origin.dx, 192);
    expect(tester.getSemantics(find.bySemanticsLabel('Card')).getSemanticsData().flagsCollection.isSelected, Tristate.isFalse);
    update(() => selected = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 70));
    final ring = _shapes(tester, _card).map((s) => s.shape).whereType<RoundedSuperellipseBorder>().singleWhere((s) => s.side.width == 3);
    expect(ring.side.color.a, inExclusiveRange(0, 1));
    expect(ring.side.strokeAlign, BorderSide.strokeAlignOutside);
    expect(_scales(tester, _card).any((s) => s > .92 && s < 1), isTrue);
    await tester.pumpAndSettle();
    expect(tester.getSemantics(find.bySemanticsLabel('Card')).getSemanticsData().flagsCollection.isSelected, Tristate.isTrue);
    update(() => selected = null);
    await tester.pumpAndSettle();
    expect(find.byType(FrostIcon), findsNothing);
    expect(tester.getSemantics(find.bySemanticsLabel('Card')).getSemanticsData().flagsCollection.isSelected, Tristate.none);
    semantics.dispose();
  });

  testWidgets('corner controls retain independent semantics, activation and focus; card supports context menu', (tester) async {
    final semantics = tester.ensureSemantics();
    var cardCalls = 0, cornerCalls = 0;
    await tester.pumpWidget(
      _host(
        FrostMediaCard(
          media: _picture,
          semanticLabel: 'Open image',
          onPressed: () => cardCalls++,
          topEnd: FrostButton.icon(label: 'Save', icon: testIcons.download, onPressed: () => cornerCalls++),
          contextMenu: [FrostMenuAction('Inspect', onSelected: () {})],
        ),
      ),
    );
    await tester.tap(find.byType(FrostButton));
    await tester.pumpAndSettle();
    expect(cornerCalls, 1);
    expect(cardCalls, 0);
    expect(find.bySemanticsLabel('Save'), findsWidgets);
    final cardNode = tester.widget<Focus>(find.descendant(of: _surface, matching: find.byType(Focus)).first).focusNode!;
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    cardNode.requestFocus();
    await tester.pump();
    expect(
      find.descendant(
        of: _surface,
        matching: find.byWidgetPredicate(
          (w) => w is CustomPaint && w.foregroundPainter != null && w.foregroundPainter.runtimeType.toString() != '_InnerStrokePainter',
        ),
      ),
      findsOneWidget,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(cardCalls, 1);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
    await mouse.down(tester.getTopLeft(_surface) + const Offset(30, 80));
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.text('Inspect'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('media skeleton matches explicit ratio and footer geometry', (tester) async {
    await tester.pumpWidget(_host(FrostMediaCard.skeleton(aspectRatio: 2, footer: '000000000000')));
    final skeleton = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_SkeletonMediaCard');
    final skeletonSize = tester.getSize(skeleton);
    final frame = find.byType(FrostMediaFrame).first;
    expect(tester.getSize(frame), const Size(200, 100));
    final titleHeight = tester.getSize(find.text('000000000000')).height;
    expect(skeletonSize.height, 100 + 8 + titleHeight);
    await tester.pumpWidget(
      _host(
        FrostMediaCard(
          media: _picture,
          aspectRatio: 2,
          footer: const FrostText('000000000000', role: FrostTextRole.subheadline, numeric: true, maxLines: 1),
        ),
      ),
    );
    expect(tester.getSize(_card), skeletonSize);
    await tester.pumpWidget(_host(SingleChildScrollView(child: FrostMediaCard.skeleton(aspectRatio: 1, footer: null))));
    expect(tester.getSize(find.byType(FrostMediaFrame).first), const Size(200, 200));
    await tester.pumpWidget(_host(SizedBox(height: 170, child: FrostMediaCard.skeleton(aspectRatio: null, footer: '000000000000'))));
    expect(tester.getSize(find.byType(FrostMediaFrame).first).height, closeTo(170 - 8 - titleHeight, .01));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('media press and hover reach endpoints immediately with reduced motion', (tester) async {
    await tester.pumpWidget(_host(FrostMediaCard(media: _picture, selected: true, onPressed: () {}), reduced: true));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(_surface));
    await tester.pump();
    expect(_scales(tester, _surface), contains(1.03));
    await mouse.down(tester.getCenter(_surface));
    await tester.pump();
    expect(_scales(tester, _surface).every((s) => s >= 1), isTrue);
    await mouse.up();
    await mouse.removePointer();
    expect(tester.takeException(), isNull);
  });

  testWidgets('thumbnail sizes, radii and outside ring share media input feedback', (tester) async {
    for (final (size, extent) in [(FrostThumbnailSize.small, 48.0), (FrostThumbnailSize.regular, 64.0), (FrostThumbnailSize.large, 96.0)]) {
      await tester.pumpWidget(
        _host(
          Align(
            alignment: Alignment.topLeft,
            child: FrostThumbnail(
              image: const FrostMediaImage(child: ColoredBox(color: Colors.red)),
              size: size,
              selected: true,
              semanticLabel: 'Preview',
              onPressed: () {},
            ),
          ),
        ),
      );
      final thumb = find.byType(FrostThumbnail);
      expect(tester.getSize(thumb), Size.square(extent));
      final shapes = _shapes(tester, thumb);
      final boundary = innerStrokes(tester, thumb).single.shape as RoundedSuperellipseBorder;
      // Row thumbnails keep the fixed row radius at every extent.
      expect(boundary.borderRadius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.xs);
      final ring = shapes.map((s) => s.shape).whereType<RoundedSuperellipseBorder>().singleWhere((s) => s.side.width == 2);
      expect(ring.borderRadius.resolve(TextDirection.ltr).topLeft.x, FrostRadius.xs + 2);
      expect(ring.side.color, FrostThemeTokens.of(tester.element(thumb)).actionFill.withValues(alpha: .65));
      expect(ring.side.strokeAlign, BorderSide.strokeAlignOutside);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('task-row thumbnails share the media-row cover radius', (tester) async {
    double boundaryRadius(Finder root) =>
        (innerStrokes(tester, root).firstWhere((s) => s.draws > 0).shape as RoundedSuperellipseBorder).borderRadius.resolve(TextDirection.ltr).topLeft.x;
    await tester.pumpWidget(
      _host(
        Column(
          children: [
            FrostTaskRow(
              title: 'Task',
              status: FrostTaskStatus.running,
              thumbnail: const FrostThumbnail(
                image: FrostMediaImage(child: ColoredBox(color: Colors.red)),
                size: FrostThumbnailSize.small,
                semanticLabel: 'Task',
              ),
            ),
            FrostMediaRow(
              media: const FrostMediaImage(child: ColoredBox(color: Colors.red)),
              title: 'Media',
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
    final cover = find.descendant(of: find.byType(FrostMediaRow), matching: find.byType(FrostMediaCard));
    expect(boundaryRadius(find.byType(FrostThumbnail)), boundaryRadius(cover));
    expect(boundaryRadius(find.byType(FrostThumbnail)), FrostRadius.xs);
    expect(tester.takeException(), isNull);
  });
}
