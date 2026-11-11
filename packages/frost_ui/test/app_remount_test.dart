import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'app_router_test.dart' show TestRouter;
import 'support.dart';

class _Probe extends StatefulWidget {
  const _Probe({required this.child});
  final Widget child;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  static var created = 0;
  @override
  void initState() {
    super.initState();
    created++;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  testWidgets('an app built under a new key starts with new states and still shows notices', (tester) async {
    _ProbeState.created = 0;
    final routers = <TestRouter>[];
    addTearDown(() {
      for (final router in routers) {
        router.dispose();
      }
    });
    Widget app(int generation) {
      final router = TestRouter(const Scaffold(body: SizedBox()));
      routers.add(router);
      return KeyedSubtree(
        key: ValueKey(generation),
        child: FrostApp.router(
          config: testConfig,
          title: 'Test',
          routerConfig: RouterConfig<Object>(routerDelegate: router),
          builder: (context, child) => _Probe(child: child!),
        ),
      );
    }

    await tester.pumpWidget(app(0));
    expect(_ProbeState.created, 1);
    FrostToast.info('Before');
    await tester.pump();
    expect(find.text('Before'), findsOneWidget);

    await tester.pumpWidget(app(1));
    expect(_ProbeState.created, 2, reason: 'the new app does not take over the previous app states');
    expect(find.text('Before'), findsNothing, reason: 'a notice ends with its app');

    FrostToast.info('After');
    await tester.pump();
    expect(find.text('After'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 4));
    expect(tester.takeException(), isNull);
  });
}
