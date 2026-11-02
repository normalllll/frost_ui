import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/_button_control.dart';
import 'support.dart';

Finder _shellBack() => find.byKey(const ValueKey('frost-shell-back'));
bool _shellBackEnabled(WidgetTester tester) => switch (tester.widget(_shellBack())) {
  FrostButtonControl(:final onPressed) => onPressed != null,
  FrostButton(:final onPressed) => onPressed != null,
  _ => false,
};

/// A settings page that opens a section in place on narrow layouts, as an App
/// holds that state instead of pushing a route.
class _Settings extends StatefulWidget {
  const _Settings({required this.calls, this.closes = true});
  final List<String> calls;
  final bool closes;
  @override
  State<_Settings> createState() => _SettingsState();
}

class _SettingsState extends State<_Settings> {
  var _open = true;
  @override
  Widget build(BuildContext context) => FrostSettingsSections(
    header: const FrostPageHeader(title: Text('Settings')),
    labels: const ['Appearance', 'Sources'],
    selectedIndex: 1,
    onSelected: (_) => setState(() => _open = true),
    sectionBuilder: (_, _) => const Text('Wide section'),
    compact: FrostSectionsCompact(
      section: _open
          ? const Column(
              children: [
                FrostPageHeader(title: Text('Sources')),
                Expanded(child: Text('Section page')),
              ],
            )
          : null,
      onClose: widget.closes
          ? () {
              widget.calls.add('close');
              setState(() => _open = false);
            }
          : null,
    ),
  );
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

void main() {
  void viewport(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));
  }

  testWidgets('narrow: the shell Back closes the routed section', (tester) async {
    viewport(tester, const Size(560, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_shell(_Settings(calls: calls)), density: FrostDensity.compact));
    await tester.pumpAndSettle();
    expect(find.text('Section page'), findsOneWidget);
    expect(_shellBackEnabled(tester), isTrue);
    await tester.tap(_shellBack());
    await tester.pumpAndSettle();
    expect(calls, ['close']);
    expect(find.text('Section page'), findsNothing);
    expect(find.text('Sources'), findsOneWidget, reason: 'back on the narrow navigation');
    expect(_shellBackEnabled(tester), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow: system back closes the routed section', (tester) async {
    viewport(tester, const Size(560, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_Settings(calls: calls)));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls, ['close']);
    expect(find.text('Section page'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final standalone in [false, true]) {
    testWidgets('narrow without a shell-owned Back: the section header offers Back (standalone=$standalone)', (tester) async {
      viewport(tester, const Size(560, 800));
      final calls = <String>[];
      final page = _Settings(calls: calls);
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

  testWidgets('wide: the section stays a pane and Back is not wired', (tester) async {
    viewport(tester, const Size(1280, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_shell(_Settings(calls: calls)), density: FrostDensity.compact));
    await tester.pumpAndSettle();
    expect(find.text('Section page'), findsNothing);
    expect(_shellBackEnabled(tester), isFalse);
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(calls, isEmpty);
  });

  testWidgets('Back follows the layout across wide and narrow changes', (tester) async {
    viewport(tester, const Size(1280, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_shell(_Settings(calls: calls)), density: FrostDensity.compact));
    await tester.pumpAndSettle();
    expect(_shellBackEnabled(tester), isFalse);
    tester.view.physicalSize = const Size(560, 800);
    await tester.pumpAndSettle();
    expect(_shellBackEnabled(tester), isTrue);
    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(_shellBackEnabled(tester), isFalse);
    expect(calls, isEmpty);
  });

  testWidgets('without onClose a routed section leaves Back to the app routes', (tester) async {
    viewport(tester, const Size(560, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_shell(_Settings(calls: calls, closes: false)), density: FrostDensity.compact));
    await tester.pumpAndSettle();
    expect(find.text('Section page'), findsOneWidget);
    expect(_shellBackEnabled(tester), isFalse);
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(calls, isEmpty);
  });
}
