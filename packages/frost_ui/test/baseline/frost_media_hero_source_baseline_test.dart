import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import '../media_test_image.dart';
import 'baseline.dart';

const _cover = ColoredBox(
  color: Color(0xFF5577AA),
  child: Center(child: FrostText('Hero child', tone: FrostTextTone.primary)),
);

Widget _source({double aspectRatio = 1.5, Object? identity}) => FrostMediaHeroSource(
  image: mediaTestImage,
  aspectRatio: aspectRatio,
  identity: identity,
  builder: (context, tag) => SizedBox(
    width: 240,
    height: 160,
    child: FrostMediaHero(tag: tag, child: _cover),
  ),
);

void main() {
  baselineGroup('FrostMediaHeroSource', [
    BaselineCase('FrostMediaHeroSource/required', (_) => _source(), envs: [...BaselineEnv.themes, BaselineEnv.narrow]),
    BaselineCase('FrostMediaHeroSource/aspectRatio=1', (_) => _source(aspectRatio: 1)),
    BaselineCase('FrostMediaHeroSource/identity', (_) => _source(identity: 'work-1')),
    // The builder receives a tag carrying the source's ratio.
    BaselineCase(
      'FrostMediaHeroSource/tagProbe',
      (_) => FrostMediaHeroSource(
        image: mediaTestImage,
        aspectRatio: 1.5,
        builder: (context, tag) => FrostText('ratio=${tag.aspectRatio}', tone: FrostTextTone.primary),
      ),
    ),
  ]);
}
