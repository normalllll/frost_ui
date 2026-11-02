// The overlay family: dialogs, sheets, confirmations, form dialogs, menus and popovers.
import 'package:flutter_test/flutter_test.dart';

import 'harness.dart';
import 'registry.dart';

void main() {
  for (final c in overlayCases) {
    void check(String name, Future<String?> Function(WidgetTester tester) run) {
      if (c.skip.containsKey(name)) return;
      testWidgets('${c.id} $name', (tester) async => expectContract(c.id, name, await run(tester)));
    }

    // Only an overlay that can be dragged away has a drag to test.
    final draggable = c.dragTarget != null;
    check('popscope-esc', (tester) => checkPopScopeEsc(tester, c));
    check('popscope-close', (tester) => checkPopScopeClose(tester, c));
    if (draggable) check('popscope-drag', (tester) => checkPopScopeDrag(tester, c));
    check('popscope-back', (tester) => checkPopScopeBack(tester, c));
    check('barrier', (tester) => checkBarrier(tester, c));
    check('back-only-overlay', (tester) => checkBackOnlyOverlay(tester, c));
    check('esc-only-overlay', (tester) => checkEscOnlyOverlay(tester, c));
  }
}
