import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';
import 'feedback_baseline_support.dart';

const _first = SizedBox(height: 60, child: FrostText('First layout'));
const _second = SizedBox(height: 100, child: FrostText('Second layout'));

// A subject whose layout identity and content change when toggled.
Widget _switching({bool media = false}) => BaselineToggle(
  builder: (_, toggled) => media
      ? FrostLayoutCrossfade.media(layoutIdentity: toggled ? 'second' : 'first', child: toggled ? _second : _first)
      : FrostLayoutCrossfade(layoutIdentity: toggled ? 'second' : 'first', child: toggled ? _second : _first),
);

void main() {
  baselineGroup('FrostLayoutCrossfade', [
    // Defaults: the layout fade, then a 100 ms settle before it starts.
    BaselineCase(
      'FrostLayoutCrossfade/required',
      (_) => const FrostLayoutCrossfade(layoutIdentity: 'first', child: _first),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostLayoutCrossfade/required#changed', (_) => _switching(), act: baselineToggle, envs: BaselineEnv.themes),
    // The media box's spelling is FrostLayoutCrossfade.media (image fade, no
    // settle wait).
    BaselineCase(
      'FrostLayoutCrossfade/duration+settleDuration',
      (_) => const FrostLayoutCrossfade.media(layoutIdentity: 'first', child: _first),
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostLayoutCrossfade/duration+settleDuration#changed', (_) => _switching(media: true), act: baselineToggle, envs: BaselineEnv.themes),
    // A media-style swap: an image box replaced by another of the same size.
    BaselineCase(
      'FrostLayoutCrossfade/duration+settleDuration#replaced',
      (_) => BaselineToggle(
        builder: (_, toggled) => FrostLayoutCrossfade.media(
          layoutIdentity: toggled ? 'b' : 'a',
          child: SizedBox(width: 160, height: 90, child: ColoredBox(color: toggled ? const Color(0xff4466aa) : const Color(0xffaa6644))),
        ),
      ),
      act: baselineToggle,
    ),
  ]);
}
