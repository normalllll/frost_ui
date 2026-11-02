import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import '../media_test_image.dart';
import 'baseline.dart';

const _child = Center(child: FrostText('Page content'));
const _height = 240.0;

void main() {
  baselineGroup('FrostAmbientBackdrop', [
    // Without a FrostAmbientBackdropHost above it, the backdrop paints the plain canvas.
    BaselineCase('FrostAmbientBackdrop/required', (_) => const FrostAmbientBackdrop(), height: _height, envs: BaselineEnv.all),
    BaselineCase(
      'FrostAmbientBackdrop/required+host',
      (_) => const FrostAmbientBackdropHost(
        image: null,
        child: Stack(
          children: [
            Positioned.fill(child: FrostAmbientBackdrop()),
            _child,
          ],
        ),
      ),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostAmbientBackdrop.fromImage/required',
      (_) => FrostAmbientBackdrop.fromImage(image: mediaTestImage, child: _child),
      height: _height,
      envs: BaselineEnv.all,
    ),
  ]);
}
