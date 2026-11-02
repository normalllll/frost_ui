import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

/// Gives a divider something to separate and a keyline to align to.
Widget _within(Widget divider, {Axis axis = Axis.horizontal}) => FrostKeyline(
  leadingRoom: 0,
  trailingRoom: 0,
  edgeDistanceStart: 0,
  edgeDistanceEnd: 0,
  insideContainer: false,
  contentStart: 48,
  child: axis == Axis.horizontal
      ? Column(mainAxisSize: MainAxisSize.min, children: [const SizedBox(height: 16), divider, const SizedBox(height: 16)])
      : SizedBox(
          height: 60,
          child: Row(mainAxisSize: MainAxisSize.min, children: [const SizedBox(width: 16), divider, const SizedBox(width: 16)]),
        ),
);

void main() {
  baselineGroup('FrostDivider', [
    BaselineCase('FrostDivider/required', (_) => _within(const FrostDivider()), envs: BaselineEnv.all),
    BaselineCase(
      'FrostDivider/axis=vertical',
      (_) => _within(const FrostDivider(axis: Axis.vertical), axis: Axis.vertical),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostDivider/inset=keyline', (_) => _within(const FrostDivider(inset: FrostDividerInset.keyline)), envs: BaselineEnv.themes),
    BaselineCase('FrostDivider/inset=none', (_) => _within(const FrostDivider(inset: FrostDividerInset.none))),
    BaselineCase('FrostDivider/length', (_) => _within(const FrostDivider(length: 120))),
    BaselineCase('FrostDivider/axis=vertical+length', (_) => _within(const FrostDivider(axis: Axis.vertical, length: 24), axis: Axis.vertical)),
    BaselineCase('FrostDivider/inset=keyline+length', (_) => _within(const FrostDivider(inset: FrostDividerInset.keyline, length: 200))),
    BaselineCase('FrostDivider/inset=keyline+noKeyline', (_) => const SizedBox(width: 300, child: FrostDivider(inset: FrostDividerInset.keyline))),
  ]);
}
