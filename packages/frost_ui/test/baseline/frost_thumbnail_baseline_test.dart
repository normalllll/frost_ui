import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _image = ColoredBox(color: Color(0xFF5577AA));

Widget _required(BuildContext context) => const FrostThumbnail(image: _image, semanticLabel: 'Cover');
Widget _onPressed(BuildContext context) => const FrostThumbnail(image: _image, semanticLabel: 'Cover', onPressed: _noop);

void main() {
  baselineGroup('FrostThumbnail', [
    const BaselineCase('FrostThumbnail/required', _required, envs: BaselineEnv.all),
    for (final size in FrostThumbnailSize.values)
      BaselineCase(
        'FrostThumbnail/size=${size.name}',
        (_) => FrostThumbnail(image: _image, semanticLabel: 'Cover', size: size),
        envs: BaselineEnv.themes,
      ),
    BaselineCase(
      'FrostThumbnail/selected',
      (_) => const FrostThumbnail(image: _image, semanticLabel: 'Cover', selected: true),
      envs: BaselineEnv.themes,
    ),
    for (final size in FrostThumbnailSize.values)
      BaselineCase('FrostThumbnail/size=${size.name}+selected', (_) => FrostThumbnail(image: _image, semanticLabel: 'Cover', size: size, selected: true)),
    const BaselineCase('FrostThumbnail/onPressed', _onPressed, envs: BaselineEnv.all),
    const BaselineCase('FrostThumbnail/onPressed#hover', _onPressed, act: baselineHover),
    const BaselineCase('FrostThumbnail/onPressed#press', _onPressed, act: baselinePress),
    const BaselineCase('FrostThumbnail/onPressed#focus', _onPressed, act: baselineFocus),
    BaselineCase('FrostThumbnail/selected+onPressed', (_) => const FrostThumbnail(image: _image, semanticLabel: 'Cover', selected: true, onPressed: _noop)),
  ]);
}
