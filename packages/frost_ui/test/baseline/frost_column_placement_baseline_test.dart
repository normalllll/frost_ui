import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

// A content column reads the placement above it.
const _column = FrostContentColumn(
  maxWidth: 480,
  child: ColoredBox(
    color: Color(0x33888888),
    child: SizedBox(height: 48, child: FrostText('Column content', tone: FrostTextTone.primary)),
  ),
);

Widget _required(BuildContext context) => const FrostColumnPlacement(alignment: FrostColumnAlignment.start, child: _column);

final _wide = BaselineEnv.standard.copyWith(width: 1280);
final _wideOrNarrow = [_wide, BaselineEnv.narrow];

void main() {
  baselineGroup('FrostColumnPlacement', [
    const BaselineCase('FrostColumnPlacement/required', _required, envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.narrow]),
    for (final alignment in FrostColumnAlignment.values)
      BaselineCase(
        'FrostColumnPlacement/alignment=${alignment.name}',
        (_) => FrostColumnPlacement(alignment: alignment, child: _column),
        envs: _wideOrNarrow,
      ),
    for (final alignment in FrostColumnAlignment.values)
      BaselineCase(
        'FrostColumnPlacement/maxWidth=320+alignment=${alignment.name}',
        (_) => FrostColumnPlacement(alignment: alignment, maxWidth: 320, child: _column),
        envs: [_wide],
      ),
  ]);
}
