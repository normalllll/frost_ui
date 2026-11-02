import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

void _noop() {}

FrostScope _withAction(Widget child) => FrostScope(config: baselineActionConfig, child: child);

void main() {
  const height = 480.0;
  const url = 'https://example.com/api/v1/items?page=2';
  const details = 'status=500\nendpoint=/api/v1/items';
  baselineGroup('FrostErrorContent', [
    BaselineCase(
      'FrostErrorContent/required',
      (_) => const FrostErrorContent(message: 'Could not load items', onRetry: _noop),
      height: height,
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostErrorContent/onRetry=null', (_) => const FrostErrorContent(message: 'Could not load items', onRetry: null), height: height),
    BaselineCase(
      'FrostErrorContent/retryLabel',
      (_) => const FrostErrorContent(message: 'Could not load items', onRetry: _noop, retryLabel: 'Reload'),
      height: height,
    ),
    BaselineCase(
      'FrostErrorContent/fullUrl',
      (_) => const FrostErrorContent(message: 'Could not load items', onRetry: _noop, fullUrl: url),
      height: height,
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostErrorContent/details',
      (_) => const FrostErrorContent(message: 'Could not load items', onRetry: _noop, details: details),
      height: height,
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostErrorContent/details#open',
      (_) => const FrostErrorContent(message: 'Could not load items', onRetry: _noop, details: details),
      height: height,
      act: baselineTapText('L.errorDetails'),
    ),
    BaselineCase(
      'FrostErrorContent/fullUrl+details',
      (_) => const FrostErrorContent(message: 'Could not load items', onRetry: _noop, fullUrl: url, details: details),
      height: height,
    ),
    BaselineCase(
      'FrostErrorContent.fromError/required',
      (_) => const FrostErrorContent.fromError(error: BaselineFailure(), onRetry: _noop),
      height: height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostErrorContent.fromError/required#open',
      (_) => const FrostErrorContent.fromError(error: BaselineFailure(), onRetry: _noop),
      height: height,
      act: baselineTapText('L.errorDetails'),
    ),
    BaselineCase('FrostErrorContent.fromError/onRetry=null', (_) => const FrostErrorContent.fromError(error: BaselineFailure(), onRetry: null), height: height),
    BaselineCase(
      'FrostErrorContent.fromError/retryLabel',
      (_) => const FrostErrorContent.fromError(error: BaselineFailure(), onRetry: _noop, retryLabel: 'Reload'),
      height: height,
    ),
    BaselineCase(
      'FrostErrorContent.fromError/presenter=action',
      (_) => _withAction(const FrostErrorContent.fromError(error: BaselineFailure(), onRetry: _noop)),
      height: height,
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
  ]);
}
