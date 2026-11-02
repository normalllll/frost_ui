import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

Widget _builder(BuildContext context, FrostSizeLayout layout, Orientation orientation, bool useHorizontalLayout) =>
    FrostText('${layout.sizeClass.name} ${orientation.name} horizontal=$useHorizontalLayout', tone: FrostTextTone.primary);

// The surface is at least 1280 wide, so a breakpoint raised to 1400 moves the
// size class down one tier.
Widget _required(BuildContext context) => const FrostAutoScaffold(builder: _builder);
Widget _mobile(BuildContext context) => const FrostAutoScaffold(builder: _builder, mobileBreakpoint: 1400);
Widget _tablet(BuildContext context) => const FrostAutoScaffold(builder: _builder, tabletBreakpoint: 1400);
Widget _desktop(BuildContext context) => const FrostAutoScaffold(builder: _builder, desktopBreakpoint: 1400);

void main() {
  baselineGroup('FrostAutoScaffold', [
    const BaselineCase('FrostAutoScaffold/required', _required, envs: BaselineEnv.themes),
    for (final placement in FrostNavigationPlacement.values)
      BaselineCase('FrostAutoScaffold/navigationPlacement=${placement.name}', (_) => FrostAutoScaffold(navigationPlacement: placement, builder: _builder)),
    const BaselineCase('FrostAutoScaffold/mobileBreakpoint', _mobile),
    const BaselineCase('FrostAutoScaffold/tabletBreakpoint', _tablet),
    const BaselineCase('FrostAutoScaffold/desktopBreakpoint', _desktop),
  ]);
}
