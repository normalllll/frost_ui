import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

void _noop() {}

FrostScope _withAction(Widget child) => FrostScope(config: baselineActionConfig, child: child);

void main() {
  baselineGroup('FrostErrorActionButton', [
    BaselineCase(
      'FrostErrorActionButton/required',
      (_) => _withAction(const FrostErrorActionButton(error: BaselineFailure(), onResolved: _noop)),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostErrorActionButton/onResolved=null', (_) => _withAction(const FrostErrorActionButton(error: BaselineFailure(), onResolved: null))),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostErrorActionButton/size=${size.name}',
        (_) => _withAction(FrostErrorActionButton(error: const BaselineFailure(), onResolved: _noop, size: size)),
      ),
    // The presenter maps no action: nothing renders.
    BaselineCase('FrostErrorActionButton/presenter=noAction', (_) => const FrostErrorActionButton(error: BaselineFailure(), onResolved: _noop)),
    BaselineCase(
      'FrostErrorActionButton.icon/required',
      (_) => _withAction(const FrostErrorActionButton.icon(error: BaselineFailure(), onResolved: _noop)),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostErrorActionButton.icon/onResolved=null',
      (_) => _withAction(const FrostErrorActionButton.icon(error: BaselineFailure(), onResolved: null)),
    ),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostErrorActionButton.icon/size=${size.name}',
        (_) => _withAction(FrostErrorActionButton.icon(error: const BaselineFailure(), onResolved: _noop, size: size)),
      ),
    BaselineCase('FrostErrorActionButton.icon/presenter=noAction', (_) => const FrostErrorActionButton.icon(error: BaselineFailure(), onResolved: _noop)),
  ]);
}
