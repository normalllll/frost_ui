import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/motion/_material_reveal.dart';

import 'support.dart';

/// The shell around a page Navigator: the destination root, then optionally a
/// secondary destination's root and a page pushed inside it.
class _App extends StatefulWidget {
  const _App({required this.platform});
  final TargetPlatform platform;
  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  bool secondary = false, inner = false;
  void show({required bool secondary, bool inner = false}) => setState(() {
    this.secondary = secondary;
    this.inner = inner;
  });

  @override
  Widget build(BuildContext context) => frostTestApp(
    platform: widget.platform,
    FrostShell(
      destinations: [FrostNavDestination(icon: testIcons.image, label: 'Home'), FrostNavDestination(icon: testIcons.search, label: 'Activity')],
      selectedIndex: secondary ? null : 0,
      secondary: FrostShellSecondary(
        destinations: [FrostNavDestination(icon: testIcons.add, label: 'Downloads')],
        selectedIndex: secondary ? 0 : null,
        onSelected: (_) => show(secondary: true),
      ),
      atDestinationRoot: !secondary,
      onDestinationSelected: (_) => show(secondary: false),
      canGoBack: secondary,
      onBack: () => show(secondary: inner, inner: false),
      showsMobileNavigation: true,
      child: Navigator(
        pages: [
          const FrostDetailPage<void>(key: ValueKey('root'), child: FrostShellDestination(child: Center(child: FrostText('Root page')))),
          if (secondary) const FrostDetailPage<void>.secondaryDestination(key: ValueKey('downloads'), child: Center(child: FrostText('Downloads page'))),
          if (inner) const FrostDetailPage<void>(key: ValueKey('item'), child: Center(child: FrostText('Item page'))),
        ],
        onDidRemovePage: (page) {
          if (page.key == const ValueKey('item')) {
            show(secondary: true);
          } else if (page.key == const ValueKey('downloads')) {
            show(secondary: false);
          }
        },
      ),
    ),
  );
}

void _window(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Whether the page holding [text] is still entering or leaving: its reveal is
/// short of opaque or its scale is off rest.
bool _moving(WidgetTester tester, String text) {
  final reveal = find.ancestor(of: find.text(text), matching: find.byType(FrostMaterialReveal));
  final faded = tester.widgetList<FrostMaterialReveal>(reveal).any((widget) => widget.opacity < 1);
  final scaled = tester
      .widgetList<Transform>(find.ancestor(of: find.text(text), matching: find.byType(Transform)))
      .any((widget) => widget.transform.getMaxScaleOnAxis() != 1);
  return faded || scaled;
}

void main() {
  testWidgets('in the sidebar layout a secondary destination switches in at once over a root page that stops painting', (tester) async {
    _window(tester, const Size(1147, 717));
    await tester.pumpWidget(const _App(platform: TargetPlatform.windows));
    await tester.pumpAndSettle();
    final app = tester.state<_AppState>(find.byType(_App));

    app.show(secondary: true);
    await tester.pump();
    expect(find.text('Downloads page'), findsOneWidget);
    expect(_moving(tester, 'Downloads page'), isFalse);
    expect(find.text('Root page'), findsNothing, reason: 'the root page is offstage from the first frame');

    // A page pushed inside the secondary destination still moves in.
    app.show(secondary: true, inner: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_moving(tester, 'Item page'), isTrue);
    await tester.pumpAndSettle();
    expect(_moving(tester, 'Item page'), isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets('with the bottom bar a secondary destination is pushed and goes back with motion', (tester) async {
    _window(tester, const Size(390, 844));
    await tester.pumpWidget(const _App(platform: TargetPlatform.windows));
    await tester.pumpAndSettle();
    final app = tester.state<_AppState>(find.byType(_App));

    app.show(secondary: true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));
    expect(_moving(tester, 'Downloads page'), isTrue);
    expect(find.text('Root page'), findsOneWidget, reason: 'the root page shows beneath while the page enters');
    await tester.pumpAndSettle();
    expect(_moving(tester, 'Downloads page'), isFalse);

    app.show(secondary: false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    expect(find.text('Downloads page'), findsOneWidget, reason: 'the page leaves with an exit motion');
    expect(find.text('Root page'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Downloads page'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
