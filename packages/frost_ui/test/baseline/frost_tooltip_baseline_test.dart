import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/overlays/tooltip.dart' show FrostTooltipX;

import 'baseline.dart';
import 'nav_overlay_support.dart';

void _noop() {}

const _shown = Duration(milliseconds: 700);

Widget _target() => const FrostButton(label: 'Target', onPressed: _noop);

void main() {
  baselineGroup('FrostTooltip', [
    BaselineCase(
      'FrostTooltip/required',
      (_) => FrostTooltip(message: 'Helpful hint', child: _target()),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostTooltip/required#hover',
      (_) => FrostTooltip(message: 'Helpful hint', child: _target()),
      act: hoverFor(_shown),
      envs: [...BaselineEnv.themes, BaselineEnv.largeText, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostTooltip/message=long#hover',
      (_) => FrostTooltip(message: List.filled(30, 'A long tooltip message').join(' '), child: _target()),
      act: hoverFor(_shown),
    ),
    BaselineCase('FrostTooltip/message=empty', (_) => FrostTooltip(message: '', child: _target())),
    BaselineCase('FrostTooltip/excludeFromSemantics', (_) => FrostTooltip(message: 'Helpful hint', excludeFromSemantics: true, child: _target())),
    BaselineCase(
      'FrostTooltip/excludeFromSemantics#hover',
      (_) => FrostTooltip(message: 'Helpful hint', excludeFromSemantics: true, child: _target()),
      act: hoverFor(_shown),
    ),
    BaselineCase(
      'FrostTooltip/required#focus',
      (_) => FrostTooltip(message: 'Helpful hint', child: _target()),
      act: baselineFocus,
    ),
    // The widget extension builds the same tree as the constructor.
    BaselineCase('FrostTooltipX.frostTooltip/required', (_) => _target().frostTooltip('Helpful hint'), envs: BaselineEnv.all),
    BaselineCase(
      'FrostTooltipX.frostTooltip/excludeFromSemantics',
      (_) => _target().frostTooltip('Helpful hint', excludeFromSemantics: true),
    ),
  ]);
}
