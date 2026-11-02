import 'dart:async';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/social.dart';

import '../media_test_image.dart';
import 'baseline.dart';

void _noopIndex(int _) {}

/// Decodes [mediaTestImage] outside the test's fake clock, so the cells show
/// their picture instead of waiting for it.
Future<void> _load(WidgetTester tester, Finder subject) async {
  await tester.runAsync(() => precacheImage(mediaTestImage, tester.element(subject)));
}

List<ImageProvider> _images(int count) => List.generate(count, (_) => mediaTestImage);

FrostMediaHeroTag _tag(int _) => FrostMediaHeroTag(image: mediaTestImage, aspectRatio: 1);

String _label(int index) => 'Image ${index + 1}';

void main() {
  baselineGroup('FrostMediaMosaic', [
    BaselineCase(
      'FrostMediaMosaic/required',
      (_) => FrostMediaMosaic(images: _images(1)),
      act: _load,
      envs: BaselineEnv.all,
    ),
    for (final count in [2, 3, 4, 5])
      BaselineCase(
        'FrostMediaMosaic/images=$count',
        (_) => FrostMediaMosaic(images: _images(count)),
        act: _load,
        envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.narrow],
      ),
    BaselineCase('FrostMediaMosaic/images=2+pending', (_) => FrostMediaMosaic(images: const [_PendingImage(), _PendingImage()])),
    BaselineCase(
      'FrostMediaMosaic/sizes=landscape',
      (_) => FrostMediaMosaic(images: _images(1), sizes: const [Size(4, 3)]),
      act: _load,
    ),
    BaselineCase(
      'FrostMediaMosaic/sizes=wide',
      (_) => FrostMediaMosaic(images: _images(1), sizes: const [Size(4, 1)]),
      act: _load,
    ),
    BaselineCase(
      'FrostMediaMosaic/sizes=tall',
      (_) => FrostMediaMosaic(images: _images(1), sizes: const [Size(1, 4)]),
      act: _load,
    ),
    BaselineCase(
      'FrostMediaMosaic/sizes=unknown',
      (_) => FrostMediaMosaic(images: _images(1), sizes: const [null]),
      act: _load,
    ),
    BaselineCase(
      'FrostMediaMosaic/sizes=multiple',
      (_) => FrostMediaMosaic(images: _images(3), sizes: const [Size(4, 3), Size(1, 1), null]),
      act: _load,
    ),
    BaselineCase(
      'FrostMediaMosaic/onPressed',
      (_) => FrostMediaMosaic(images: _images(2), onPressed: _noopIndex),
      act: _load,
      envs: [BaselineEnv.standard, BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostMediaMosaic/onPressed#hover',
      (_) => FrostMediaMosaic(images: _images(2), onPressed: _noopIndex),
      act: (tester, subject) async {
        await _load(tester, subject);
        await baselineHover(tester, subject);
      },
    ),
    BaselineCase(
      'FrostMediaMosaic/onPressed#press',
      (_) => FrostMediaMosaic(images: _images(2), onPressed: _noopIndex),
      act: (tester, subject) async {
        await _load(tester, subject);
        await baselinePress(tester, subject);
      },
    ),
    BaselineCase(
      'FrostMediaMosaic/onPressed#focus',
      (_) => FrostMediaMosaic(images: _images(2), onPressed: _noopIndex),
      act: (tester, subject) async {
        await _load(tester, subject);
        await baselineFocus(tester, subject);
      },
    ),
    BaselineCase(
      'FrostMediaMosaic/semanticLabel',
      (_) => FrostMediaMosaic(images: _images(2), semanticLabel: _label),
      act: _load,
    ),
    BaselineCase(
      'FrostMediaMosaic/semanticLabel+onPressed',
      (_) => FrostMediaMosaic(images: _images(2), onPressed: _noopIndex, semanticLabel: _label),
      act: _load,
    ),
    BaselineCase(
      'FrostMediaMosaic/heroTag',
      (_) => FrostMediaMosaic(images: _images(2), heroTag: _tag),
      act: _load,
    ),
    BaselineCase(
      'FrostMediaMosaic/onPressed+heroTag+semanticLabel',
      (_) => FrostMediaMosaic(images: _images(3), onPressed: _noopIndex, heroTag: _tag, semanticLabel: _label),
      act: _load,
    ),
    BaselineCase('FrostMediaMosaic.skeleton/required', (_) => FrostMediaMosaic.skeleton(count: 1, sizes: const [Size(4, 3)]), envs: BaselineEnv.all),
    for (final count in [2, 3, 4])
      BaselineCase('FrostMediaMosaic.skeleton/count=$count', (_) => FrostMediaMosaic.skeleton(count: count, sizes: List.filled(count, null))),
    BaselineCase('FrostMediaMosaic.skeleton/count=6', (_) => FrostMediaMosaic.skeleton(count: 6, sizes: List.filled(4, null))),
    BaselineCase('FrostMediaMosaic.skeleton/sizes=wide', (_) => FrostMediaMosaic.skeleton(count: 1, sizes: const [Size(4, 1)])),
  ]);
}

/// An image that never finishes loading: the cells keep their placeholders.
class _PendingImage extends ImageProvider<_PendingImage> {
  const _PendingImage();
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_PendingImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}
