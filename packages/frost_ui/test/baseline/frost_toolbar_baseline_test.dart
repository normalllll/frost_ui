import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}
void _changed(String _) {}
void _sorted(String _, bool _) {}

const _entries = <FrostMenuEntry>[FrostMenuAction('Copy', onSelected: _noop), FrostMenuAction('Paste', onSelected: _noop)];
const _choices = [FrostPickerOption<String>(value: 'grid', label: 'Grid'), FrostPickerOption<String>(value: 'list', label: 'List')];
const _fields = [FrostPickerOption<String>(value: 'name', label: 'Name'), FrostPickerOption<String>(value: 'date', label: 'Date')];

FrostToolbarItem _action({
  FrostToolbarPriority priority = FrostToolbarPriority.normal,
  bool showsLabel = false,
  VoidCallback? onPressed = _noop,
  String label = 'Filter',
}) => FrostToolbarItem.action(icon: baselineIcon, label: label, priority: priority, showsLabel: showsLabel, onPressed: onPressed);

FrostToolbarItem _menu({bool showsLabel = true, String? valueLabel, FrostIconData? icon}) =>
    FrostToolbarItem.menu(label: 'Options', entries: _entries, showsLabel: showsLabel, valueLabel: valueLabel, icon: icon);

FrostToolbarItem _custom() => FrostToolbarItem.custom(
  builder: (_) => const Center(child: Text('Custom')),
  minWidth: 80,
  overflowEntry: const FrostMenuAction('Custom', onSelected: _noop),
);

// Several actions of different priorities: they overflow in a narrow window.
List<FrostToolbarItem> _many() => [
  _action(priority: FrostToolbarPriority.high, label: 'Share'),
  _action(label: 'Filter', showsLabel: true),
  FrostToolbarItem.picker<String>(choices: _choices, value: 'grid', onChanged: _changed, label: 'View'),
  FrostToolbarItem.sortMenu<String>(fields: _fields, value: 'name', ascending: true, onChanged: _sorted, label: 'Sort'),
  _menu(valueLabel: null),
  _action(priority: FrostToolbarPriority.low, label: 'Archive'),
];

Widget _bar({
  List<Widget>? leadingIcons,
  Widget? title,
  List<Widget>? leading,
  List<FrostToolbarItem>? controls,
  Widget? middle,
  Widget? collapsedMiddle,
  List<FrostToolbarItem>? trailing,
}) => windowed(
  FrostToolbar(
    leadingIcons: leadingIcons ?? const [],
    title: title,
    leading: leading ?? const [],
    controls: controls ?? const [],
    middle: middle,
    collapsedMiddle: collapsedMiddle,
    trailing: trailing ?? const [],
  ),
);

const _title = Text('Title');
const _collapsed = FrostButton.icon(icon: baselineIcon, label: 'Search', onPressed: _noop);
const _envs = [BaselineEnv.standard, BaselineEnv.narrow];

BaselineCase _case(String id, Widget Function() build, {List<BaselineEnv> envs = const [BaselineEnv.standard], BaselineAct? act}) =>
    BaselineCase(id, (_) => build(), envs: envs, act: act);

Widget _search(Widget Function(Widget search) build) => SearchHost(builder: (context, search, header) => build(search));

void main() {
  baselineGroup('FrostToolbar', [
    _case('FrostToolbar/required', () => _bar(), envs: [...BaselineEnv.all, wide]),
    _case('FrostToolbar/leading=text', () => _bar(title: _title), envs: _envs),
    _case(
      'FrostToolbar/leading=icon',
      () => _bar(leadingIcons: const [_collapsed], title: _title),
      envs: _envs,
    ),
    _case(
      'FrostToolbar/leading=icon#hover',
      () => _bar(leadingIcons: const [_collapsed], title: _title),
      act: baselineHover,
    ),
    _case(
      'FrostToolbar/leading=icon#press',
      () => _bar(leadingIcons: const [_collapsed], title: _title),
      act: baselinePress,
    ),
    _case(
      'FrostToolbar/leading=icon#focus',
      () => _bar(leadingIcons: const [_collapsed], title: _title),
      act: baselineFocus,
    ),
    _case(
      'FrostToolbar/leading=titleMenu',
      () => _bar(
        leading: const [FrostTitleMenu(title: 'Library', entries: _entries)],
      ),
      envs: _envs,
    ),
    _case(
      'FrostToolbar/leading=titleMenu#open',
      () => _bar(
        leading: const [FrostTitleMenu(title: 'Library', entries: _entries)],
      ),
      act: tapButton,
    ),
    _case(
      'FrostToolbar/leading=menuButton',
      () => _bar(
        leading: const [FrostToolbarMenuButton(label: 'Sort', entries: _entries)],
      ),
      envs: _envs,
    ),
    _case(
      'FrostToolbar/leading=compactBack',
      () => _bar(
        leadingIcons: const [FrostCompactBackButton(onPressed: _noop)],
        title: _title,
      ),
      envs: _envs,
    ),
    _case(
      'FrostToolbar/leading=compactBack#hover',
      () => _bar(
        leadingIcons: const [FrostCompactBackButton(onPressed: _noop)],
        title: _title,
      ),
      act: baselineHover,
    ),

    // controls
    _case('FrostToolbar/controls=action', () => _bar(controls: [_action()]), envs: _envs),
    _case(
      'FrostToolbar/controls=picker',
      () => _bar(
        controls: [FrostToolbarItem.picker<String>(choices: _choices, value: 'grid', onChanged: _changed, label: 'View')],
      ),
      envs: _envs,
    ),
    _case('FrostToolbar/controls=many', () => _bar(controls: _many()), envs: [wide, ..._envs]),
    _case(
      'FrostToolbar/controls+trailing',
      () => _bar(
        controls: [_action(label: 'Filter')],
        trailing: [_action(label: 'Share')],
      ),
      envs: _envs,
    ),

    // middle, collapsedMiddle; the middle stops at 360
    _case('FrostToolbar/middle', () => _search((search) => _bar(middle: search)), envs: [wide, ..._envs]),
    _case(
      'FrostToolbar/middle#focus',
      () => _search((search) => _bar(middle: search)),
      act: tapField,
      envs: _envs,
    ),
    _case(
      'FrostToolbar/middle+leading+trailing',
      () => _search((search) => _bar(title: _title, middle: search, trailing: [_action()])),
      envs: [wide, ..._envs],
    ),
    _case(
      'FrostToolbar/middleMaxWidth=default',
      () => _search((search) => _bar(middle: search, trailing: [_action()])),
      envs: [wide, ..._envs],
    ),
    _case(
      'FrostToolbar/collapsedMiddle',
      () => _search((search) => _bar(title: _title, middle: search, collapsedMiddle: _collapsed, trailing: _many())),
      envs: [wide, ..._envs],
    ),
    _case(
      'FrostToolbar/collapsedMiddle#hover',
      () => _search((search) => _bar(title: _title, middle: search, collapsedMiddle: _collapsed, trailing: _many())),
      envs: [BaselineEnv.narrow],
      act: baselineHover,
    ),

    // trailing
    _case('FrostToolbar/trailing=action', () => _bar(trailing: [_action()]), envs: BaselineEnv.all),
    _case('FrostToolbar/trailing=action#hover', () => _bar(trailing: [_action()]), act: baselineHover),
    _case('FrostToolbar/trailing=action#press', () => _bar(trailing: [_action()]), act: baselinePress),
    _case('FrostToolbar/trailing=action#focus', () => _bar(trailing: [_action()]), act: baselineFocus),
    _case('FrostToolbar/trailing=action+onPressed=null', () => _bar(trailing: [_action(onPressed: null)])),
    _case('FrostToolbar/trailing=action+showsLabel', () => _bar(trailing: [_action(showsLabel: true)]), envs: _envs),
    for (final priority in FrostToolbarPriority.values)
      _case(
        'FrostToolbar/trailing=action+priority=${priority.name}',
        () => _bar(
          title: _title,
          trailing: [
            _action(priority: priority, label: 'One'),
            _action(label: 'Two'),
            _action(label: 'Three'),
          ],
        ),
        envs: _envs,
      ),
    _case(
      'FrostToolbar/trailing=picker',
      () => _bar(
        trailing: [FrostToolbarItem.picker<String>(choices: _choices, value: 'grid', onChanged: _changed, label: 'View')],
      ),
      envs: _envs,
    ),
    _case(
      'FrostToolbar/trailing=picker+priority=high',
      () => _bar(
        trailing: [FrostToolbarItem.picker<String>(choices: _choices, value: 'grid', onChanged: _changed, label: 'View', priority: FrostToolbarPriority.high)],
      ),
      envs: _envs,
    ),
    _case('FrostToolbar/trailing=menu', () => _bar(trailing: [_menu()]), envs: _envs),
    _case('FrostToolbar/trailing=menu#open', () => _bar(trailing: [_menu()]), act: tapButton),
    _case(
      'FrostToolbar/trailing=menu+valueLabel',
      () => _bar(trailing: [_menu(valueLabel: 'Two')]),
      envs: _envs,
    ),
    _case(
      'FrostToolbar/trailing=menu+icon',
      () => _bar(trailing: [_menu(icon: baselineIcon)]),
      envs: _envs,
    ),
    _case(
      'FrostToolbar/trailing=menu+showsLabel=false',
      () => _bar(trailing: [_menu(showsLabel: false, icon: baselineIcon)]),
      envs: _envs,
    ),
    _case(
      'FrostToolbar/trailing=sortMenu',
      () => _bar(
        trailing: [FrostToolbarItem.sortMenu<String>(fields: _fields, value: 'name', ascending: true, onChanged: _sorted, label: 'Sort')],
      ),
      envs: _envs,
    ),
    _case(
      'FrostToolbar/trailing=sortMenu#open',
      () => _bar(
        trailing: [FrostToolbarItem.sortMenu<String>(fields: _fields, value: 'name', ascending: false, onChanged: _sorted, label: 'Sort')],
      ),
      act: tapButton,
    ),
    _case('FrostToolbar/trailing=custom', () => _bar(trailing: [_custom()]), envs: _envs),
    _case(
      'FrostToolbar/trailing=many',
      () => _bar(title: _title, trailing: _many()),
      envs: [wide, ..._envs],
    ),

    // overflow (the More menu)
    _case(
      'FrostToolbar/trailing=many#open',
      () => _bar(title: _title, trailing: _many()),
      act: tapMore,
      envs: [BaselineEnv.narrow, const BaselineEnv(width: 300)],
    ),
  ]);
}
