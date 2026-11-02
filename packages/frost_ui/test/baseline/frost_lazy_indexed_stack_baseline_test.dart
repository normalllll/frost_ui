import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

List<Widget> _children() => const [
  SizedBox(
    width: 200,
    height: 80,
    child: ColoredBox(
      color: Color(0x33888888),
      child: FrostText('First', tone: FrostTextTone.primary),
    ),
  ),
  SizedBox(
    width: 300,
    height: 120,
    child: ColoredBox(
      color: Color(0x33AA8888),
      child: FrostText('Second', tone: FrostTextTone.primary),
    ),
  ),
  SizedBox(
    width: 100,
    height: 40,
    child: ColoredBox(
      color: Color(0x3388AA88),
      child: FrostText('Third', tone: FrostTextTone.primary),
    ),
  ),
];

// A stack bounded by a frame, so alignment and sizing show.
Widget _framed(Widget stack) => SizedBox(
  width: 400,
  height: 200,
  child: DecoratedBox(
    decoration: BoxDecoration(border: Border.all(color: const Color(0xFF888888))),
    child: stack,
  ),
);

void main() {
  baselineGroup('FrostLazyIndexedStack', [
    BaselineCase(
      'FrostLazyIndexedStack/required',
      (_) => FrostLazyIndexedStack(index: 0, children: _children()),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase('FrostLazyIndexedStack/index=1', (_) => FrostLazyIndexedStack(index: 1, children: _children())),
    BaselineCase('FrostLazyIndexedStack/alignment', (_) => _framed(FrostLazyIndexedStack(index: 0, alignment: Alignment.bottomRight, children: _children()))),
    BaselineCase(
      'FrostLazyIndexedStack/textDirection=rtl',
      (_) => _framed(FrostLazyIndexedStack(index: 0, textDirection: TextDirection.rtl, children: _children())),
    ),
    BaselineCase('FrostLazyIndexedStack/sizing=expand', (_) => _framed(FrostLazyIndexedStack(index: 1, sizing: StackFit.expand, children: _children()))),
    BaselineCase('FrostLazyIndexedStack/children=empty', (_) => const FrostLazyIndexedStack(index: 0, children: [])),
  ]);
}
