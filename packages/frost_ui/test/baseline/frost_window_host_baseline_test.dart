import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _content = SizedBox(width: 300, height: 60, child: FrostText('Window content', tone: FrostTextTone.primary));

// The host only talks to the native side on desktop platforms with a custom
// title bar; in the test environment the controller stays idle.
Widget _host({double? resizeBorderWidth, FrostWindowBackdrop? backdrop}) => FrostWindowHost(
  controller: FrostWindowController(minimumSize: const Size(480, 360)),
  title: 'Baseline window',
  resizeBorderWidth: resizeBorderWidth ?? 4.0,
  backdrop: backdrop ?? FrostWindowBackdrop.none,
  child: _content,
);

void main() {
  baselineGroup('FrostWindowHost', [
    BaselineCase('FrostWindowHost/required', (_) => _host(), envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.narrow]),
    BaselineCase('FrostWindowHost/resizeBorderWidth=8', (_) => _host(resizeBorderWidth: 8)),
    BaselineCase('FrostWindowHost/backdrop=mica', (_) => _host(backdrop: FrostWindowBackdrop.mica), envs: BaselineEnv.themes),
    BaselineCase('FrostWindowHost/backdrop=micaAlt', (_) => _host(backdrop: FrostWindowBackdrop.micaAlt)),
  ]);
}
