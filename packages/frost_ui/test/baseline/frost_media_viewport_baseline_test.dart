import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/media.dart';

import 'baseline.dart';

void _zoomed(bool zoomed) {}
void _scaled(double scale) {}
void _noop() {}

const _image = ColoredBox(
  color: Color(0xFF5577AA),
  child: Center(child: FrostText('Image', tone: FrostTextTone.primary)),
);
const _background = ColoredBox(color: Color(0xFF111111));
const _overlay = Align(
  alignment: Alignment.topLeft,
  child: FrostText('Viewer controls', tone: FrostTextTone.primary),
);

Widget _viewport({
  ValueChanged<bool>? onZoomChanged,
  ValueChanged<double>? onScaleChanged,
  VoidCallback? onDismiss,
  FrostMediaViewportController? controller,
  Widget? background,
  Widget? overlay,
  double? maxScale,
  double? doubleTapScale,
}) => SizedBox(
  width: 400,
  height: 300,
  child: FrostMediaViewport(
    onZoomChanged: onZoomChanged,
    onScaleChanged: onScaleChanged,
    onDismiss: onDismiss,
    controller: controller,
    background: background,
    overlay: overlay,
    maxScale: maxScale ?? 5,
    doubleTapScale: doubleTapScale ?? 2.5,
    child: _image,
  ),
);

Future<void> _doubleTap(WidgetTester tester, Finder subject) async {
  final center = tester.getCenter(subject);
  await tester.tapAt(center);
  await tester.pump(const Duration(milliseconds: 50));
  await tester.tapAt(center);
}

void main() {
  final zoomController = FrostMediaViewportController();
  baselineGroup('FrostMediaViewport', [
    BaselineCase('FrostMediaViewport/required', (_) => _viewport(), envs: [...BaselineEnv.themes, BaselineEnv.narrow]),
    BaselineCase('FrostMediaViewport/required#doubleTap', (_) => _viewport(), act: _doubleTap),
    BaselineCase('FrostMediaViewport/onZoomChanged', (_) => _viewport(onZoomChanged: _zoomed)),
    BaselineCase('FrostMediaViewport/onScaleChanged', (_) => _viewport(onScaleChanged: _scaled)),
    BaselineCase('FrostMediaViewport/onDismiss', (_) => _viewport(onDismiss: _noop)),
    BaselineCase('FrostMediaViewport/controller', (_) => _viewport(controller: FrostMediaViewportController())),
    BaselineCase(
      'FrostMediaViewport/controller#zoomed',
      (_) => _viewport(controller: zoomController),
      act: (tester, subject) async => zoomController.zoomTo(2),
    ),
    BaselineCase('FrostMediaViewport/background', (_) => _viewport(background: _background)),
    BaselineCase('FrostMediaViewport/overlay', (_) => _viewport(overlay: _overlay), envs: BaselineEnv.themes),
    BaselineCase('FrostMediaViewport/maxScale=2#doubleTap', (_) => _viewport(maxScale: 2), act: _doubleTap),
    BaselineCase('FrostMediaViewport/doubleTapScale=4#doubleTap', (_) => _viewport(doubleTapScale: 4), act: _doubleTap),
  ]);
}
