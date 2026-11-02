import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import '../media_test_image.dart';
import 'baseline.dart';

const _child = Center(child: FrostText('Window content'));
const _height = 240.0;

void main() {
  baselineGroup('FrostAmbientBackdropHost', [
    BaselineCase(
      'FrostAmbientBackdropHost/required',
      (_) => const FrostAmbientBackdropHost(image: null, child: _child),
      height: _height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostAmbientBackdropHost/image',
      (_) => FrostAmbientBackdropHost(image: mediaTestImage, child: _child),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase('FrostAmbientBackdropHost/intensity=0', (_) => const FrostAmbientBackdropHost(image: null, intensity: 0, child: _child), height: _height),
    BaselineCase('FrostAmbientBackdropHost/intensity=.5', (_) => const FrostAmbientBackdropHost(image: null, intensity: .5, child: _child), height: _height),
    BaselineCase(
      'FrostAmbientBackdropHost/fallback=none',
      (_) => const FrostAmbientBackdropHost(image: null, fallback: FrostAmbientFallback.none, child: _child),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostAmbientBackdropHost/fallback=accentWash',
      (_) => const FrostAmbientBackdropHost(image: null, fallback: FrostAmbientFallback.accentWash, child: _child),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostAmbientBackdropHost/fallback=accentWash+intensity=0',
      (_) => const FrostAmbientBackdropHost(image: null, fallback: FrostAmbientFallback.accentWash, intensity: 0, child: _child),
      height: _height,
    ),
    BaselineCase(
      'FrostAmbientBackdropHost/fallback=accentWash+intensity=.5',
      (_) => const FrostAmbientBackdropHost(image: null, fallback: FrostAmbientFallback.accentWash, intensity: .5, child: _child),
      height: _height,
    ),
  ]);
}
