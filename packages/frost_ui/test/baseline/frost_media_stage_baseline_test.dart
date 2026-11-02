import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _media = ColoredBox(
  color: Color(0xFF5577AA),
  child: Center(child: FrostText('Media', tone: FrostTextTone.primary)),
);

// A finite slot: the stage contains the media in it.
Widget _slot(Widget stage, {double width = 400, double height = 300}) => SizedBox(width: width, height: height, child: stage);

void main() {
  baselineGroup('FrostMediaStage', [
    BaselineCase(
      'FrostMediaStage/required',
      (_) => _slot(const FrostMediaStage(aspectRatio: 16 / 9, child: _media)),
      envs: [...BaselineEnv.themes, BaselineEnv.narrow],
    ),
    BaselineCase('FrostMediaStage/aspectRatio=1', (_) => _slot(const FrostMediaStage(aspectRatio: 1, child: _media))),
    BaselineCase('FrostMediaStage/aspectRatio=0.5', (_) => _slot(const FrostMediaStage(aspectRatio: .5, child: _media))),
    BaselineCase('FrostMediaStage/aspectRatio=3', (_) => _slot(const FrostMediaStage(aspectRatio: 3, child: _media))),
    // Unbounded height: the media grows to its full height at the available width.
    BaselineCase(
      'FrostMediaStage/aspectRatio=0.25+unboundedHeight',
      (_) => const SingleChildScrollView(child: FrostMediaStage(aspectRatio: .25, child: _media)),
      height: 500,
    ),
    BaselineCase(
      'FrostMediaStage/aspectRatio=1+unboundedWidth',
      (_) => const SizedBox(
        height: 200,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: FrostMediaStage(aspectRatio: 1, child: _media),
        ),
      ),
    ),
  ]);
}
