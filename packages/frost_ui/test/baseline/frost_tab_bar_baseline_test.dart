import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _tapped(int _) {}

const _tabs = [FrostTab(label: 'Overview'), FrostTab(label: 'Files'), FrostTab(label: 'Activity')];
const _iconTabs = [
  FrostTab(label: 'Overview', icon: baselineIcon),
  FrostTab(label: 'Files', icon: baselineIcon),
  FrostTab(label: 'Activity', icon: baselineIcon),
];
const _secondaryTabs = [FrostTab(label: 'Overview', secondaryLabel: '3'), FrostTab(label: 'Files', secondaryLabel: '12'), FrostTab(label: 'Activity')];
const _manyTabs = [
  FrostTab(label: 'Overview'),
  FrostTab(label: 'Files'),
  FrostTab(label: 'Activity'),
  FrostTab(label: 'Comments'),
  FrostTab(label: 'Settings'),
  FrostTab(label: 'Permissions'),
  FrostTab(label: 'Integrations'),
  FrostTab(label: 'Billing'),
];

/// Owns a [FrostTabController] for the tab bar's `controller` argument.
class _Controller extends StatefulWidget {
  const _Controller({required this.length, required this.builder, this.index = 0});

  final int length, index;
  final Widget Function(FrostTabController controller) builder;

  @override
  State<_Controller> createState() => _ControllerState();
}

class _ControllerState extends State<_Controller> with SingleTickerProviderStateMixin {
  late final _controller = FrostTabController(length: widget.length, vsync: this, initialIndex: widget.index);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(_controller);
}

// The bar reads FrostDefaultTabController when it is given no controller.
Widget _bar(List<FrostTab> tabs, {int index = 0, bool scrollable = false, ValueChanged<int>? onTap, FrostControlSize? size, bool showDivider = false}) =>
    FrostDefaultTabController(
      length: tabs.length,
      initialIndex: index,
      child: FrostTabBar(tabs: tabs, scrollable: scrollable, onTap: onTap, size: size, showDivider: showDivider),
    );

void main() {
  baselineGroup('FrostTabBar', [
    BaselineCase('FrostTabBar/required', (_) => _bar(_tabs), envs: BaselineEnv.all),
    BaselineCase('FrostTabBar/tabs=icon', (_) => _bar(_iconTabs), envs: BaselineEnv.themes),
    BaselineCase('FrostTabBar/tabs=secondaryLabel', (_) => _bar(_secondaryTabs), envs: BaselineEnv.themes),
    BaselineCase(
      'FrostTabBar/controller',
      (_) => _Controller(
        length: 3,
        index: 1,
        builder: (controller) => FrostTabBar(tabs: _tabs, controller: controller),
      ),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostTabBar/scrollable', (_) => _bar(_manyTabs, scrollable: true), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostTabBar/scrollable+selected=last', (_) => _bar(_manyTabs, index: 7, scrollable: true), envs: [BaselineEnv.narrow]),
    BaselineCase('FrostTabBar/onTap', (_) => _bar(_tabs, onTap: _tapped)),
    for (final size in FrostControlSize.values)
      BaselineCase('FrostTabBar/size=${size.name}', (_) => _bar(_tabs, size: size), envs: [BaselineEnv.standard, BaselineEnv.touch]),
    BaselineCase('FrostTabBar/showDivider', (_) => _bar(_tabs, showDivider: true), envs: BaselineEnv.themes),
    BaselineCase('FrostTabBar/required#hover', (_) => _bar(_tabs), act: baselineHover),
    BaselineCase('FrostTabBar/required#press', (_) => _bar(_tabs), act: baselinePress),
    BaselineCase('FrostTabBar/required#focus', (_) => _bar(_tabs), act: baselineFocus),
    BaselineCase('FrostTabBar/onTap#selected', (_) => _bar(_tabs, onTap: _tapped), act: baselineTap),
  ]);
}
