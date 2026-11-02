import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _graphic = FrostMeter(value: .6, semanticLabel: 'Usage');
const _content = FrostText('Some free-form content inside the module.');
const _pointerAndTouch = [BaselineEnv.standard, BaselineEnv.touch];

void main() {
  baselineGroup('FrostModule', [
    BaselineCase('FrostModule/required', (_) => const FrostModule(title: 'Storage'), envs: BaselineEnv.all),
    BaselineCase(
      'FrostModule/icon',
      (_) => const FrostModule(title: 'Storage', icon: baselineIcon),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostModule/value',
      (_) => const FrostModule(title: 'Storage', value: '1,234'),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostModule/value=long',
      (_) => const FrostModule(title: 'Storage', value: '123,456,789,012,345'),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase('FrostModule/graphic', (_) => const FrostModule(title: 'Storage', graphic: _graphic)),
    BaselineCase('FrostModule/content', (_) => const FrostModule(title: 'Storage', content: _content)),
    BaselineCase('FrostModule/note', (_) => const FrostModule(title: 'Storage', note: 'Updated just now')),
    BaselineCase(
      'FrostModule/icon+value+graphic+content+note',
      (_) => const FrostModule(title: 'Storage', icon: baselineIcon, value: '1,234', graphic: _graphic, content: _content, note: 'Updated just now'),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.largeText, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostModule/onPressed',
      (_) => const FrostModule(title: 'Storage', value: '1,234', onPressed: _noop),
      envs: _pointerAndTouch,
    ),
    BaselineCase(
      'FrostModule/onPressed#hover',
      (_) => const FrostModule(title: 'Storage', value: '1,234', onPressed: _noop),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostModule/onPressed#press',
      (_) => const FrostModule(title: 'Storage', value: '1,234', onPressed: _noop),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostModule/onPressed#focus',
      (_) => const FrostModule(title: 'Storage', value: '1,234', onPressed: _noop),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostModule/onPressed+icon+note',
      (_) => const FrostModule(title: 'Storage', icon: baselineIcon, value: '1,234', note: 'Updated just now', onPressed: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostModule.skeleton/required',
      (_) => FrostModule.skeleton(title: 'Storage', icon: true, value: '1,234', note: 'Updated just now'),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostModule.skeleton/icon=false', (_) => FrostModule.skeleton(title: 'Storage', icon: false, value: null, note: null)),
  ]);
}
