import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionClearance, FrostNativeCaptionPadding;

import '../window_caption_test.dart' show FakeWindow;
import 'baseline.dart';

const _child = SizedBox(width: 100, height: 40, child: Text('Content'));

Widget _padded({bool window = true, bool fullscreen = false, Rect controls = const Rect.fromLTRB(12, 12, 72, 32), bool clearance = false}) {
  final fake = FakeWindow()
    ..current = FrostCaptionState(
      maximized: false,
      fullscreen: fullscreen,
      active: true,
      maximizeHovered: false,
      maximizePressed: false,
      failed: false,
      mode: FrostCaptionMode.nativeControls,
      leftButtons: const [],
      rightButtons: const [],
      nativeControls: controls,
    );
  Widget subject = const Align(
    alignment: Alignment.topLeft,
    child: FrostNativeCaptionPadding(child: _child),
  );
  if (clearance) subject = FrostCaptionClearance(child: subject);
  return FrostWindowCaptionScope(window: window ? fake : null, child: subject);
}

void main() {
  baselineGroup('FrostNativeCaptionPadding', [
    BaselineCase('FrostNativeCaptionPadding/required', (_) => _padded(), envs: BaselineEnv.all),
    BaselineCase('FrostNativeCaptionPadding/required#noWindow', (_) => _padded(window: false)),
    BaselineCase('FrostNativeCaptionPadding/controls=empty', (_) => _padded(controls: Rect.zero)),
    BaselineCase('FrostNativeCaptionPadding/controls=tall', (_) => _padded(controls: const Rect.fromLTRB(20, 20, 100, 60))),
    BaselineCase('FrostNativeCaptionPadding/fullscreen', (_) => _padded(fullscreen: true)),
    BaselineCase('FrostNativeCaptionPadding/clearance', (_) => _padded(clearance: true)),
  ]);
}
