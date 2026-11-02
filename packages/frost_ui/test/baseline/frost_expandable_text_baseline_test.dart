import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noopChanged(bool _) {}

const _long =
    'The quick brown fox jumps over the lazy dog while the afternoon light slowly fades behind the hills. '
    'Nobody noticed the small details at first, but every sentence added a little more weight to the story, '
    'until the paragraph no longer fit within three lines of body text and needed a way to expand.';
const _short = 'A short sentence that fits.';

Finder _action(Finder subject) => find.descendant(of: subject, matching: find.text('L.expandText'));
Future<void> _tapAction(WidgetTester tester, Finder subject) => tester.tap(_action(subject));
Future<void> _hoverAction(WidgetTester tester, Finder subject) => baselineHover(tester, _action(subject));

void main() {
  baselineGroup('FrostExpandableText', [
    BaselineCase('FrostExpandableText/required', (_) => const FrostExpandableText(text: _long), envs: BaselineEnv.all),
    BaselineCase('FrostExpandableText/required#open', (_) => const FrostExpandableText(text: _long), act: _tapAction),
    BaselineCase('FrostExpandableText/required#hover', (_) => const FrostExpandableText(text: _long), act: _hoverAction),
    BaselineCase('FrostExpandableText/required#focus', (_) => const FrostExpandableText(text: _long), act: baselineFocus),
    BaselineCase('FrostExpandableText/text=short', (_) => const FrostExpandableText(text: _short)),
    BaselineCase('FrostExpandableText/maxLines=1', (_) => const FrostExpandableText(text: _long, maxLines: 1)),
    BaselineCase('FrostExpandableText/maxLines=5', (_) => const FrostExpandableText(text: _long, maxLines: 5)),
    for (final role in [FrostTextRole.footnote, FrostTextRole.headline])
      BaselineCase('FrostExpandableText/role=${role.name}', (_) => FrostExpandableText(text: _long, role: role)),
    BaselineCase(
      'FrostExpandableText/expanded=true+onExpandedChanged',
      (_) => const FrostExpandableText(text: _long, expanded: true, onExpandedChanged: _noopChanged),
    ),
    BaselineCase(
      'FrostExpandableText/expanded=false+onExpandedChanged',
      (_) => const FrostExpandableText(text: _long, expanded: false, onExpandedChanged: _noopChanged),
    ),
    BaselineCase('FrostExpandableText/expanded=false', (_) => const FrostExpandableText(text: _long, expanded: false)),
  ]);
}
