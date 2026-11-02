import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import '../media_test_image.dart';
import 'baseline.dart';

const _cover = ColoredBox(
  color: Color(0xFF5577AA),
  child: Center(child: FrostText('Hero child', tone: FrostTextTone.primary)),
);

// The tag is the identity of one card-to-detail pair, so every case makes its own.
Widget _hero({double aspectRatio = 1.5, BoxFit fit = BoxFit.cover}) => SizedBox(
  width: 240,
  height: 160,
  child: FrostMediaHero(
    tag: FrostMediaHeroTag(image: mediaTestImage, aspectRatio: aspectRatio),
    fit: fit,
    child: _cover,
  ),
);

void main() {
  baselineGroup('FrostMediaHeroTag', [
    // The tag has no pixels of its own: it rides on a hero and sets its ratio.
    BaselineCase('FrostMediaHeroTag/required', (_) => _hero(), envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase('FrostMediaHeroTag/aspectRatio=1', (_) => _hero(aspectRatio: 1)),
    BaselineCase('FrostMediaHeroTag/aspectRatio=2.4', (_) => _hero(aspectRatio: 2.4)),
  ]);
}
