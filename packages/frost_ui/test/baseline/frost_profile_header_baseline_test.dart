import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _avatar = FrostAvatar(initials: 'MK', semanticLabel: 'Mika');
const _stats = [FrostStat(value: '1.2k', caption: 'Followers'), FrostStat(value: '48', caption: 'Following'), FrostStat(value: '312', caption: 'Posts')];
const _follow = FrostButton(label: 'Follow', onPressed: _noop);
const _more = FrostButton.icon(icon: baselineIcon, label: 'More', onPressed: _noop);

// The header switches arrangement at 560, so every argument runs wide and narrow.
const _wideAndNarrow = [BaselineEnv.standard, BaselineEnv.narrow];

void main() {
  baselineGroup('FrostProfileHeader', [
    BaselineCase(
      'FrostProfileHeader/required',
      (_) => const FrostProfileHeader(avatar: _avatar, title: 'Mika Kobayashi'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostProfileHeader/subtitle',
      (_) => const FrostProfileHeader(avatar: _avatar, title: 'Mika Kobayashi', subtitle: 'Illustrator in Tokyo'),
      envs: _wideAndNarrow,
    ),
    BaselineCase(
      'FrostProfileHeader/contentTitle',
      (_) => const FrostProfileHeader(avatar: _avatar, title: 'Mika Kobayashi', contentTitle: true),
      envs: _wideAndNarrow,
    ),
    BaselineCase(
      'FrostProfileHeader/titleTrailing',
      (_) => const FrostProfileHeader(
        avatar: _avatar,
        title: 'Mika Kobayashi',
        titleTrailing: FrostTag(label: 'Pro'),
      ),
      envs: _wideAndNarrow,
    ),
    BaselineCase(
      'FrostProfileHeader/subtitleLeading',
      (_) => const FrostProfileHeader(avatar: _avatar, title: 'Mika Kobayashi', subtitle: 'Studio Frost', subtitleLeading: FrostIcon(baselineIcon)),
      envs: [BaselineEnv.standard, BaselineEnv.narrow, BaselineEnv.largeText],
    ),
    BaselineCase(
      'FrostProfileHeader/stats',
      (_) => const FrostProfileHeader(avatar: _avatar, title: 'Mika Kobayashi', stats: _stats),
      envs: _wideAndNarrow,
    ),
    BaselineCase(
      'FrostProfileHeader/actions',
      (_) => const FrostProfileHeader(avatar: _avatar, title: 'Mika Kobayashi', actions: [_follow]),
      envs: _wideAndNarrow,
    ),
    BaselineCase(
      'FrostProfileHeader/moreAction',
      (_) => const FrostProfileHeader(avatar: _avatar, title: 'Mika Kobayashi', moreAction: _more),
      envs: _wideAndNarrow,
    ),
    BaselineCase(
      'FrostProfileHeader/actions+moreAction',
      (_) => const FrostProfileHeader(avatar: _avatar, title: 'Mika Kobayashi', actions: [_follow], moreAction: _more),
      envs: _wideAndNarrow,
    ),
    BaselineCase(
      'FrostProfileHeader/subtitle+titleTrailing+stats+actions+moreAction',
      (_) => const FrostProfileHeader(
        avatar: _avatar,
        title: 'Mika Kobayashi',
        subtitle: 'Illustrator in Tokyo',
        titleTrailing: FrostTag(label: 'Pro'),
        stats: _stats,
        actions: [_follow],
        moreAction: _more,
      ),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.largeText, BaselineEnv.touch, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostProfileHeader/avatar=placeholder',
      (_) => const FrostProfileHeader(
        avatar: FrostAvatar(semanticLabel: 'Mika'),
        title: 'Mika Kobayashi',
      ),
      envs: _wideAndNarrow,
    ),
  ]);
}
