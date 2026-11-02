import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart' show FrostCaptionRegion, FrostHitKind;

import 'baseline.dart';

class _FakeWindow extends ChangeNotifier implements FrostWindowActions {
  @override
  FrostCaptionState get captionState => const FrostCaptionState(maximized: false, active: true, maximizeHovered: false, maximizePressed: false, failed: false);
  @override
  void updateHitRegions(List<FrostHitRegion> regions) {}
  @override
  Future<void> minimize() async {}
  @override
  Future<void> toggleMaximized() async {}
  @override
  Future<void> close() async {}
  @override
  Future<void> retry() async {}
}

const _content = SizedBox(width: 200, height: 40, child: FrostText('Region content', tone: FrostTextTone.primary));

void main() {
  baselineGroup('FrostCaptionRegion', [
    // Without a window scope the region returns its child unchanged.
    for (final kind in FrostHitKind.values)
      BaselineCase(
        kind == FrostHitKind.caption ? 'FrostCaptionRegion/required' : 'FrostCaptionRegion/kind=${kind.name}',
        (_) => FrostCaptionRegion(kind: kind, child: _content),
      ),
    for (final kind in FrostHitKind.values)
      BaselineCase(
        'FrostCaptionRegion/${kind == FrostHitKind.caption ? 'required' : 'kind=${kind.name}'}+inWindowScope',
        (_) => FrostWindowCaptionScope(
          window: _FakeWindow(),
          child: FrostCaptionRegion(kind: kind, child: _content),
        ),
      ),
  ]);
}
