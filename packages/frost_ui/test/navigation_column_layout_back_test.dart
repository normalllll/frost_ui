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

/// A repository page as an App holds it: the selection and whether its detail
/// page is open.
class _Repositories extends StatefulWidget {
  const _Repositories({required this.calls, this.initiallyOpen = true});
  final List<String> calls;
  final bool initiallyOpen;
  @override
  State<_Repositories> createState() => _RepositoriesState();
}

class _RepositoriesState extends State<_Repositories> {
  late var _open = widget.initiallyOpen;
  void open() => setState(() => _open = true);
  @override
  Widget build(BuildContext context) => FrostNavigationColumnLayout(
    header: const FrostPageHeader(title: Text('Repositories')),
    navigationBuilder: (_) => ListView(
      children: [FrostListRow(title: 'gitbound', onPressed: open)],
    ),
    content: const Text('Wide detail'),
    compactPage: _open
        ? FrostNavigationColumnPage(
            onClose: () {
              widget.calls.add('close');
              setState(() => _open = false);
            },
            child: const Column(
              children: [
                FrostPageHeader(title: Text('gitbound')),
                Expanded(child: Text('Detail page')),
              ],
            ),
          )
        : null,
  );
}

Widget _shell(Widget child, {FrostNavigationPlacement? placement = FrostNavigationPlacement.sidebar}) => FrostShell(
  navigationPlacement: placement,
  destinations: const [FrostNavDestination(icon: FrostIconData.glyph(Icons.folder), label: 'Repositories')],
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

  testWidgets('narrow: the shell Back closes the detail page and returns to the column', (tester) async {
    viewport(tester, const Size(560, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_shell(_Repositories(calls: calls)), density: FrostDensity.compact));
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);
    expect(_shellBackEnabled(tester), isTrue);
    await tester.tap(_shellBack());
    await tester.pumpAndSettle();
    expect(calls, ['close']);
    expect(find.text('Detail page'), findsNothing);
    expect(find.text('gitbound'), findsOneWidget);
    expect(_shellBackEnabled(tester), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow: system back closes the detail page instead of leaving the app route', (tester) async {
    viewport(tester, const Size(560, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_Repositories(calls: calls)));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(calls, ['close']);
    expect(find.text('Detail page'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final standalone in [false, true]) {
    testWidgets('narrow without a shell-owned Back: the page header offers Back (standalone=$standalone)', (tester) async {
      viewport(tester, const Size(560, 800));
      final calls = <String>[];
      final page = _Repositories(calls: calls);
      await tester.pumpWidget(frostTestApp(standalone ? page : _shell(page, placement: FrostNavigationPlacement.bottom), platform: TargetPlatform.android));
      await tester.pumpAndSettle();
      expect(_shellBack(), findsNothing);
      expect(find.byType(FrostCompactBackButton), findsOneWidget);
      await tester.tap(find.byType(FrostCompactBackButton));
      await tester.pumpAndSettle();
      expect(calls, ['close']);
      // The column's root header has no Back.
      expect(find.byType(FrostCompactBackButton), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('wide: the open page is not shown and root Back stays disabled', (tester) async {
    viewport(tester, const Size(1280, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_shell(_Repositories(calls: calls)), density: FrostDensity.compact));
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsNothing);
    expect(find.text('Wide detail'), findsOneWidget);
    expect(_shellBackEnabled(tester), isFalse);
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(calls, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide without a shell-owned Back: no header Back', (tester) async {
    viewport(tester, const Size(1280, 800));
    await tester.pumpWidget(frostTestApp(_Repositories(calls: <String>[]), platform: TargetPlatform.android));
    await tester.pumpAndSettle();
    expect(find.byType(FrostCompactBackButton), findsNothing);
  });

  testWidgets('Back follows the layout across wide and narrow changes', (tester) async {
    viewport(tester, const Size(1280, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_shell(_Repositories(calls: calls)), density: FrostDensity.compact));
    await tester.pumpAndSettle();
    expect(_shellBackEnabled(tester), isFalse);

    tester.view.physicalSize = const Size(560, 800);
    await tester.pumpAndSettle();
    expect(find.text('Detail page'), findsOneWidget);
    expect(_shellBackEnabled(tester), isTrue);

    tester.view.physicalSize = const Size(1280, 800);
    await tester.pumpAndSettle();
    expect(find.text('Wide detail'), findsOneWidget);
    expect(_shellBackEnabled(tester), isFalse);

    tester.view.physicalSize = const Size(560, 800);
    await tester.pumpAndSettle();
    await tester.tap(_shellBack());
    await tester.pumpAndSettle();
    expect(calls, ['close']);
    expect(_shellBackEnabled(tester), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow without an open page: Back is left to the app route', (tester) async {
    viewport(tester, const Size(560, 800));
    final calls = <String>[];
    await tester.pumpWidget(frostTestApp(_shell(_Repositories(calls: calls, initiallyOpen: false)), density: FrostDensity.compact));
    await tester.pumpAndSettle();
    expect(find.text('gitbound'), findsOneWidget);
    expect(_shellBackEnabled(tester), isFalse);
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(calls, isEmpty);
  });
}
