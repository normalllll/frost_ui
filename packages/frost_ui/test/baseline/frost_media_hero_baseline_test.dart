import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import '../media_test_image.dart';
import 'baseline.dart';

const _cover = ColoredBox(
  color: Color(0xFF5577AA),
  child: Center(child: FrostText('Hero child', tone: FrostTextTone.primary)),
);

// The tag is the identity of one card-to-detail pair, so every case makes its own.
FrostMediaHeroTag _tag({double aspectRatio = 1.5}) => FrostMediaHeroTag(image: mediaTestImage, aspectRatio: aspectRatio);

Widget _hero({double aspectRatio = 1.5, BoxFit fit = BoxFit.cover, double width = 240, double height = 160}) => SizedBox(
  width: width,
  height: height,
  child: FrostMediaHero(
    tag: _tag(aspectRatio: aspectRatio),
    fit: fit,
    child: _cover,
  ),
);

// A hero in a media frame takes the frame's corners.
Widget _heroInFrame(double radius) => SizedBox(
  width: 240,
  height: 160,
  child: FrostMediaFrame(
    radius: radius,
    child: FrostMediaHero(tag: _tag(), child: _cover),
  ),
);

void main() {
  baselineGroup('FrostMediaHero', [
    BaselineCase('FrostMediaHero/required', (_) => _hero(), envs: [...BaselineEnv.themes, BaselineEnv.narrow]),
    // The corners come from the media area around the hero, not from an argument.
    BaselineCase('FrostMediaHero/inFrame=zero', (_) => _heroInFrame(0)),
    BaselineCase('FrostMediaHero/inFrame=24', (_) => _heroInFrame(24), envs: BaselineEnv.themes),
    for (final fit in [BoxFit.cover, BoxFit.contain, BoxFit.fill, BoxFit.fitWidth, BoxFit.fitHeight])
      BaselineCase('FrostMediaHero/fit=${fit.name}', (_) => _hero(fit: fit, aspectRatio: 1)),
    BaselineCase('FrostMediaHero/required+tallTag', (_) => _hero(aspectRatio: .5)),
    BaselineCase('FrostMediaHero/required+wideTag', (_) => _hero(aspectRatio: 3)),
  ]);
}
