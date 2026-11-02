import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

void main() {
  // The widget draws only its child; it decides when focus rings show.
  baselineGroup('FrostInputFeedback', [
    BaselineCase(
      'FrostInputFeedback/required',
      (_) => const FrostInputFeedback(
        child: FrostButton(label: 'Save', onPressed: _noop),
      ),
      envs: BaselineEnv.all,
    ),
    // Keyboard focus shows the ring.
    BaselineCase(
      'FrostInputFeedback/required#focus',
      (_) => const FrostInputFeedback(
        child: FrostButton(label: 'Save', onPressed: _noop),
      ),
      act: baselineFocus,
    ),
    // A pointer press switches to touch highlighting, so no ring follows the click.
    BaselineCase(
      'FrostInputFeedback/required#press',
      (_) => const FrostInputFeedback(
        child: FrostButton(label: 'Save', onPressed: _noop),
      ),
      act: baselinePress,
    ),
  ]);
}
