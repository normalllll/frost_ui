import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/navigation/window_caption.dart' show FrostCaptionClearance, FrostNativeCaptionPadding;

import '../window_caption_test.dart' show FakeWindow;
import 'baseline.dart';

// Clearance has no layout of its own: it tells the native caption padding
// below it that the owner already placed the content under the caption row.
Widget _clearance({bool nativeControls = true}) {
  final fake = FakeWindow()
    ..current = FrostCaptionState(
      maximized: false,
      active: true,
      maximizeHovered: false,
      maximizePressed: false,
      failed: false,
      mode: FrostCaptionMode.nativeControls,
      leftButtons: const [],
      rightButtons: const [],
      nativeControls: nativeControls ? const Rect.fromLTRB(12, 12, 72, 32) : Rect.zero,
    );
  return FrostWindowCaptionScope(
    window: fake,
    child: const Align(
      alignment: Alignment.topLeft,
      child: FrostCaptionClearance(
        child: FrostNativeCaptionPadding(child: SizedBox(width: 100, height: 40, child: Text('Content'))),
      ),
    ),
  );
}

void main() {
  baselineGroup('FrostCaptionClearance', [
    BaselineCase(
      'FrostCaptionClearance/required',
      (_) => const FrostCaptionClearance(child: SizedBox(width: 100, height: 40, child: Text('Content'))),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostCaptionClearance/required+nativeControls', (_) => _clearance()),
    BaselineCase('FrostCaptionClearance/required+nativeControls=empty', (_) => _clearance(nativeControls: false)),
  ]);
}
