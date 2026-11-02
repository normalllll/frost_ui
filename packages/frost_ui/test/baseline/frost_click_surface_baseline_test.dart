import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}
void _changed(bool _) {}

const _radius = BorderRadius.all(Radius.circular(12));
const _child = SizedBox(width: 160, height: 48, child: Center(child: FrostText('Surface')));
const _round = SizedBox.square(dimension: 56, child: Center(child: FrostIcon(baselineIcon)));

void main() {
  baselineGroup('FrostClickSurface', [
    const BaselineCase('FrostClickSurface/required', _required, envs: BaselineEnv.all),

    // Callbacks.
    const BaselineCase('FrostClickSurface/onTap', _onTap, envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.touch]),
    const BaselineCase('FrostClickSurface/onTap#hover', _onTap, act: baselineHover),
    const BaselineCase('FrostClickSurface/onTap#press', _onTap, act: baselinePress),
    const BaselineCase('FrostClickSurface/onTap#focus', _onTap, act: baselineFocus),
    const BaselineCase('FrostClickSurface/onTap#hover+light', _onTap, act: baselineHover, envs: [BaselineEnv.light]),
    const BaselineCase('FrostClickSurface/onTap#press+light', _onTap, act: baselinePress, envs: [BaselineEnv.light]),
    const BaselineCase('FrostClickSurface/onLongPress', _onLongPress),
    const BaselineCase('FrostClickSurface/onLongPress#hover', _onLongPress, act: baselineHover),
    const BaselineCase('FrostClickSurface/onOpenInBackground', _onOpenInBackground),
    const BaselineCase('FrostClickSurface/onOpenInNewTab', _onOpenInNewTab),
    const BaselineCase('FrostClickSurface/onHover', _onHover),
    const BaselineCase('FrostClickSurface/onHover#hover', _onHover, act: baselineHover),
    const BaselineCase('FrostClickSurface/onFocusChange#focus', _onFocusChange, act: baselineFocus),
    const BaselineCase('FrostClickSurface/onPressedChange#press', _onPressedChange, act: baselinePress),

    // Feedback kinds.
    for (final feedback in FrostClickFeedback.values) ...[
      BaselineCase(
        'FrostClickSurface/feedback=${feedback.name}',
        (_) => FrostClickSurface(onTap: _noop, feedback: feedback, child: _child),
        envs: BaselineEnv.themes,
      ),
      BaselineCase(
        'FrostClickSurface/feedback=${feedback.name}#hover',
        (_) => FrostClickSurface(onTap: _noop, feedback: feedback, child: _child),
        act: baselineHover,
      ),
      BaselineCase(
        'FrostClickSurface/feedback=${feedback.name}#press',
        (_) => FrostClickSurface(onTap: _noop, feedback: feedback, child: _child),
        act: baselinePress,
      ),
    ],

    // Shape: rounded corners.
    const BaselineCase('FrostClickSurface/borderRadius', _borderRadius, envs: BaselineEnv.themes),
    const BaselineCase('FrostClickSurface/borderRadius#hover', _borderRadius, act: baselineHover),
    const BaselineCase('FrostClickSurface/borderRadius#press', _borderRadius, act: baselinePress),
    const BaselineCase('FrostClickSurface/borderRadius#focus', _borderRadius, act: baselineFocus),

    // Shape: circle and rounded rectangle.
    const BaselineCase('FrostClickSurface/customBorder=circle', _circle, envs: BaselineEnv.themes),
    const BaselineCase('FrostClickSurface/customBorder=circle#hover', _circle, act: baselineHover),
    const BaselineCase('FrostClickSurface/customBorder=circle#press', _circle, act: baselinePress),
    const BaselineCase('FrostClickSurface/customBorder=circle#focus', _circle, act: baselineFocus),

    // Focus and cursor.
    const BaselineCase('FrostClickSurface/autofocus', _autofocus),
    const BaselineCase('FrostClickSurface/focusNode', _focusNode),
    const BaselineCase('FrostClickSurface/mouseCursor#hover', _cursor, act: baselineHover),
    const BaselineCase('FrostClickSurface/required#hover', _required, act: baselineHover),
  ]);
}

final _node = FocusNode(debugLabel: 'baseline');

Widget _required(BuildContext context) => const FrostClickSurface(child: _child);
Widget _onTap(BuildContext context) => const FrostClickSurface(onTap: _noop, child: _child);
Widget _onLongPress(BuildContext context) => const FrostClickSurface(onLongPress: _noop, child: _child);
Widget _onOpenInBackground(BuildContext context) => const FrostClickSurface(onTap: _noop, onOpenInBackground: _noop, child: _child);
Widget _onOpenInNewTab(BuildContext context) => const FrostClickSurface(onTap: _noop, onOpenInNewTab: _noop, child: _child);
Widget _onHover(BuildContext context) => const FrostClickSurface(onTap: _noop, onHover: _changed, child: _child);
Widget _onFocusChange(BuildContext context) => const FrostClickSurface(onTap: _noop, onFocusChange: _changed, child: _child);
Widget _onPressedChange(BuildContext context) => const FrostClickSurface(onTap: _noop, onPressedChange: _changed, child: _child);
Widget _borderRadius(BuildContext context) => const FrostClickSurface(onTap: _noop, shape: FrostClickShape.rounded(_radius), child: _child);
Widget _circle(BuildContext context) => const FrostClickSurface(onTap: _noop, shape: FrostClickShape.circle(), child: _round);
Widget _autofocus(BuildContext context) => const FrostClickSurface(onTap: _noop, autofocus: true, child: _child);
Widget _focusNode(BuildContext context) => FrostClickSurface(onTap: _noop, focusNode: _node, child: _child);
Widget _cursor(BuildContext context) => const FrostClickSurface(onTap: _noop, mouseCursor: SystemMouseCursors.help, child: _child);
