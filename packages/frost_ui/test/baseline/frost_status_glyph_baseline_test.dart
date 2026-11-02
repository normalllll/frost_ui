import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void main() {
  baselineGroup('FrostStatusGlyph', [
    const BaselineCase('FrostStatusGlyph/required', _required, envs: BaselineEnv.all),
    for (final kind in FrostStatusGlyphKind.values)
      BaselineCase('FrostStatusGlyph/kind=${kind.name}', (_) => FrostStatusGlyph(kind: kind, size: 24), envs: BaselineEnv.themes),
    for (final size in [12.0, 16.0, 40.0])
      BaselineCase('FrostStatusGlyph/size=${size.toInt()}', (_) => FrostStatusGlyph(kind: FrostStatusGlyphKind.success, size: size)),
    for (final kind in FrostStatusGlyphKind.values)
      BaselineCase('FrostStatusGlyph/kind=${kind.name}+color', (_) => FrostStatusGlyph(kind: kind, size: 24, color: const Color(0xFF3366CC))),
    const BaselineCase('FrostStatusGlyph/animate=false', _static),
  ]);
}

Widget _required(BuildContext context) => const FrostStatusGlyph(kind: FrostStatusGlyphKind.success, size: 24);
Widget _static(BuildContext context) => const FrostStatusGlyph(kind: FrostStatusGlyphKind.failure, size: 24, animate: false);
