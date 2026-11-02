import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

void _noop() {}

void main() {
  baselineGroup('FrostCompactMessage', [
    BaselineCase(
      'FrostCompactMessage/required',
      (_) => const FrostCompactMessage(icon: baselineIcon, message: 'Saved to library'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostCompactMessage/message=long',
      (_) => const FrostCompactMessage(
        icon: baselineIcon,
        message: 'The library could not be saved because the destination folder is read-only and cannot be changed',
        actionLabel: 'Retry',
        onAction: _noop,
      ),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase('FrostCompactMessage/actionLabel', (_) => const FrostCompactMessage(icon: baselineIcon, message: 'Saved to library', actionLabel: 'Retry')),
    BaselineCase('FrostCompactMessage/onAction', (_) => const FrostCompactMessage(icon: baselineIcon, message: 'Saved to library', onAction: _noop)),
    BaselineCase(
      'FrostCompactMessage/actionLabel+onAction',
      (_) => const FrostCompactMessage(icon: baselineIcon, message: 'Saved to library', actionLabel: 'Retry', onAction: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostCompactMessage/details',
      (_) => const FrostCompactMessage(icon: baselineIcon, message: 'Saved to library', details: 'path=/library\nstatus=200'),
    ),
    BaselineCase(
      'FrostCompactMessage/details#open',
      (_) => const FrostCompactMessage(icon: baselineIcon, message: 'Saved to library', details: 'path=/library\nstatus=200'),
      act: baselineTapText('L.errorDetails'),
    ),
    BaselineCase('FrostCompactMessage.error/required', (_) => const FrostCompactMessage.error(error: BaselineFailure()), envs: BaselineEnv.all),
    BaselineCase(
      'FrostCompactMessage.error/required#open',
      (_) => const FrostCompactMessage.error(error: BaselineFailure()),
      act: baselineTapText('L.errorDetails'),
    ),
    BaselineCase('FrostCompactMessage.error/actionLabel', (_) => const FrostCompactMessage.error(error: BaselineFailure(), actionLabel: 'Try again')),
    BaselineCase('FrostCompactMessage.error/onAction', (_) => const FrostCompactMessage.error(error: BaselineFailure(), onAction: _noop)),
    BaselineCase(
      'FrostCompactMessage.error/actionLabel+onAction',
      (_) => const FrostCompactMessage.error(error: BaselineFailure(), actionLabel: 'Try again', onAction: _noop),
      envs: BaselineEnv.themes,
    ),
  ]);
}
