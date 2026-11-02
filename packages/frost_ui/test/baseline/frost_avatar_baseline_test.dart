import 'dart:async';

import 'package:flutter/foundation.dart' show SynchronousFuture;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import '../media_test_image.dart';
import 'baseline.dart';

/// Decodes [mediaTestImage] outside the test's fake clock, so the case records
/// the loaded picture instead of its placeholder.
Future<void> _loadImage(WidgetTester tester, Finder subject) async {
  await tester.runAsync(() => precacheImage(mediaTestImage, tester.element(subject)));
}

/// An image that never finishes loading: the avatar keeps its placeholder.
class _PendingImage extends ImageProvider<_PendingImage> {
  const _PendingImage();
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) => SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(_PendingImage key, ImageDecoderCallback decode) => OneFrameImageStreamCompleter(Completer<ImageInfo>().future);
}

const _sizeEnvs = [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.largeText];

void main() {
  baselineGroup('FrostAvatar', [
    const BaselineCase('FrostAvatar/required', _required, envs: BaselineEnv.all),
    const BaselineCase('FrostAvatar/initials', _initials, envs: BaselineEnv.all),
    const BaselineCase('FrostAvatar/initials=three letters', _threeLetters),
    const BaselineCase('FrostAvatar/initials=empty', _emptyInitials),
    for (final size in FrostAvatarSize.values)
      BaselineCase(
        'FrostAvatar/size=${size.name}',
        (_) => FrostAvatar(initials: 'MK', size: size, semanticLabel: 'Mika'),
        envs: _sizeEnvs,
      ),
    BaselineCase(
      'FrostAvatar/image',
      (_) => FrostAvatar(image: mediaTestImage, semanticLabel: 'Mika'),
      act: (tester, subject) => _loadImage(tester, subject),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostAvatar/image=pending+initials', (_) => const FrostAvatar(image: _PendingImage(), initials: 'MK', semanticLabel: 'Mika')),
    for (final size in FrostAvatarSize.values)
      BaselineCase(
        'FrostAvatar/image+size=${size.name}',
        (_) => FrostAvatar(image: mediaTestImage, size: size, semanticLabel: 'Mika'),
        act: (tester, subject) => _loadImage(tester, subject),
      ),
    const BaselineCase('FrostAvatar/child', _child, envs: BaselineEnv.themes),
    BaselineCase('FrostAvatar.skeleton/required', (_) => FrostAvatar.skeleton(size: FrostAvatarSize.regular), envs: BaselineEnv.all),
    for (final size in FrostAvatarSize.values) BaselineCase('FrostAvatar.skeleton/size=${size.name}', (_) => FrostAvatar.skeleton(size: size)),
    // New API: a person's avatar takes its initial and color from the name.
    const BaselineCase('FrostAvatar.person/required', _person, envs: BaselineEnv.all),
    const BaselineCase('FrostAvatar.person/colorKey', _personColorKey, envs: BaselineEnv.themes),
    const BaselineCase('FrostAvatar.person/name=cjk', _personCjk, envs: BaselineEnv.themes),
    const BaselineCase('FrostAvatar.person/name=no-letter', _personNoLetter, envs: BaselineEnv.themes),
    for (final size in FrostAvatarSize.values)
      BaselineCase(
        'FrostAvatar.person/size=${size.name}',
        (_) => FrostAvatar.person(name: 'zhang', size: size),
        envs: _sizeEnvs,
      ),
  ]);
}

Widget _required(BuildContext _) => const FrostAvatar(semanticLabel: 'Mika');
Widget _initials(BuildContext _) => const FrostAvatar(initials: 'MK', semanticLabel: 'Mika');
Widget _threeLetters(BuildContext _) => const FrostAvatar(initials: 'ABC', semanticLabel: 'Abc');
Widget _emptyInitials(BuildContext _) => const FrostAvatar(initials: '', semanticLabel: 'Empty');
Widget _child(BuildContext _) => const FrostAvatar(
  semanticLabel: 'Mika',
  child: ColoredBox(color: Color(0xFF3366CC), child: SizedBox.expand()),
);
Widget _person(BuildContext _) => const FrostAvatar.person(name: 'zhang');
Widget _personColorKey(BuildContext _) => const FrostAvatar.person(name: 'zhang', colorKey: 'account-7');
Widget _personCjk(BuildContext _) => const FrostAvatar.person(name: '张三');
Widget _personNoLetter(BuildContext _) => const FrostAvatar.person(name: '---');
