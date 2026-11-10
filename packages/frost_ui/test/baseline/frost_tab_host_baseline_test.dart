import 'package:flutter/widgets.dart';
import 'package:frost_ui/desktop.dart';

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

Widget _page(BuildContext context, String tab) => Center(child: Text('Page of $tab'));

// A tab host fills its parent, so every case gives it a height.
BaselineCase _case(String id, Widget Function() build, {List<BaselineEnv> envs = const [BaselineEnv.standard], BaselineAct? act}) =>
    BaselineCase(id, (_) => build(), height: 200, envs: envs, act: act);

Widget _host({int count = 1, int active = 0, bool base = false, VoidCallback? onNewTab, VoidCallback? onReopen}) => TabsHost(
  count: count,
  active: active,
  base: base,
  builder: (context, controller) => FrostTabHost<String>(controller: controller, builder: _page, onNewTab: onNewTab, onReopen: onReopen),
);

void main() {
  baselineGroup('FrostTabHost', [
    _case('FrostTabHost/required', () => _host(), envs: BaselineEnv.all),
    _case('FrostTabHost/tabs=3', () => _host(count: 3), envs: BaselineEnv.themes),
    _case('FrostTabHost/tabs=3+active', () => _host(count: 3, active: 2)),
    _case('FrostTabHost/tabs=baseTab', () => _host(count: 2, base: true, active: 1)),
    _case('FrostTabHost/onNewTab', () => _host(onNewTab: _noop)),
    _case('FrostTabHost/onReopen', () => _host(onReopen: _noop)),
  ]);
}
