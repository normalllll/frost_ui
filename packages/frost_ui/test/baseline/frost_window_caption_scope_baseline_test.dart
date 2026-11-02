import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

/// A window with no native side: it only reports a caption state.
class _FakeWindow extends ChangeNotifier implements FrostWindowActions {
  _FakeWindow({this.maximized = false});
  final bool maximized;
  @override
  FrostCaptionState get captionState => FrostCaptionState(maximized: maximized, active: true, maximizeHovered: false, maximizePressed: false, failed: false);
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

Widget _probe(BuildContext context) => FrostText(
  'window=${FrostWindowCaptionScope.windowOf(context) != null} '
  'maximized=${FrostWindowCaptionScope.stateOf(context)?.maximized} '
  'backdropActive=${FrostWindowCaptionScope.systemBackdropActiveOf(context)} '
  'backdropAvailable=${FrostWindowCaptionScope.systemBackdropAvailableOf(context)}',
  tone: FrostTextTone.primary,
);

Widget _required(BuildContext context) => const FrostWindowCaptionScope(child: Builder(builder: _probe));
Widget _active(BuildContext context) => const FrostWindowCaptionScope(systemBackdropActive: true, child: Builder(builder: _probe));
Widget _available(BuildContext context) => const FrostWindowCaptionScope(systemBackdropAvailable: true, child: Builder(builder: _probe));

void main() {
  baselineGroup('FrostWindowCaptionScope', [
    const BaselineCase('FrostWindowCaptionScope/required', _required, envs: [BaselineEnv.standard, BaselineEnv.narrow]),
    BaselineCase(
      'FrostWindowCaptionScope/window',
      (_) => FrostWindowCaptionScope(
        window: _FakeWindow(),
        child: const Builder(builder: _probe),
      ),
    ),
    BaselineCase(
      'FrostWindowCaptionScope/window+maximized',
      (_) => FrostWindowCaptionScope(
        window: _FakeWindow(maximized: true),
        child: const Builder(builder: _probe),
      ),
    ),
    const BaselineCase('FrostWindowCaptionScope/systemBackdropActive', _active),
    const BaselineCase('FrostWindowCaptionScope/systemBackdropAvailable', _available),
  ]);
}
