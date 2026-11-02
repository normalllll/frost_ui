import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

Widget _body(BuildContext context, bool shown) => shown ? const FrostActivityIndicator(semanticLabel: 'Loading') : const FrostText('Content');

// The gate shows its loading state after 300 ms and keeps it for 400 ms.
Future<void> _afterDelay(WidgetTester tester, Finder subject) => tester.pump(const Duration(milliseconds: 350));

Future<void> _finished(WidgetTester tester, Finder subject) async {
  await tester.pump(const Duration(milliseconds: 350));
  await baselineToggle(tester, subject);
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  baselineGroup('FrostLoadingGate', [
    BaselineCase('FrostLoadingGate/required', (_) => const FrostLoadingGate(loading: false, builder: _body), envs: BaselineEnv.all),
    // Loading for less than the delay: still not shown.
    BaselineCase('FrostLoadingGate/loading=true', (_) => const FrostLoadingGate(loading: true, builder: _body)),
    BaselineCase(
      'FrostLoadingGate/loading=true#shown',
      (_) => const FrostLoadingGate(loading: true, builder: _body),
      act: _afterDelay,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostLoadingGate/loading=true#done',
      (_) => BaselineToggle(
        builder: (_, done) => FrostLoadingGate(loading: !done, builder: _body),
      ),
      act: _finished,
    ),
  ]);
}
