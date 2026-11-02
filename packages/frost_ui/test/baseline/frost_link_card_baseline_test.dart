import 'dart:async';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/social.dart';

import '../media_test_image.dart';
import 'baseline.dart';

void _noop() {}

final _url = Uri.parse('https://example.com/articles/frost');
const _description = 'A short description of the linked article that is long enough to need a second line in a narrow card.';

/// Decodes [mediaTestImage] outside the test's fake clock, so the card shows
/// its image slot instead of waiting for the picture.
Future<void> _loadImage(WidgetTester tester, Finder subject) async {
  await tester.runAsync(() => precacheImage(mediaTestImage, tester.element(subject)));
}

void main() {
  baselineGroup('FrostLinkCard', [
    BaselineCase(
      'FrostLinkCard/required',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostLinkCard/description',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, description: _description),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostLinkCard/title=long',
      (_) => FrostLinkCard(title: 'A very long title that goes on and on until it has to be truncated after the second line of text', url: _url),
      envs: [BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostLinkCard/image',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, image: mediaTestImage),
      act: (tester, subject) => _loadImage(tester, subject),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostLinkCard/image=pending', (_) => FrostLinkCard(title: 'Frost UI released', url: _url, image: const _PendingImage())),
    BaselineCase(
      'FrostLinkCard/image+description',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, description: _description, image: mediaTestImage),
      act: (tester, subject) => _loadImage(tester, subject),
    ),
    BaselineCase(
      'FrostLinkCard/style=row',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, style: FrostLinkCardStyle.row, description: _description),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostLinkCard/style=large',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, description: _description, style: FrostLinkCardStyle.large),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostLinkCard/style=large+image',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, description: _description, image: mediaTestImage, style: FrostLinkCardStyle.large),
      act: (tester, subject) => _loadImage(tester, subject),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostLinkCard/onPressed',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, onPressed: _noop),
      envs: [BaselineEnv.standard, BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostLinkCard/onPressed#hover',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostLinkCard/onPressed#press',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, onPressed: _noop),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostLinkCard/onPressed#focus',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, onPressed: _noop),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostLinkCard/style=large+onPressed#hover',
      (_) => FrostLinkCard(title: 'Frost UI released', url: _url, style: FrostLinkCardStyle.large, onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostLinkCard.skeleton/required',
      (_) => FrostLinkCard.skeleton(style: FrostLinkCardStyle.row, image: true, title: 'Frost UI released', description: _description, host: 'example.com'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostLinkCard.skeleton/style=large',
      (_) => FrostLinkCard.skeleton(style: FrostLinkCardStyle.large, image: true, title: 'Frost UI released', description: _description, host: 'example.com'),
    ),
    BaselineCase(
      'FrostLinkCard.skeleton/image=false',
      (_) => FrostLinkCard.skeleton(style: FrostLinkCardStyle.row, image: false, title: 'Frost UI released', description: null, host: 'example.com'),
    ),
  ]);
}

/// An image that never finishes loading: the card shows no image slot yet.
class _PendingImage extends ImageProvider<_PendingImage> {
  const _PendingImage();
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_PendingImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}
