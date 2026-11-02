// The hiding family: components that hide a subtree.
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import 'registry.dart';

void main() {
  for (final c in hidingCases) {
    void check(String name, Future<String?> Function(WidgetTester tester) run) {
      if (c.skip.containsKey(name)) return;
      testWidgets('${c.id} $name', (tester) async => expectContract(c.id, name, await run(tester)));
    }

    check('hidden-focus', (tester) => checkHiddenFocus(tester, c));
    check('hidden-tap', (tester) => checkHiddenTap(tester, c));
    check('hidden-ticker', (tester) => checkHiddenTicker(tester, c));
  }
}
