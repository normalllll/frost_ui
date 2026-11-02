// The display checks of frost_ui's contract suite, for the frost_data components.
import 'package:flutter_test/flutter_test.dart';

import '../../../frost_ui/test/contract/harness.dart';
import 'cases.dart';

void main() {
  for (final c in displayCases) {
    void check(String name, Future<String?> Function(WidgetTester tester) run) {
      if (c.skip.containsKey(name)) return;
      testWidgets('${c.id} $name', (tester) async => expectContract(c.id, name, await run(tester)));
    }

    check('text-scale', (tester) => checkTextScale(tester, c));
    check('rtl', (tester) => checkRtl(tester, c));
    check('intrinsic', (tester) => checkIntrinsic(tester, c));
    check('no-theme', (tester) => checkNoTheme(tester, c));
  }
}
