import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

late ui.Image _picture;

/// An image provider that has its pixels at once, never touches the engine
/// codec and never shares a cache entry with another case.
class _Loaded extends ImageProvider<Object> {
  const _Loaded();
  @override
  Future<Object> obtainKey(ImageConfiguration configuration) => SynchronousFuture(Object());
  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) =>
      OneFrameImageStreamCompleter(SynchronousFuture(ImageInfo(image: _picture.clone())));
}

/// Never finishes loading: the placeholder stays.
class _Pending extends ImageProvider<Object> {
  const _Pending();
  @override
  Future<Object> obtainKey(ImageConfiguration configuration) => SynchronousFuture(Object());
  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

/// Fails to load: the error content shows.
class _Failing extends ImageProvider<Object> {
  const _Failing();
  @override
  Future<Object> obtainKey(ImageConfiguration configuration) => SynchronousFuture(Object());
  @override
  ImageStreamCompleter loadImage(Object key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(Future<ImageInfo>.error(StateError('baseline')));
}

const _fill = ColoredBox(color: Color(0xFF3366CC), child: SizedBox.expand());
final _wide = [BaselineEnv.standard, BaselineEnv.narrow];
const _height = 200.0;

// Text, because the record shows text but not a plain fill colour.
Widget _placeholder(BuildContext context, double? progress) => const Center(child: FrostText('placeholder'));
Widget _error(BuildContext context, Object error) => const Center(child: FrostText('error'));

void main() {
  setUpAll(() async {
    _picture = await createTestImage(width: 64, height: 48);
  });

  baselineGroup('FrostMediaFrame', [
    // Default constructor, child mode.
    BaselineCase(
      'FrostMediaFrame/required',
      (_) => const FrostMediaFrame(child: _fill),
      height: _height,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostMediaFrame/aspectRatio',
      (_) => const FrostMediaFrame(aspectRatio: 16 / 9, child: _fill),
      envs: _wide,
    ),
    BaselineCase('FrostMediaFrame/aspectRatio=1', (_) => const FrostMediaFrame(aspectRatio: 1, child: _fill), envs: BaselineEnv.themes),
    BaselineCase('FrostMediaFrame/radius=0', (_) => const FrostMediaFrame(radius: 0, aspectRatio: 2, child: _fill)),
    BaselineCase('FrostMediaFrame/radius=24', (_) => const FrostMediaFrame(radius: 24, aspectRatio: 2, child: _fill)),
    BaselineCase('FrostMediaFrame/semanticLabel', (_) => const FrostMediaFrame(semanticLabel: 'Cover', aspectRatio: 2, child: _fill)),

    // Image-provider mode.
    BaselineCase('FrostMediaFrame/image', (_) => const FrostMediaFrame(image: _Loaded(), aspectRatio: 2), envs: BaselineEnv.themes),
    BaselineCase('FrostMediaFrame/image+height', (_) => const FrostMediaFrame(image: _Loaded()), height: _height),
    for (final fit in [BoxFit.cover, BoxFit.contain, BoxFit.fill])
      BaselineCase('FrostMediaFrame/image+fit=${fit.name}', (_) => FrostMediaFrame(image: const _Loaded(), aspectRatio: 2, fit: fit)),
    BaselineCase('FrostMediaFrame/image+radius=0', (_) => const FrostMediaFrame(image: _Loaded(), radius: 0, aspectRatio: 2)),
    BaselineCase('FrostMediaFrame/image+semanticLabel', (_) => const FrostMediaFrame(image: _Loaded(), semanticLabel: 'Cover', aspectRatio: 2)),
    BaselineCase('FrostMediaFrame/image=pending', (_) => const FrostMediaFrame(image: _Pending(), aspectRatio: 2), envs: BaselineEnv.themes),
    BaselineCase(
      'FrostMediaFrame/image=pending+placeholderBuilder',
      (_) => const FrostMediaFrame(image: _Pending(), aspectRatio: 2, placeholderBuilder: _placeholder),
    ),
    BaselineCase('FrostMediaFrame/image=failing', (_) => const FrostMediaFrame(image: _Failing(), aspectRatio: 2), envs: BaselineEnv.themes),
    BaselineCase('FrostMediaFrame/image=failing+errorBuilder', (_) => const FrostMediaFrame(image: _Failing(), aspectRatio: 2, errorBuilder: _error)),

    // FrostMediaFrame.skeleton
    BaselineCase('FrostMediaFrame.skeleton/required', (_) => FrostMediaFrame.skeleton(aspectRatio: 16 / 9), envs: [..._wide, BaselineEnv.light]),
    BaselineCase('FrostMediaFrame.skeleton/radius', (_) => FrostMediaFrame.skeleton(aspectRatio: 2, radius: 24)),
    BaselineCase('FrostMediaFrame.skeleton/aspectRatio=null', (_) => FrostMediaFrame.skeleton(aspectRatio: null), height: _height),
  ]);
}
