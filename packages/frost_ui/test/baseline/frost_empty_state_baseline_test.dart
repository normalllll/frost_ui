import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

void main() {
  const height = 360.0;
  baselineGroup('FrostEmptyState', [
    BaselineCase(
      'FrostEmptyState/required',
      (_) => const FrostEmptyState(title: 'Nothing here yet'),
      height: height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostEmptyState/icon',
      (_) => const FrostEmptyState(icon: baselineIcon, title: 'Nothing here yet'),
      height: height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostEmptyState/message',
      (_) => const FrostEmptyState(title: 'Nothing here yet', message: 'Items you add will show up in this list.'),
      height: height,
      envs: [BaselineEnv.standard, BaselineEnv.largeText, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostEmptyState/actionLabel',
      (_) => const FrostEmptyState(title: 'Nothing here yet', actionLabel: 'Add item'),
      height: height,
    ),
    BaselineCase(
      'FrostEmptyState/actionLabel+onAction',
      (_) => const FrostEmptyState(title: 'Nothing here yet', actionLabel: 'Add item', onAction: _noop),
      height: height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostEmptyState/details',
      (_) => const FrostEmptyState(title: 'Nothing here yet', details: FrostText('Filters: archived')),
      height: height,
    ),
    BaselineCase(
      'FrostEmptyState/icon+message+actionLabel+onAction+details',
      (_) => const FrostEmptyState(
        icon: baselineIcon,
        title: 'Nothing here yet',
        message: 'Items you add will show up in this list.',
        actionLabel: 'Add item',
        onAction: _noop,
        details: FrostText('Filters: archived'),
      ),
      height: height,
      envs: [BaselineEnv.standard, BaselineEnv.largeText, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostEmptyState/message+actionLabel+onAction#short',
      (_) => const FrostEmptyState(
        icon: baselineIcon,
        title: 'Nothing here yet',
        message: 'Items you add will show up in this list.',
        actionLabel: 'Add item',
        onAction: _noop,
      ),
      height: 140,
    ),
    BaselineCase(
      'FrostEmptyState.search/required',
      (_) => FrostEmptyState.search(query: 'cat', onClear: _noop),
      height: height,
      envs: BaselineEnv.all,
    ),
  ]);
}
