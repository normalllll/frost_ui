import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}
void _changed(bool _) {}

const _path = '/Users/example/Documents/Projects/frost/assets/images/background-photo-01.png';
const _swatch = SizedBox.square(
  dimension: 28,
  child: DecoratedBox(
    decoration: BoxDecoration(color: Color(0xFF3366CC), shape: BoxShape.circle),
  ),
);
const _avatar = FrostAvatar(initials: 'AB', semanticLabel: 'Avatar');
const _person = FrostAvatar.person(name: 'zhang');
final _menu = [FrostMenuAction('Open', onSelected: _noop), FrostMenuAction('Delete', destructive: true, onSelected: _noop)];

BaselineCase _row(String id, WidgetBuilder builder, {List<BaselineEnv> envs = const [BaselineEnv.standard], BaselineAct? act}) =>
    BaselineCase(id, builder, envs: envs, act: act);

/// Opens the context menu with a secondary mouse click on the subject.
Future<void> _secondaryClick(WidgetTester tester, Finder subject) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse, buttons: kSecondaryMouseButton);
  await mouse.down(tester.getCenter(subject));
  await mouse.up();
}

void main() {
  baselineGroup('FrostListRow', [
    // Default constructor.
    _row('FrostListRow/required', (_) => const FrostListRow(title: 'Title'), envs: BaselineEnv.all),
    _row(
      'FrostListRow/subtitle',
      (_) => const FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('Subtitle')),
      envs: BaselineEnv.all,
    ),
    for (final tone in [FrostTextTone.tertiary, FrostTextTone.negative])
      _row(
        'FrostListRow/subtitle+subtitleTone=${tone.name}',
        (_) => FrostListRow(
          title: 'Title',
          subtitle: FrostRowSubtitle('Subtitle', tone: tone),
        ),
        envs: BaselineEnv.themes,
      ),
    _row('FrostListRow/subtitle+contentSubtitle', (_) => const FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('日本語の名前', content: true))),
    for (final tone in [FrostStatusTone.positive, FrostStatusTone.negative])
      _row(
        'FrostListRow/subtitle+subtitleStatus=${tone.name}',
        (_) => FrostListRow(title: 'Title', subtitle: FrostRowSubtitle.status('Subtitle', tone)),
        envs: BaselineEnv.themes,
      ),
    _row(
      'FrostListRow/subtitle+subtitleKind=path',
      (_) => const FrostListRow(title: 'Title', subtitle: FrostRowSubtitle.path(_path)),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    _row(
      'FrostListRow/subtitle+inlineSubtitle',
      (_) => const FrostListRow(title: 'Title', subtitle: FrostRowSubtitle.inline('Subtitle')),
      envs: [BaselineEnv.standard, BaselineEnv.narrow, BaselineEnv.largeText],
    ),
    _row(
      'FrostListRow/icon',
      (_) => const FrostListRow(title: 'Title', leading: FrostGlyph.icon(baselineIcon)),
      envs: BaselineEnv.themes,
    ),
    _row(
      'FrostListRow/icon+subtitle',
      (_) => const FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), leading: FrostGlyph.icon(baselineIcon)),
    ),
    _row(
      'FrostListRow/leading=custom',
      (_) => const FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), leading: FrostLeading.custom(_swatch)),
    ),
    _row(
      'FrostListRow/leading=avatar',
      (_) => const FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), leading: FrostLeading.custom(_avatar)),
      envs: BaselineEnv.themes,
    ),
    _row('FrostListRow/contentTitle', (_) => const FrostListRow(title: '日本語の名前', contentTitle: true)),
    _row(
      'FrostListRow/value',
      (_) => const FrostListRow(title: 'Title', value: 'Value'),
      envs: BaselineEnv.all,
    ),
    _row(
      'FrostListRow/value+longTitle',
      (_) => const FrostListRow(title: 'A title long enough that the value has to move below the text', value: 'Value that is long too'),
      envs: [BaselineEnv.narrow, BaselineEnv.largeText],
    ),
    _row(
      'FrostListRow/trailing',
      (_) => const FrostListRow(
        title: 'Title',
        trailing: FrostButton.icon(icon: baselineIcon, label: 'Add', onPressed: _noop),
      ),
      envs: BaselineEnv.themes,
    ),
    _row(
      'FrostListRow/value+trailing',
      (_) => const FrostListRow(
        title: 'Title',
        value: 'Value',
        trailing: FrostButton.icon(icon: baselineIcon, label: 'Add', onPressed: _noop),
      ),
    ),
    for (final accessory in FrostRowAccessory.values)
      _row(
        'FrostListRow/accessory=${accessory.name}',
        (_) => FrostListRow(title: 'Title', accessory: accessory),
        envs: BaselineEnv.themes,
      ),
    _row(
      'FrostListRow/accessory=chevron+onPressed',
      (_) => const FrostListRow(title: 'Title', accessory: FrostRowAccessory.chevron, onPressed: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.touch],
    ),
    _row(
      'FrostListRow/onPressed',
      (_) => const FrostListRow(title: 'Title', onPressed: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.touch],
    ),
    _row(
      'FrostListRow/onPressed#hover',
      (_) => const FrostListRow(title: 'Title', onPressed: _noop),
      act: baselineHover,
    ),
    _row(
      'FrostListRow/onPressed#press',
      (_) => const FrostListRow(title: 'Title', onPressed: _noop),
      act: baselinePress,
    ),
    _row(
      'FrostListRow/onPressed#focus',
      (_) => const FrostListRow(title: 'Title', onPressed: _noop),
      act: baselineFocus,
    ),
    _row(
      'FrostListRow/selected',
      (_) => const FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), selected: true),
      envs: BaselineEnv.themes,
    ),
    _row(
      'FrostListRow/selected+onPressed#hover',
      (_) => const FrostListRow(title: 'Title', selected: true, onPressed: _noop),
      act: baselineHover,
    ),
    _row(
      'FrostListRow/destructive',
      (_) => const FrostListRow(title: 'Title', destructive: true, onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    _row(
      'FrostListRow/destructive#hover',
      (_) => const FrostListRow(title: 'Title', destructive: true, onPressed: _noop),
      act: baselineHover,
    ),
    _row(
      'FrostListRow/enabled=false',
      (_) => const FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), enabled: false, onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    _row('FrostListRow/contextMenu', (_) => FrostListRow(title: 'Title', contextMenu: _menu)),
    _row(
      'FrostListRow/contextMenu#open',
      (_) => FrostListRow(title: 'Title', contextMenu: _menu),
      act: _secondaryClick,
    ),

    // Inside a grouped section the row takes the group corners and keyline.
    _row(
      'FrostListRow/required+inSection',
      (_) => const FrostGroupedSection(
        children: [
          FrostListRow(title: 'First', onPressed: _noop),
          FrostListRow(title: 'Second', subtitle: FrostRowSubtitle('Subtitle'), onPressed: _noop),
          FrostListRow(title: 'Third', onPressed: _noop),
        ],
      ),
      envs: BaselineEnv.themes,
    ),
    _row(
      'FrostListRow/selected+inSection',
      (_) => const FrostGroupedSection(
        children: [
          FrostListRow(title: 'First', onPressed: _noop),
          FrostListRow(title: 'Second', selected: true, onPressed: _noop),
          FrostListRow(title: 'Third', onPressed: _noop),
        ],
      ),
    ),
    _row(
      'FrostListRow/onPressed#hover+inSection',
      (_) => const FrostGroupedSection(
        children: [
          FrostListRow(title: 'First', onPressed: _noop),
          FrostListRow(title: 'Second', onPressed: _noop),
          FrostListRow(title: 'Third', onPressed: _noop),
        ],
      ),
      act: (tester, subject) => baselineHover(tester, find.text('Second')),
    ),

    // FrostListRow.toggle
    _row(
      'FrostListRow.toggle/required',
      (_) => FrostListRow.toggle(title: 'Title', value: false, onChanged: _changed),
      envs: BaselineEnv.all,
    ),
    _row(
      'FrostListRow.toggle/value=true',
      (_) => FrostListRow.toggle(title: 'Title', value: true, onChanged: _changed),
      envs: BaselineEnv.themes,
    ),
    _row('FrostListRow.toggle/onChanged=null', (_) => const FrostListRow.toggle(title: 'Title', value: true, onChanged: null), envs: BaselineEnv.themes),
    _row('FrostListRow.toggle/subtitle', (_) => FrostListRow.toggle(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), value: true, onChanged: _changed)),
    for (final tone in [FrostTextTone.tertiary, FrostTextTone.negative])
      _row(
        'FrostListRow.toggle/subtitle+subtitleTone=${tone.name}',
        (_) => FrostListRow.toggle(
          title: 'Title',
          subtitle: FrostRowSubtitle('Subtitle', tone: tone),
          value: true,
          onChanged: _changed,
        ),
      ),
    _row(
      'FrostListRow.toggle/subtitle+contentSubtitle',
      (_) => FrostListRow.toggle(title: 'Title', subtitle: FrostRowSubtitle('日本語の名前', content: true), value: true, onChanged: _changed),
    ),
    _row(
      'FrostListRow.toggle/subtitle+subtitleStatus',
      (_) => FrostListRow.toggle(title: 'Title', subtitle: FrostRowSubtitle.status('Subtitle', FrostStatusTone.positive), value: true, onChanged: _changed),
    ),
    _row(
      'FrostListRow.toggle/subtitle+subtitleKind=path',
      (_) => FrostListRow.toggle(title: 'Title', subtitle: FrostRowSubtitle.path(_path), value: true, onChanged: _changed),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    _row(
      'FrostListRow.toggle/subtitle+inlineSubtitle',
      (_) => FrostListRow.toggle(title: 'Title', subtitle: FrostRowSubtitle.inline('Subtitle'), value: true, onChanged: _changed),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    _row('FrostListRow.toggle/icon', (_) => FrostListRow.toggle(title: 'Title', leading: FrostGlyph.icon(baselineIcon), value: true, onChanged: _changed)),
    _row('FrostListRow.toggle/contentTitle', (_) => FrostListRow.toggle(title: '日本語の名前', contentTitle: true, value: true, onChanged: _changed)),
    _row(
      'FrostListRow.toggle/selected',
      (_) => FrostListRow.toggle(title: 'Title', selected: true, value: true, onChanged: _changed),
      envs: BaselineEnv.themes,
    ),
    _row(
      'FrostListRow.toggle/onChanged#hover',
      (_) => FrostListRow.toggle(title: 'Title', value: true, onChanged: _changed),
      act: baselineHover,
    ),
    _row(
      'FrostListRow.toggle/onChanged#press',
      (_) => FrostListRow.toggle(title: 'Title', value: true, onChanged: _changed),
      act: baselinePress,
    ),
    _row(
      'FrostListRow.toggle/onChanged#focus',
      (_) => FrostListRow.toggle(title: 'Title', value: true, onChanged: _changed),
      act: baselineFocus,
    ),

    // FrostListRow.check
    _row(
      'FrostListRow.check/required',
      (_) => const FrostListRow.check(title: 'Title', checked: false, onPressed: _noop),
      envs: BaselineEnv.all,
    ),
    _row(
      'FrostListRow.check/checked=true',
      (_) => const FrostListRow.check(title: 'Title', checked: true, onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    _row('FrostListRow.check/onPressed=null', (_) => const FrostListRow.check(title: 'Title', checked: true, onPressed: null), envs: BaselineEnv.themes),
    _row(
      'FrostListRow.check/subtitle',
      (_) => const FrostListRow.check(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), checked: true, onPressed: _noop),
    ),
    for (final tone in [FrostTextTone.tertiary, FrostTextTone.negative])
      _row(
        'FrostListRow.check/subtitle+subtitleTone=${tone.name}',
        (_) => FrostListRow.check(
          title: 'Title',
          subtitle: FrostRowSubtitle('Subtitle', tone: tone),
          checked: true,
          onPressed: _noop,
        ),
      ),
    _row(
      'FrostListRow.check/subtitle+contentSubtitle',
      (_) => const FrostListRow.check(title: 'Title', subtitle: FrostRowSubtitle('日本語の名前', content: true), checked: true, onPressed: _noop),
    ),
    _row(
      'FrostListRow.check/subtitle+subtitleStatus',
      (_) => const FrostListRow.check(title: 'Title', subtitle: FrostRowSubtitle.status('Subtitle', FrostStatusTone.positive), checked: true, onPressed: _noop),
    ),
    _row(
      'FrostListRow.check/subtitle+subtitleKind=path',
      (_) => const FrostListRow.check(title: 'Title', subtitle: FrostRowSubtitle.path(_path), checked: true, onPressed: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    _row(
      'FrostListRow.check/subtitle+inlineSubtitle',
      (_) => const FrostListRow.check(title: 'Title', subtitle: FrostRowSubtitle.inline('Subtitle'), checked: true, onPressed: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    _row('FrostListRow.check/icon', (_) => const FrostListRow.check(title: 'Title', leading: FrostGlyph.icon(baselineIcon), checked: true, onPressed: _noop)),
    _row('FrostListRow.check/contentTitle', (_) => const FrostListRow.check(title: '日本語の名前', contentTitle: true, checked: true, onPressed: _noop)),
    _row(
      'FrostListRow.check/selected',
      (_) => const FrostListRow.check(title: 'Title', selected: true, checked: true, onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    _row(
      'FrostListRow.check/onPressed#hover',
      (_) => const FrostListRow.check(title: 'Title', checked: true, onPressed: _noop),
      act: baselineHover,
    ),
    _row(
      'FrostListRow.check/onPressed#press',
      (_) => const FrostListRow.check(title: 'Title', checked: true, onPressed: _noop),
      act: baselinePress,
    ),
    _row(
      'FrostListRow.check/onPressed#focus',
      (_) => const FrostListRow.check(title: 'Title', checked: true, onPressed: _noop),
      act: baselineFocus,
    ),

    // New API: a person's avatar in the icon column, and a status subtitle
    // inked by its own tone.
    _row(
      'FrostListRow/leading=person-avatar',
      (_) => const FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), leading: FrostGlyph.avatar(_person)),
      envs: BaselineEnv.themes,
    ),
    _row(
      'FrostListRow.toggle/leading=person-avatar',
      (_) => FrostListRow.toggle(title: 'Title', leading: const FrostGlyph.avatar(_person), value: true, onChanged: _changed),
      envs: BaselineEnv.themes,
    ),
    _row(
      'FrostListRow.check/leading=person-avatar',
      (_) => const FrostListRow.check(title: 'Title', leading: FrostGlyph.avatar(_person), checked: true, onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    _row(
      'FrostListRow/subtitle+subtitleStatus=negative+tone=negative',
      (_) => const FrostListRow(
        title: 'Title',
        subtitle: FrostRowSubtitle.status('Subtitle', FrostStatusTone.negative, tone: FrostTextTone.negative),
      ),
      envs: BaselineEnv.themes,
    ),

    // FrostListRow.skeleton
    _row('FrostListRow.skeleton/required', (_) => FrostListRow.skeleton(title: 'Title', icon: false, subtitle: null, value: null), envs: BaselineEnv.all),
    _row('FrostListRow.skeleton/icon', (_) => FrostListRow.skeleton(title: 'Title', icon: true, subtitle: null, value: null)),
    _row('FrostListRow.skeleton/subtitle', (_) => FrostListRow.skeleton(title: 'Title', icon: false, subtitle: 'Subtitle', value: null)),
    _row('FrostListRow.skeleton/value', (_) => FrostListRow.skeleton(title: 'Title', icon: false, subtitle: null, value: 'Value')),
    _row(
      'FrostListRow.skeleton/icon+subtitle+value',
      (_) => FrostListRow.skeleton(title: 'Title', icon: true, subtitle: 'Subtitle', value: 'Value'),
      envs: BaselineEnv.themes,
    ),
  ]);
}
