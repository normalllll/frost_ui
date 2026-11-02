import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _changed(num _) {}

// The stepper is a pair of buttons; the subject's center is the divider, so
// hover and press act on the center of the increment half.
Offset _increment(WidgetTester tester, Finder subject) => tester.getCenter(subject) + Offset(tester.getSize(subject).width / 4, 0);

Future<void> _hoverIncrement(WidgetTester tester, Finder subject) async {
  final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await gesture.addPointer(location: Offset.zero);
  addTearDown(gesture.removePointer);
  await gesture.moveTo(_increment(tester, subject));
}

Future<void> _pressIncrement(WidgetTester tester, Finder subject) async {
  final gesture = await tester.startGesture(_increment(tester, subject));
  addTearDown(gesture.up);
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  baselineGroup('FrostStepper', [
    BaselineCase('FrostStepper/required', (_) => const FrostStepper(value: 5, onChanged: null, semanticLabel: 'Quantity'), envs: BaselineEnv.all),
    BaselineCase(
      'FrostStepper/onChanged',
      (_) => const FrostStepper(value: 5, onChanged: _changed, semanticLabel: 'Quantity'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostStepper/value=min', (_) => const FrostStepper(value: 0, onChanged: _changed, semanticLabel: 'Quantity')),
    BaselineCase('FrostStepper/value=max', (_) => const FrostStepper(value: 100, onChanged: _changed, semanticLabel: 'Quantity')),
    BaselineCase('FrostStepper/min+max', (_) => const FrostStepper(value: 3, min: 1, max: 3, onChanged: _changed, semanticLabel: 'Quantity')),
    BaselineCase('FrostStepper/step', (_) => const FrostStepper(value: 10, step: 5, onChanged: _changed, semanticLabel: 'Quantity')),
    BaselineCase(
      'FrostStepper/onChanged#hover',
      (_) => const FrostStepper(value: 5, onChanged: _changed, semanticLabel: 'Quantity'),
      act: _hoverIncrement,
    ),
    BaselineCase(
      'FrostStepper/onChanged#press',
      (_) => const FrostStepper(value: 5, onChanged: _changed, semanticLabel: 'Quantity'),
      act: _pressIncrement,
    ),
    BaselineCase(
      'FrostStepper/onChanged#focus',
      (_) => const FrostStepper(value: 5, onChanged: _changed, semanticLabel: 'Quantity'),
      act: baselineFocus,
    ),
  ]);
}
