import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'app_router_test.dart' show TestRouter;
import 'support.dart';

class _ThemeReader extends StatelessWidget {
  const _ThemeReader();
  static var builds = 0;
  static Color? accent;

  @override
  Widget build(BuildContext context) {
    builds++;
    Theme.of(context);
    accent = FrostThemeTokens.of(context).accent;
    return const SizedBox();
  }
}

void main() {
  testWidgets('rebuilding the app with unchanged arguments leaves theme readers alone; a new accent reaches them', (tester) async {
    _ThemeReader.builds = 0;
    final router = TestRouter(const _ThemeReader());
    addTearDown(router.dispose);
    final routerConfig = RouterConfig<Object>(routerDelegate: router);
    final presets = FrostPalettes.pink.accentPresets;
    var accent = presets[0];
    late StateSetter rebuild;
    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setState) {
          rebuild = setState;
          return FrostApp.router(
            config: testConfig,
            title: 'Test',
            routerConfig: routerConfig,
            appearance: FrostAppearance(lightAccent: accent, darkAccent: accent, mode: FrostThemeMode.light),
          );
        },
      ),
    );
    await tester.pumpAndSettle();
    final settled = _ThemeReader.builds;

    rebuild(() {});
    await tester.pumpAndSettle();
    expect(_ThemeReader.builds, settled, reason: 'the same config, appearance, locale and density build no new theme');

    rebuild(() => accent = presets[1]);
    await tester.pumpAndSettle();
    expect(_ThemeReader.builds, greaterThan(settled));
    expect(_ThemeReader.accent, FrostPalettes.pink.palette(Brightness.light, FrostTone.neutral, presets[1]).accent);
  });
}
