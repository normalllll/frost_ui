import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

void main() {
  const message = 'Your library was synced.';
  const long = 'Your library was synced, but two folders could not be read because they are no longer available on this device.';
  baselineGroup('FrostInlineBanner', [
    BaselineCase(
      'FrostInlineBanner/required',
      (_) => const FrostInlineBanner(tone: FrostBannerTone.info, message: message),
      envs: BaselineEnv.all,
    ),
    for (final tone in FrostBannerTone.values.skip(1))
      BaselineCase(
        'FrostInlineBanner/tone=${tone.name}',
        (_) => FrostInlineBanner(tone: tone, message: message),
        envs: BaselineEnv.themes,
      ),
    BaselineCase(
      'FrostInlineBanner/title',
      (_) => const FrostInlineBanner(tone: FrostBannerTone.info, message: message, title: 'Synced'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostInlineBanner/actionLabel', (_) => const FrostInlineBanner(tone: FrostBannerTone.info, message: message, actionLabel: 'Review')),
    BaselineCase('FrostInlineBanner/onAction', (_) => const FrostInlineBanner(tone: FrostBannerTone.info, message: message, onAction: _noop)),
    BaselineCase(
      'FrostInlineBanner/actionLabel+onAction',
      (_) => const FrostInlineBanner(tone: FrostBannerTone.info, message: message, actionLabel: 'Review', onAction: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostInlineBanner/onDismiss',
      (_) => const FrostInlineBanner(tone: FrostBannerTone.info, message: message, onDismiss: _noop),
      envs: BaselineEnv.themes,
    ),
    for (final tone in FrostBannerTone.values)
      BaselineCase(
        'FrostInlineBanner/style=filled+tone=${tone.name}',
        (_) => FrostInlineBanner(tone: tone, message: message, style: FrostBannerStyle.filled),
        envs: BaselineEnv.themes,
      ),
    BaselineCase(
      'FrostInlineBanner/title+actionLabel+onAction+onDismiss',
      (_) =>
          const FrostInlineBanner(tone: FrostBannerTone.caution, message: message, title: 'Synced', actionLabel: 'Review', onAction: _noop, onDismiss: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.largeText, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostInlineBanner/message=long+actionLabel+onAction',
      (_) => const FrostInlineBanner(tone: FrostBannerTone.negative, message: long, actionLabel: 'Review', onAction: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.largeText, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostInlineBanner/message=long+title+onDismiss',
      (_) => const FrostInlineBanner(tone: FrostBannerTone.positive, message: long, title: 'Synced', onDismiss: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
  ]);
}
