import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'baseline.dart';

void _noop() {}

// Media ink is white: show it on a media-like backdrop.
Widget _onMedia(Widget button) => ColoredBox(
  color: const Color(0xFF334455),
  child: Padding(padding: const EdgeInsets.all(12), child: button),
);

Widget _required(BuildContext context) => _onMedia(const FrostMediaButton(label: 'Speed', onPressed: _noop));
Widget _iconRequired(BuildContext context) => _onMedia(const FrostMediaButton.icon(icon: baselineIcon, label: 'Play', onPressed: _noop));

void main() {
  baselineGroup('FrostMediaButton', [
    const BaselineCase('FrostMediaButton/required', _required, envs: BaselineEnv.all),
    BaselineCase('FrostMediaButton/onPressed=null', (_) => _onMedia(const FrostMediaButton(label: 'Speed', onPressed: null)), envs: BaselineEnv.themes),
    BaselineCase('FrostMediaButton/icon', (_) => _onMedia(const FrostMediaButton(label: 'Speed', icon: baselineIcon, onPressed: _noop))),
    for (final size in FrostControlSize.values)
      BaselineCase('FrostMediaButton/size=${size.name}', (_) => _onMedia(FrostMediaButton(label: 'Speed', size: size, onPressed: _noop))),
    const BaselineCase('FrostMediaButton/required#hover', _required, act: baselineHover),
    const BaselineCase('FrostMediaButton/required#press', _required, act: baselinePress),
    const BaselineCase('FrostMediaButton/required#focus', _required, act: baselineFocus),
    const BaselineCase('FrostMediaButton.icon/required', _iconRequired, envs: BaselineEnv.all),
    BaselineCase('FrostMediaButton.icon/onPressed=null', (_) => _onMedia(const FrostMediaButton.icon(icon: baselineIcon, label: 'Play', onPressed: null))),
    for (final size in FrostControlSize.values)
      BaselineCase(
        'FrostMediaButton.icon/size=${size.name}',
        (_) => _onMedia(FrostMediaButton.icon(icon: baselineIcon, label: 'Play', size: size, onPressed: _noop)),
      ),
    const BaselineCase('FrostMediaButton.icon/required#hover', _iconRequired, act: baselineHover),
    const BaselineCase('FrostMediaButton.icon/required#press', _iconRequired, act: baselinePress),
  ]);
}
