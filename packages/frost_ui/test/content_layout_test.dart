import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'support.dart';

class _Identity extends StatefulWidget {
  const _Identity({required this.created, required this.disposed, required this.label});
  final VoidCallback created, disposed;
  final String label;
  @override
  State<_Identity> createState() => _IdentityState();
}

class _IdentityState extends State<_Identity> {
  @override
  void initState() {
    super.initState();
    widget.created();
  }

  @override
  void dispose() {
    widget.disposed();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(height: 180, child: Text(widget.label));
}

void main() {
  void size(WidgetTester tester, Size value) {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Widget app(Widget child, {double textScale = 1, TextDirection direction = TextDirection.ltr}) => frostTestApp(
    Directionality(
      textDirection: direction,
      child: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );

  for (final (viewport, textScale, beside) in [
    (const Size(1600, 900), 1.0, true),
    (const Size(1200, 1100), 1.0, false),
    (const Size(900, 600), 1.0, false),
    (const Size(390, 800), 1.0, false),
    (const Size(1600, 360), 1.0, false),
    (const Size(1600, 900), 2.0, false),
    (const Size(2600, 1500), 2.0, true),
  ]) {
    testWidgets('content follows actual space and reading size: $viewport scale=$textScale', (tester) async {
      size(tester, viewport);
      await tester.pumpWidget(
        app(
          const FrostContentLayout(
            slivers: [
              SliverToBoxAdapter(child: SizedBox(key: ValueKey('media'), height: 100)),
              SliverToBoxAdapter(child: SizedBox(key: ValueKey('discussion'), height: 80)),
            ],
            auxiliarySlivers: [SliverToBoxAdapter(child: SizedBox(key: ValueKey('auxiliary'), height: 120))],
          ),
          textScale: textScale,
        ),
      );
      await tester.pumpAndSettle();
      final media = tester.getRect(find.byKey(const ValueKey('media')));
      final discussion = tester.getRect(find.byKey(const ValueKey('discussion')));
      final auxiliary = tester.getRect(find.byKey(const ValueKey('auxiliary')));
      expect(discussion.top, media.bottom);
      expect(find.byType(SliverCrossAxisGroup), beside ? findsOneWidget : findsNothing);
      if (beside) {
        expect(auxiliary.top, media.top);
        expect(auxiliary.left, greaterThan(media.right));
        expect(media.width, greaterThan(auxiliary.width));
      } else {
        expect(auxiliary.top, greaterThan(discussion.bottom));
        expect(auxiliary.left, media.left);
        expect(auxiliary.width, media.width);
      }
      expect(find.byType(Scrollable), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('local constraints decide layout even under a wider window', (tester) async {
    size(tester, const Size(1800, 1000));
    await tester.pumpWidget(
      app(
        const Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 900,
            height: 700,
            child: FrostContentLayout(
              slivers: [SliverToBoxAdapter(child: SizedBox(height: 100))],
              auxiliarySlivers: [SliverToBoxAdapter(child: SizedBox(height: 100))],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SliverCrossAxisGroup), findsNothing);
    expect(tester.getSize(find.byType(Viewport)), const Size(900, 700));
    expect(tester.takeException(), isNull);
  });

  testWidgets('pinned chrome stays outside one viewport and aligns both flows below its measured height', (tester) async {
    size(tester, const Size(1600, 900));
    await tester.pumpWidget(
      app(
        const FrostPinnedChrome(
          chrome: SizedBox(height: 52),
          body: FrostContentLayout(
            slivers: [SliverToBoxAdapter(child: SizedBox(key: ValueKey('primary'), height: 1200))],
            auxiliarySlivers: [SliverToBoxAdapter(child: SizedBox(key: ValueKey('auxiliary'), height: 1500))],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(find.byKey(const ValueKey('primary'))).top, 52);
    expect(tester.getRect(find.byKey(const ValueKey('auxiliary'))).top, 52);
    expect(tester.getRect(find.byType(Viewport)).right, 1600);
    expect(find.byType(Scrollable), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keyboard-obscured height and an absent auxiliary flow do not force columns or leave a gap', (tester) async {
    size(tester, const Size(1600, 900));
    final controller = ScrollController();
    Widget flow(List<Widget> auxiliary) => FrostContentLayout(
      controller: controller,
      slivers: const [SliverToBoxAdapter(child: SizedBox(height: 100))],
      auxiliarySlivers: auxiliary,
    );
    await tester.pumpWidget(
      app(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(viewInsets: const EdgeInsets.only(bottom: 600)),
            child: flow(const [SliverToBoxAdapter(child: SizedBox(height: 100))]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SliverCrossAxisGroup), findsNothing);
    await tester.pumpWidget(app(flow(const [])));
    await tester.pumpAndSettle();
    expect(find.byType(SliverCrossAxisGroup), findsNothing);
    expect(controller.position.maxScrollExtent, 0);
    await tester.pumpWidget(
      app(
        FrostContentLayout(
          controller: controller,
          slivers: const [],
          auxiliarySlivers: const [SliverToBoxAdapter(child: SizedBox(height: 100))],
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(SliverCrossAxisGroup), findsNothing);
    expect(controller.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });
  testWidgets('media and auxiliary identity, lazy construction and one ScrollPosition survive rearrangement', (tester) async {
    size(tester, const Size(1600, 900));
    final controller = ScrollController();
    var mediaCreated = 0, auxiliaryCreated = 0, disposed = 0;
    var primaryBuilds = 0, auxiliaryBuilds = 0;
    await tester.pumpWidget(
      app(
        FrostContentLayout(
          controller: controller,
          slivers: [
            SliverToBoxAdapter(
              child: _Identity(label: 'Live media', created: () => mediaCreated++, disposed: () => disposed++),
            ),
            SliverFixedExtentList(
              itemExtent: 60,
              delegate: SliverChildBuilderDelegate((_, index) {
                primaryBuilds++;
                return Text('Primary $index');
              }, childCount: 1000),
            ),
          ],
          auxiliarySlivers: [
            SliverToBoxAdapter(
              child: _Identity(label: 'Auxiliary state', created: () => auxiliaryCreated++, disposed: () => disposed++),
            ),
            SliverFixedExtentList(
              itemExtent: 60,
              delegate: SliverChildBuilderDelegate((_, index) {
                auxiliaryBuilds++;
                return Text('Auxiliary $index');
              }, childCount: 500),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final states = tester.stateList<_IdentityState>(find.byType(_Identity, skipOffstage: false)).toList();
    final position = controller.position;
    controller.jumpTo(600);
    await tester.pumpAndSettle();
    for (final viewport in [const Size(900, 800), const Size(1600, 900), const Size(1200, 1100), const Size(1600, 900)]) {
      tester.view.physicalSize = viewport;
      await tester.pumpAndSettle();
      expect(controller.position, same(position));
      expect(controller.offset, 600);
      expect(tester.stateList<_IdentityState>(find.byType(_Identity, skipOffstage: false)), orderedEquals(states));
      expect(mediaCreated, 1);
      expect(auxiliaryCreated, 1);
    }
    expect(primaryBuilds, lessThan(200));
    expect(auxiliaryBuilds, lessThan(200));
    expect(disposed, 0);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(disposed, 2);
    controller.dispose();
  });

  testWidgets('an auxiliary reading offset maps between trailing and side layouts instead of clamping to a different item', (tester) async {
    size(tester, const Size(900, 800));
    final controller = ScrollController();
    await tester.pumpWidget(
      app(
        FrostContentLayout(
          controller: controller,
          slivers: const [SliverToBoxAdapter(child: SizedBox(key: ValueKey('primary-flow-box'), height: 2000))],
          auxiliarySlivers: [
            SliverFixedExtentList(
              itemExtent: 60,
              delegate: SliverChildBuilderDelegate((_, index) => SizedBox(key: ValueKey('aux-$index'), child: Text('Auxiliary $index')), childCount: 60),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(2000 + FrostGap.of(tester.element(find.byType(FrostContentLayout))).section + 1000);
    await tester.pumpAndSettle();
    final top = tester.getTopLeft(find.byKey(const ValueKey('aux-18'))).dy;
    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpAndSettle();
    expect(controller.offset, 1000);
    expect(tester.getTopLeft(find.byKey(const ValueKey('aux-18'))).dy, top);
    tester.view.physicalSize = const Size(900, 800);
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byKey(const ValueKey('aux-18'))).dy, top);
    tester.view.physicalSize = const Size(1600, 900);
    await tester.pumpAndSettle();
    final primary = tester.getRect(find.byKey(const ValueKey('primary-flow-box')));
    await tester.sendEventToBinding(PointerScrollEvent(position: Offset(primary.center.dx, 450), scrollDelta: const Offset(0, 60)));
    await tester.pumpAndSettle();
    final primaryOffset = controller.offset;
    tester.view.physicalSize = const Size(900, 800);
    await tester.pumpAndSettle();
    expect(controller.offset, primaryOffset);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    controller.dispose();
  });

  testWidgets('focused auxiliary content stays mounted and is revealed after it moves below the primary flow', (tester) async {
    size(tester, const Size(1600, 900));
    final focus = FocusNode();
    final editing = TextEditingController(text: 'Retained');
    final controller = ScrollController();
    await tester.pumpWidget(
      app(
        FrostContentLayout(
          controller: controller,
          slivers: const [SliverToBoxAdapter(child: SizedBox(height: 1400))],
          auxiliarySlivers: [
            SliverToBoxAdapter(
              child: TextField(focusNode: focus, controller: editing),
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
    final field = tester.element(find.byType(TextField));
    focus.requestFocus();
    await tester.pump();
    for (final viewport in [const Size(900, 800), const Size(1600, 900)]) {
      tester.view.physicalSize = viewport;
      await tester.pumpAndSettle();
      expect(focus.hasPrimaryFocus, true);
      expect(tester.element(find.byType(TextField)), same(field));
      expect(editing.text, 'Retained');
      final rect = tester.getRect(find.byType(TextField));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(viewport.height));
    }
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    focus.dispose();
    editing.dispose();
    controller.dispose();
  });


  for (final direction in TextDirection.values) {
    testWidgets('scrollbar remains at physical right and auxiliary order is stable in $direction', (tester) async {
      size(tester, const Size(1600, 900));
      final controller = ScrollController();
      await tester.pumpWidget(
        app(
          FrostContentLayout(
            controller: controller,
            slivers: const [SliverToBoxAdapter(child: SizedBox(key: ValueKey('primary'), height: 3000))],
            auxiliarySlivers: const [SliverToBoxAdapter(child: SizedBox(key: ValueKey('auxiliary'), height: 3000))],
          ),
          direction: direction,
        ),
      );
      await tester.pumpAndSettle();
      final viewport = tester.getRect(find.byType(Viewport));
      expect(viewport.left, 0);
      expect(viewport.right, 1600);
      expect(tester.widget<Scrollbar>(find.byType(Scrollbar)).scrollbarOrientation, ScrollbarOrientation.right);
      expect(tester.getRect(find.byKey(const ValueKey('auxiliary'))).left, greaterThan(tester.getRect(find.byKey(const ValueKey('primary'))).right));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
