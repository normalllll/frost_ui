import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

Widget _probe(BuildContext context) =>
    FrostText('horizontal=${FrostAutoScaffold.usesHorizontalLayoutOf(context)} sizeClass=${FrostSizeClass.of(context).name}', tone: FrostTextTone.primary);

Widget _required(BuildContext context) => const FrostLayoutScope(child: Builder(builder: _probe));

void main() {
  baselineGroup('FrostLayoutScope', [
    const BaselineCase('FrostLayoutScope/required', _required, envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.touch]),
    for (final placement in FrostNavigationPlacement.values)
      BaselineCase(
        'FrostLayoutScope/navigationPlacement=${placement.name}',
        (_) => FrostLayoutScope(
          navigationPlacement: placement,
          child: const Builder(builder: _probe),
        ),
      ),
  ]);
}
