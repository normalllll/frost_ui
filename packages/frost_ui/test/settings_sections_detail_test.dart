import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'package:frost_ui/src/navigation/_navigation_tile.dart';
import 'support.dart';

Finder _shellBack() => find.byKey(const ValueKey('frost-shell-back'));
bool _shellBackEnabled(WidgetTester tester) => switch (tester.widget(_shellBack())) {
  FrostButtonControl(:final onPressed) => onPressed != null,
  FrostButton(:final onPressed) => onPressed != null,
  _ => false,
};
Finder _tile(String label) => find.widgetWithText(FrostNavigationTile, label);

class _SectionBody extends StatefulWidget {
  const _SectionBody({required this.controller});
  final ScrollController controller;
  @override
  State<_SectionBody> createState() => _SectionBodyState();
}

class _SectionBodyState extends State<_SectionBody> {
  @override
  Widget build(BuildContext context) => ListView.builder(
    controller: widget.controller,
    itemCount: 80,
    itemBuilder: (_, index) => SizedBox(height: 40, child: Text('Source $index')),
  );
}

/// A settings page whose Sources section opens one source in place on wide
/// windows, as an App holds that state.
class _Settings extends StatefulWidget {
  const _Settings({required this.controller, required this.calls, this.initialDetail = false});
  final ScrollController controller;
  final List<String> calls;
  final bool initialDetail;
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  var _selected = 1;
  late var _detail = widget.initialDetail;
  void open() => setState(() => _detail = true);
  @override
  Widget build(BuildContext context) => FrostSettingsSections(
    header: const FrostPageHeader(title: Text('Settings')),
    labels: const ['Appearance', 'Sources'],
    selectedIndex: _selected,
    onSelected: (index) {
      widget.calls.add('select $index');
      setState(() => _selected = index);
    },
    sectionBuilder: (_, index) => index == 1 ? _SectionBody(controller: widget.controller) : const Text('Appearance rows'),
    detail: _detail ? FrostSectionsDetail(child: const Text('Source detail'), onClose: _close) : null,
  );

  void _close() {
    widget.calls.add('close');
    setState(() => _detail = false);
  }
}

Widget _shell(Widget child, {FrostNavigationPlacement? placement = FrostNavigationPlacement.sidebar}) => FrostShell(
  navigationPlacement: placement,
  destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.settings), label: 'Settings')],
  selectedIndex: 0,
  atDestinationRoot: true,
  onDestinationSelected: (_) {},
  canGoBack: false,
  onBack: () {},
  showsMobileNavigation: true,
  brand: const FrostShellBrand(expanded: Text('Brand')),
  child: child,
);

double _opacityAbove(WidgetTester tester, Finder finder) =>
    tester.widgetList<Opacity>(find.ancestor(of: finder, matching: find.byType(Opacity))).fold(1.0, (value, opacity) => value * opacity.opacity);

void main() {
  late ScrollController controller;
  setUp(() => controller = ScrollController());
  tearDown(() => controller.dispose());

  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  testWidgets('wide detail transitions only the pane and the shell Back closes it', (tester) async {
    viewport(tester, const Size(1280, 800));
    final calls = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        _shell(_Settings(controller: controller, calls: calls)),
        density: FrostDensity.compact,
      ),
    );
    await tester.pumpAndSettle();
    controller.jumpTo(400);
    await tester.pump();
    final section = tester.state(find.byType(_SectionBody));
    final column = tester.getRect(_tile('Sources'));
    expect(_shellBackEnabled(tester), isFalse);

    tester.state<_SettingsState>(find.byType(_Settings)).open();
    await tester.pump();
    await tester.pump(FrostMotion.page ~/ 2);
    // Mid-transition: the detail fades in over the section, while the
    // navigation column neither moves nor fades.
    expect(_opacityAbove(tester, find.text('Source detail')), inExclusiveRange(0, 1));
    expect(_opacityAbove(tester, find.text('Source 10')), lessThan(1));
    expect(tester.getRect(_tile('Sources')), column);
    expect(_opacityAbove(tester, _tile('Sources')), 1);
    await tester.pumpAndSettle();
    expect(find.text('Source detail'), findsOneWidget);
    expect(find.text('Source 10'), findsNothing, reason: 'the covered section is offstage');
    expect(tester.getRect(_tile('Sources')), column);
    expect(_shellBackEnabled(tester), isTrue);

    await tester.tap(_shellBack());
    await tester.pump();
    expect(calls, ['close']);
    await tester.pump(FrostMotion.exit ~/ 2);
    expect(_opacityAbove(tester, find.text('Source detail')), inExclusiveRange(0, 1));
    await tester.pumpAndSettle();
    expect(find.text('Source detail'), findsNothing);
    expect(identical(tester.state(find.byType(_SectionBody)), section), isTrue);
    expect(controller.offset, 400);
    expect(_shellBackEnabled(tester), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choosing a section closes the detail before selecting it', (tester) async {
    viewport(tester, const Size(1280, 800));
    final calls = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        _shell(_Settings(controller: controller, calls: calls, initialDetail: true)),
        density: FrostDensity.compact,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Source detail'), findsOneWidget);
    await tester.tap(_tile('Appearance'));
    await tester.pumpAndSettle();
    expect(calls, ['close', 'select 0']);
    expect(find.text('Appearance rows'), findsOneWidget);
    expect(find.text('Source detail'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('system back closes the wide detail instead of leaving the page', (tester) async {
    viewport(tester, const Size(1280, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_Settings(controller: controller, calls: calls, initialDetail: true)));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls, ['close']);
    expect(find.text('Source detail'), findsNothing);
    expect(find.text('Source 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final standalone in [false, true]) {
    testWidgets('without a shell-owned Back the header offers it for the detail (standalone=$standalone)', (tester) async {
      viewport(tester, const Size(1280, 800));
      final calls = <String>[];
      final page = _Settings(controller: controller, calls: calls, initialDetail: true);
      await tester.pumpWidget(frostTestApp(standalone ? page : _shell(page, placement: FrostNavigationPlacement.bottom), platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      expect(_shellBack(), findsNothing);
      expect(find.byType(FrostCompactBackButton), findsOneWidget);
      await tester.tap(find.byType(FrostCompactBackButton));
      await tester.pumpAndSettle();
      expect(calls, ['close']);
      expect(find.byType(FrostCompactBackButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('narrow windows never show the detail and leave Back to the route', (tester) async {
    viewport(tester, const Size(560, 800));
    final calls = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        _shell(_Settings(controller: controller, calls: calls, initialDetail: true)),
        density: FrostDensity.compact,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Source detail'), findsNothing);
    expect(_shellBackEnabled(tester), isFalse);
    expect(find.byType(FrostCompactBackButton), findsNothing);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion opens and closes the detail without a transition', (tester) async {
    viewport(tester, const Size(1280, 800));
    final calls = <String>[];
    await tester.pumpWidget(
      frostTestApp(
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: _Settings(controller: controller, calls: calls),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    tester.state<_SettingsState>(find.byType(_Settings)).open();
    await tester.pump();
    await tester.pump();
    expect(_opacityAbove(tester, find.text('Source detail')), 1);
    expect(find.text('Source 0'), findsNothing);
    await tester.binding.handlePopRoute();
    await tester.pump();
    await tester.pump();
    expect(find.text('Source detail'), findsNothing);
    expect(find.text('Source 0'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
