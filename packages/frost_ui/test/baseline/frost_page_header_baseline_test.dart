import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}
void _changed(String _) {}

const _entries = <FrostMenuEntry>[FrostMenuAction('Copy', onSelected: _noop), FrostMenuAction('Paste', onSelected: _noop)];
const _choices = [FrostPickerOption<String>(value: 'grid', label: 'Grid'), FrostPickerOption<String>(value: 'list', label: 'List')];

FrostToolbarItem _action({String label = 'Filter', FrostToolbarPriority priority = FrostToolbarPriority.normal}) =>
    FrostToolbarItem.action(icon: baselineIcon, label: label, priority: priority, onPressed: _noop);

List<FrostToolbarItem> _actions() => [
  _action(label: 'Share', priority: FrostToolbarPriority.high),
  _action(),
  FrostToolbarItem.menu(label: 'Options', entries: _entries, icon: baselineIcon, showsLabel: false),
];

const _collapsed = FrostButton.icon(icon: baselineIcon, label: 'Search', onPressed: _noop);

Widget _header({
  List<Widget>? leading,
  List<FrostToolbarItem>? controls,
  Widget? title,
  Widget? middle,
  Widget? collapsedMiddle,
  List<FrostToolbarItem>? actions,
  VoidCallback? onBack,
  FrostPageHeaderSearchController? searchController,
}) => windowed(
  Align(
    alignment: Alignment.topCenter,
    child: FrostPageHeader(
      leading: leading ?? const [],
      controls: controls ?? const [],
      title: title,
      middle: middle,
      collapsedMiddle: collapsedMiddle,
      actions: actions ?? const [],
      onBack: onBack,
      searchController: searchController,
    ),
  ),
);

Widget _search(Widget Function(Widget search, FrostPageHeaderSearchController controller) build) =>
    SearchHost(builder: (context, search, controller) => build(search, controller));

BaselineCase _case(String id, Widget Function() build, {List<BaselineEnv> envs = const [BaselineEnv.standard], BaselineAct? act}) =>
    BaselineCase(id, (_) => build(), envs: envs, act: act);

const _title = Text('Title');
const _envs = [BaselineEnv.standard, BaselineEnv.narrow];

void main() {
  baselineGroup('FrostPageHeader', [
    _case('FrostPageHeader/required', () => _header(), envs: [...BaselineEnv.all, wide, medium]),
    _case('FrostPageHeader/title', () => _header(title: _title), envs: [wide, medium, narrow, narrowTouch, BaselineEnv.light, BaselineEnv.largeText]),
    _case('FrostPageHeader/title=long', () => _header(title: const Text('A very long page title that has to be truncated in the row')), envs: _envs),
    _case(
      'FrostPageHeader/title=composed',
      () => _header(
        title: const Column(mainAxisSize: MainAxisSize.min, children: [Text('Title'), Text('Source')]),
      ),
      envs: _envs,
    ),
    _case('FrostPageHeader/title=frostText', () => _header(title: const FrostText('Title')), envs: _envs),
    _case(
      'FrostPageHeader/leading',
      () => _header(
        leading: const [FrostTitleMenu(title: 'Library', entries: _entries)],
      ),
      envs: _envs,
    ),
    _case(
      'FrostPageHeader/leading+title',
      () => _header(leading: const [_collapsed], title: _title),
      envs: _envs,
    ),
    _case(
      'FrostPageHeader/controls',
      () => _header(title: _title, controls: [_action()]),
      envs: _envs,
    ),
    _case(
      'FrostPageHeader/controls=picker',
      () => _header(
        title: _title,
        controls: [FrostToolbarItem.picker<String>(choices: _choices, value: 'grid', onChanged: _changed, label: 'View')],
      ),
      envs: _envs,
    ),
    _case(
      'FrostPageHeader/actions',
      () => _header(title: _title, actions: _actions()),
      envs: [wide, medium, narrow, narrowTouch],
    ),
    _case(
      'FrostPageHeader/actions#hover',
      () => _header(title: _title, actions: _actions()),
      act: baselineHover,
    ),
    _case(
      'FrostPageHeader/actions=many#open',
      () => _header(title: const Text('A long title'), actions: _many()),
      act: tapMore,
      envs: [BaselineEnv.narrow, const BaselineEnv(width: 300)],
    ),
    _case(
      'FrostPageHeader/actions=many',
      () => _header(
        title: _title,
        actions: [
          ..._actions(),
          _action(label: 'Archive', priority: FrostToolbarPriority.low),
        ],
      ),
      envs: _envs,
    ),

    // onBack: the compact Back control before the title.
    _case(
      'FrostPageHeader/onBack',
      () => _header(title: _title, onBack: _noop),
      envs: [wide, medium, narrow, narrowTouch],
    ),
    _case(
      'FrostPageHeader/onBack#hover',
      () => _header(title: _title, onBack: _noop),
      act: baselineHover,
    ),
    _case(
      'FrostPageHeader/onBack#press',
      () => _header(title: _title, onBack: _noop),
      act: baselinePress,
    ),
    _case(
      'FrostPageHeader/onBack#focus',
      () => _header(title: _title, onBack: _noop),
      act: baselineFocus,
    ),
    _case(
      'FrostPageHeader/onBack+actions',
      () => _header(title: _title, onBack: _noop, actions: _actions()),
      envs: _envs,
    ),

    // middle, collapsedMiddle; a header with a searchController is in search mode and its middle grows to 640.
    _case(
      'FrostPageHeader/middle',
      () => _search((search, _) => _header(title: _title, middle: search)),
      envs: [wide, medium, narrow, narrowTouch],
    ),
    _case(
      'FrostPageHeader/middle#focus',
      () => _search((search, _) => _header(title: _title, middle: search)),
      act: tapField,
      envs: [wide, medium, narrow, narrowTouch],
    ),
    _case(
      'FrostPageHeader/middle+actions',
      () => _search((search, _) => _header(title: _title, middle: search, actions: _actions())),
      envs: [wide, medium, narrow],
    ),
    _case(
      'FrostPageHeader/middle+actions#focus',
      () => _search((search, _) => _header(title: _title, middle: search, actions: _actions())),
      act: tapField,
      envs: [wide, narrow],
    ),
    _case(
      'FrostPageHeader/middle+onBack#focus',
      () => _search((search, _) => _header(onBack: _noop, middle: search, actions: _actions())),
      act: tapField,
      envs: [narrow],
    ),
    _case(
      'FrostPageHeader/middleMaxWidth=default',
      () => _search((search, _) => _header(middle: search, actions: _actions())),
      envs: [wide, medium, narrow],
    ),
    _case(
      'FrostPageHeader/middleMaxWidth=640',
      () => _search((search, controller) => _header(middle: search, searchController: controller, actions: _actions())),
      envs: [wide, medium, narrow],
    ),
    _case(
      'FrostPageHeader/middleMaxWidth=640#focus',
      () => _search((search, controller) => _header(middle: search, searchController: controller, actions: _actions())),
      act: tapField,
      envs: [medium, narrow],
    ),
    _case(
      'FrostPageHeader/collapsedMiddle',
      () => _search((search, _) => _header(title: _title, middle: search, collapsedMiddle: _collapsed, actions: _actions())),
      envs: [wide, medium, narrow],
    ),
    // On wide and medium windows a controller puts the header in search mode, so its middle grows to 640; the next case covers them.
    _case(
      'FrostPageHeader/searchController',
      () => _search((search, controller) => _header(title: _title, middle: search, searchController: controller)),
      envs: [narrow],
    ),
    _case(
      'FrostPageHeader/searchController+title=searchMode',
      () => _search((search, controller) => _header(title: _title, middle: search, searchController: controller)),
      envs: [wide, medium],
    ),
    _case(
      'FrostPageHeader/searchController#focus',
      () => _search((search, controller) => _header(title: _title, middle: search, searchController: controller)),
      act: tapField,
      envs: [narrow],
    ),
  ]);
}

List<FrostToolbarItem> _many() => [
  ..._actions(),
  FrostToolbarItem.picker<String>(choices: _choices, value: 'grid', onChanged: _changed, label: 'View'),
  _action(label: 'Archive', priority: FrostToolbarPriority.low),
  _action(label: 'Export', priority: FrostToolbarPriority.low),
];
