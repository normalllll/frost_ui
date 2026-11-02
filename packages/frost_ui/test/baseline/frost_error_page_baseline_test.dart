import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

void _noop() {}

FrostScope _withAction(Widget child) => FrostScope(config: baselineActionConfig, child: child);

void main() {
  const height = 640.0;
  const url = 'https://example.com/api/v1/items?page=2';
  const details = 'status=500\nendpoint=/api/v1/items';
  final wide = BaselineEnv.standard.copyWith(width: 1280);
  // A page fills its parent: wide (navigation beside the page) and narrow
  // (the page owns its back control).
  final pageEnvs = [
    wide,
    wide.copyWith(brightness: Brightness.light),
    wide.copyWith(textScale: 2),
    wide.copyWith(input: BaselineInput.touch),
    BaselineEnv.narrow,
  ];
  final pageThemes = [wide, wide.copyWith(brightness: Brightness.light)];
  final wideAndNarrow = [wide, BaselineEnv.narrow];
  baselineGroup('FrostErrorPage', [
    BaselineCase(
      'FrostErrorPage/required',
      (_) => const FrostErrorPage(message: 'Could not load items', onRetry: _noop),
      height: height,
      envs: pageEnvs,
    ),
    BaselineCase(
      'FrostErrorPage/fullUrl',
      (_) => const FrostErrorPage(message: 'Could not load items', onRetry: _noop, fullUrl: url),
      height: height,
      envs: wideAndNarrow,
    ),
    BaselineCase(
      'FrostErrorPage/details',
      (_) => const FrostErrorPage(message: 'Could not load items', onRetry: _noop, details: details),
      height: height,
      envs: wideAndNarrow,
    ),
    BaselineCase(
      'FrostErrorPage/fullUrl+details',
      (_) => const FrostErrorPage(message: 'Could not load items', onRetry: _noop, fullUrl: url, details: details),
      height: height,
      envs: pageThemes,
    ),
    BaselineCase(
      'FrostErrorPage.fromError/required',
      (_) => const FrostErrorPage.fromError(error: BaselineFailure(), onRetry: _noop),
      height: height,
      envs: pageEnvs,
    ),
    BaselineCase(
      'FrostErrorPage.fromError/required#open',
      (_) => const FrostErrorPage.fromError(error: BaselineFailure(), onRetry: _noop),
      height: height,
      act: baselineTapText('L.errorDetails'),
      envs: [wide],
    ),
    BaselineCase(
      'FrostErrorPage.fromError/presenter=action',
      (_) => _withAction(const FrostErrorPage.fromError(error: BaselineFailure(), onRetry: _noop)),
      height: height,
      envs: wideAndNarrow,
    ),
  ]);
}
