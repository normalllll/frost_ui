import 'package:flutter/widgets.dart';
import 'package:frost_ui/src/primitives/caption_glyph.dart' show FrostCaptionGlyph, FrostCaptionGlyphKind;

import 'baseline.dart';

const _ink = Color(0xFF808080);

void main() {
  baselineGroup('FrostCaptionGlyph', [
    const BaselineCase('FrostCaptionGlyph/required', _required, envs: BaselineEnv.all),
    for (final kind in FrostCaptionGlyphKind.values)
      BaselineCase('FrostCaptionGlyph/kind=${kind.name}', (_) => FrostCaptionGlyph(kind, color: _ink), envs: BaselineEnv.themes),
    const BaselineCase('FrostCaptionGlyph/color', _colored, envs: BaselineEnv.themes),
    const BaselineCase('FrostCaptionGlyph/size', _sized),
    const BaselineCase('FrostCaptionGlyph/size=large', _large),
  ]);
}

Widget _required(BuildContext context) => const FrostCaptionGlyph(FrostCaptionGlyphKind.minimize, color: _ink);
Widget _colored(BuildContext context) => const FrostCaptionGlyph(FrostCaptionGlyphKind.close, color: Color(0xFFD93025));
Widget _sized(BuildContext context) => const FrostCaptionGlyph(FrostCaptionGlyphKind.maximize, color: _ink, size: 16);
Widget _large(BuildContext context) => const FrostCaptionGlyph(FrostCaptionGlyphKind.restore, color: _ink, size: 24);
