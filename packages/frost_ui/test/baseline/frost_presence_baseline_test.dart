import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _content = SizedBox(width: 160, height: 48, child: Center(child: FrostText('Content')));

/// Neighbours show whether the presence keeps or gives back its space.
Widget _around(Widget presence, {Axis axis = Axis.vertical}) => axis == Axis.vertical
    ? Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const FrostText('Before'), presence, const FrostText('After')],
      )
    : Row(mainAxisSize: MainAxisSize.min, children: [const FrostText('Before'), presence, const FrostText('After')]);

Widget _toggling(FrostPresenceEffect effect, {Axis axis = Axis.vertical}) => _Toggling(effect: effect, axis: axis);

/// Starts shown and hides on the first tap of the subject, to record the state after the dismissal.
class _Toggling extends StatefulWidget {
  const _Toggling({required this.effect, required this.axis});
  final FrostPresenceEffect effect;
  final Axis axis;
  @override
  State<_Toggling> createState() => _TogglingState();
}

class _TogglingState extends State<_Toggling> {
  bool _visible = true;
  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => setState(() => _visible = !_visible),
    child: _around(
      FrostPresence(visible: _visible, effect: widget.effect, axis: widget.axis, child: _content),
      axis: widget.axis,
    ),
  );
}

void main() {
  baselineGroup('FrostPresence', [
    BaselineCase('FrostPresence/required', (_) => _around(const FrostPresence(visible: true, child: _content)), envs: BaselineEnv.all),
    BaselineCase('FrostPresence/visible=false', (_) => _around(const FrostPresence(visible: false, child: _content)), envs: BaselineEnv.themes),
    BaselineCase('FrostPresence/effect=expand', (_) => _around(const FrostPresence(visible: true, effect: FrostPresenceEffect.expand, child: _content))),
    BaselineCase(
      'FrostPresence/effect=expand+visible=false',
      (_) => _around(const FrostPresence(visible: false, effect: FrostPresenceEffect.expand, child: _content)),
    ),
    BaselineCase(
      'FrostPresence/axis=horizontal',
      (_) => _around(
        const FrostPresence(visible: true, effect: FrostPresenceEffect.expand, axis: Axis.horizontal, child: _content),
        axis: Axis.horizontal,
      ),
    ),
    BaselineCase(
      'FrostPresence/axis=horizontal+visible=false',
      (_) => _around(
        const FrostPresence(visible: false, effect: FrostPresenceEffect.expand, axis: Axis.horizontal, child: _content),
        axis: Axis.horizontal,
      ),
    ),
    BaselineCase(
      'FrostPresence/alignment=topStart',
      (_) => _around(const FrostPresence(visible: true, alignment: AlignmentDirectional.topStart, child: _content)),
    ),
    BaselineCase(
      'FrostPresence/effect=expand+alignment=topStart',
      (_) => _around(const FrostPresence(visible: true, effect: FrostPresenceEffect.expand, alignment: AlignmentDirectional.topStart, child: _content)),
    ),

    // Hiding after mount: the outgoing content leaves and the slot closes.
    BaselineCase(
      'FrostPresence/effect=fadeScale#hidden',
      (_) => _toggling(FrostPresenceEffect.fadeScale),
      act: (tester, subject) => tester.tap(find.text('Before')),
    ),
    BaselineCase('FrostPresence/effect=expand#hidden', (_) => _toggling(FrostPresenceEffect.expand), act: (tester, subject) => tester.tap(find.text('Before'))),
    BaselineCase(
      'FrostPresence/axis=horizontal#hidden',
      (_) => _toggling(FrostPresenceEffect.expand, axis: Axis.horizontal),
      act: (tester, subject) => tester.tap(find.text('Before')),
    ),
  ]);
}
