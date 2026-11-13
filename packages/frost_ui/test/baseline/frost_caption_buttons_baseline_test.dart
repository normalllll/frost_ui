import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart' show FrostCaptionSide;
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionButtons;
import 'package:frost_ui/src/primitives/_state_button.dart' show FrostStateButton;
import 'package:material_ui/material_ui.dart';

import '../window_caption_test.dart' show FakeWindow;
import 'baseline.dart';

const _all = [FrostCaptionAction.minimize, FrostCaptionAction.maximize, FrostCaptionAction.close];

// The buttons stretch to their title row, so every case gives them one.
Widget _buttons({
  FrostCaptionSide? side,
  bool maximized = false,
  bool fullscreen = false,
  bool active = true,
  bool maximizeHovered = false,
  bool maximizePressed = false,
  bool failed = false,
  FrostCaptionMode mode = FrostCaptionMode.client,
  FrostCaptionStyle style = FrostCaptionStyle.windows,
  List<FrostCaptionAction> left = const [],
  List<FrostCaptionAction> right = _all,
  bool window = true,
}) {
  final fake = FakeWindow()
    ..current = FrostCaptionState(
      maximized: maximized,
      fullscreen: fullscreen,
      active: active,
      maximizeHovered: maximizeHovered,
      maximizePressed: maximizePressed,
      failed: failed,
      mode: mode,
      style: style,
      leftButtons: left,
      rightButtons: right,
    );
  final child = Align(
    alignment: Alignment.topLeft,
    child: SizedBox(height: 40, child: side == null ? const FrostCaptionButtons() : FrostCaptionButtons(side: side)),
  );
  return FrostWindowCaptionScope(window: window ? fake : null, child: child);
}

Finder _glyph(int index) => find.byType(FrostStateButton).at(index);

void main() {
  baselineGroup('FrostCaptionButtons', [
    BaselineCase('FrostCaptionButtons/required', (_) => _buttons(), envs: BaselineEnv.all),
    BaselineCase('FrostCaptionButtons/required#noWindow', (_) => _buttons(window: false)),
    BaselineCase('FrostCaptionButtons/required#hover', (_) => _buttons(), act: (tester, subject) => baselineHover(tester, _glyph(0))),
    BaselineCase('FrostCaptionButtons/required#hover-close', (_) => _buttons(), act: (tester, subject) => baselineHover(tester, _glyph(2))),
    BaselineCase('FrostCaptionButtons/required#press', (_) => _buttons(), act: (tester, subject) => baselinePress(tester, _glyph(2))),
    BaselineCase('FrostCaptionButtons/required#focus', (_) => _buttons(), act: baselineFocus),
    BaselineCase('FrostCaptionButtons/side=left', (_) => _buttons(side: FrostCaptionSide.left, left: _all, right: const [])),
    BaselineCase('FrostCaptionButtons/side=right', (_) => _buttons(side: FrostCaptionSide.right)),
    BaselineCase('FrostCaptionButtons/side=left+rightButtons', (_) => _buttons(side: FrostCaptionSide.left)),
    BaselineCase('FrostCaptionButtons/maximized', (_) => _buttons(maximized: true), envs: BaselineEnv.themes),
    BaselineCase('FrostCaptionButtons/active=false', (_) => _buttons(active: false), envs: BaselineEnv.themes),
    BaselineCase('FrostCaptionButtons/maximizeHovered', (_) => _buttons(maximizeHovered: true)),
    BaselineCase('FrostCaptionButtons/maximizePressed', (_) => _buttons(maximizeHovered: true, maximizePressed: true)),
    BaselineCase('FrostCaptionButtons/failed', (_) => _buttons(failed: true)),
    BaselineCase('FrostCaptionButtons/fullscreen', (_) => _buttons(fullscreen: true)),
    BaselineCase('FrostCaptionButtons/mode=system', (_) => _buttons(mode: FrostCaptionMode.system)),
    BaselineCase('FrostCaptionButtons/mode=nativeControls', (_) => _buttons(mode: FrostCaptionMode.nativeControls)),
    BaselineCase('FrostCaptionButtons/mode=nativeControls+failed', (_) => _buttons(mode: FrostCaptionMode.nativeControls, failed: true)),
    BaselineCase(
      'FrostCaptionButtons/style=adwaita',
      (_) => _buttons(style: FrostCaptionStyle.adwaita, right: const [FrostCaptionAction.close]),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostCaptionButtons/style=adwaita#hover',
      (_) => _buttons(style: FrostCaptionStyle.adwaita),
      act: (tester, subject) => baselineHover(tester, _glyph(2)),
    ),
    BaselineCase(
      'FrostCaptionButtons/style=breeze',
      (_) => _buttons(
        style: FrostCaptionStyle.breeze,
        left: const [FrostCaptionAction.close],
        right: const [FrostCaptionAction.minimize, FrostCaptionAction.maximize],
      ),
    ),
    BaselineCase(
      'FrostCaptionButtons/style=breeze#hover',
      (_) => _buttons(style: FrostCaptionStyle.breeze),
      act: (tester, subject) => baselineHover(tester, _glyph(2)),
    ),
    BaselineCase('FrostCaptionButtons/rightButtons=close', (_) => _buttons(right: const [FrostCaptionAction.close])),
    BaselineCase('FrostCaptionButtons/rightButtons=empty', (_) => _buttons(right: const [])),
  ]);
}
