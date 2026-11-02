import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/social.dart';

import 'baseline.dart';

void _noop() {}

const _filledIcon = FrostIconData.glyph(IconData(0xe011));
const _avatar = FrostAvatar(initials: 'MK', semanticLabel: 'Mika');
const _body = FrostText('This is the comment text. It is long enough to wrap onto a second line when the column is narrow.');
const _like = FrostThreadAction(icon: baselineIcon, label: 'Like', count: '12', onPressed: _noop);
const _liked = FrostThreadAction(icon: _filledIcon, label: 'Like', count: '13', selected: true, onPressed: _noop);
const _reply = FrostThreadAction(icon: baselineIcon, label: 'Reply', onPressed: _noop);
const _menu = [FrostMenuAction('Report', onSelected: _noop)];
const _pointerAndTouch = [BaselineEnv.standard, BaselineEnv.touch];

void main() {
  baselineGroup('FrostThreadItem', [
    BaselineCase(
      'FrostThreadItem/required',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostThreadItem/badge',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, badge: 'UP'),
      envs: BaselineEnv.themes,
    ),
    for (final tone in FrostBadgeTone.values)
      BaselineCase(
        'FrostThreadItem/badge+badgeTone=${tone.name}',
        (_) => FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, badge: 'UP', badgeTone: tone),
      ),
    BaselineCase('FrostThreadItem/meta', (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, meta: 'Tokyo')),
    BaselineCase(
      'FrostThreadItem/badge+meta',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, badge: 'UP', meta: 'Tokyo'),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostThreadItem/time',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, time: '3 hours ago'),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostThreadItem/like',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, like: _like),
      envs: _pointerAndTouch,
    ),
    BaselineCase(
      'FrostThreadItem/like=selected',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, like: _liked),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostThreadItem/reply',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, reply: _reply),
      envs: _pointerAndTouch,
    ),
    BaselineCase('FrostThreadItem/actions', (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, actions: FrostText('Edited'))),
    BaselineCase(
      'FrostThreadItem/time+like+reply',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, time: '3 hours ago', like: _like, reply: _reply),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.largeText, BaselineEnv.touch, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostThreadItem/time+like+reply+actions',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, time: '3 hours ago', like: _like, reply: _reply, actions: FrostText('Edited')),
    ),
    BaselineCase(
      'FrostThreadItem/onPressed',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, onPressed: _noop),
      envs: _pointerAndTouch,
    ),
    BaselineCase(
      'FrostThreadItem/onPressed#hover',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostThreadItem/onPressed#press',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, onPressed: _noop),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostThreadItem/like#focus',
      (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, time: '3 hours ago', like: _like, reply: _reply),
      act: baselineFocus,
    ),
    BaselineCase('FrostThreadItem/contextMenu', (_) => const FrostThreadItem(avatar: _avatar, author: 'Mika', body: _body, contextMenu: _menu)),
  ]);
}
