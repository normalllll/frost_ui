// The interactive family: buttons, toggles, inputs, pickers, clickable rows and cards.
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import 'registry.dart';

void main() {
  for (final c in interactiveCases) {
    void check(String name, Future<String?> Function(WidgetTester tester) run) {
      if (c.skip.containsKey(name)) return;
      testWidgets('${c.id} $name', (tester) async => expectContract(c.id, name, await run(tester)));
    }

    check('disabled-scope', (tester) => checkDisabledScope(tester, c));
    check('disabled-semantics', (tester) => checkDisabledSemantics(tester, c));
    check('semantics', (tester) => checkSemantics(tester, c));
    check('keyboard', (tester) => checkKeyboard(tester, c));
    check('touch-target', (tester) => checkTouchTarget(tester, c));
    check('text-scale', (tester) => checkTextScale(tester, c));
    check('rtl', (tester) => checkRtl(tester, c));
    check('reduced-motion', (tester) => checkReducedMotion(tester, c));
    check('intrinsic', (tester) => checkIntrinsic(tester, c));
    check('no-theme', (tester) => checkNoTheme(tester, c));
  }
}
