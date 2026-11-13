import 'package:flutter/foundation.dart';
// ignore: deprecated_member_use
import 'package:flutter_localizations/flutter_localizations.dart' as legacy;
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:material_ui/material_ui.dart';

import 'support.dart';

class _Router extends RouterDelegate<Object> with ChangeNotifier, PopNavigatorRouterDelegateMixin<Object> {
  _Router(this.child);
  final Widget child;
  @override
  final navigatorKey = GlobalKey<NavigatorState>();
  @override
  Future<void> setNewRoutePath(Object configuration) async {}
  @override
  Widget build(BuildContext context) => Navigator(
    key: navigatorKey,
    pages: [MaterialPage<void>(child: child)],
    onDidRemovePage: (_) {},
  );
}

class _MarkerLocalizations extends DefaultMaterialLocalizations {
  const _MarkerLocalizations();
  @override
  String formatMonthYear(DateTime date) => 'marker';
}

class _MarkerDelegate extends LocalizationsDelegate<MaterialLocalizations> {
  const _MarkerDelegate();
  @override
  bool isSupported(Locale locale) => true;
  @override
  Future<MaterialLocalizations> load(Locale locale) => SynchronousFuture(const _MarkerLocalizations());
  @override
  bool shouldReload(_MarkerDelegate old) => false;
}

Future<MaterialLocalizations> _pump(WidgetTester tester, {Iterable<LocalizationsDelegate<dynamic>>? delegates}) async {
  late MaterialLocalizations found;
  final router = _Router(
    Builder(
      builder: (context) {
        found = MaterialLocalizations.of(context);
        return const SizedBox();
      },
    ),
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    FrostApp.router(
      config: testConfig,
      title: 'Test',
      routerConfig: RouterConfig<Object>(routerDelegate: router),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: delegates,
    ),
  );
  await tester.pumpAndSettle();
  return found;
}

void main() {
  final date = DateTime(2026, 11, 9);

  testWidgets('FrostApp supplies Material localizations for the app locale without delegates', (tester) async {
    final l10n = await _pump(tester);
    expect(l10n.formatMonthYear(date), isNot(const DefaultMaterialLocalizations().formatMonthYear(date)));
    expect(l10n.formatMonthYear(date), contains('2026年'));
  });

  testWidgets('FrostApp still localizes when the app passes the legacy flutter_localizations delegates', (tester) async {
    // ignore: deprecated_member_use
    final l10n = await _pump(tester, delegates: legacy.GlobalMaterialLocalizations.delegates);
    expect(l10n.formatMonthYear(date), contains('2026年'));
  });

  testWidgets('an app-supplied Material delegate wins over the one Frost adds', (tester) async {
    final l10n = await _pump(tester, delegates: const [_MarkerDelegate()]);
    expect(l10n.formatMonthYear(date), 'marker');
  });
}
