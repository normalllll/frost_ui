import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noopChanged(bool _) {}

const _body = FrostText('Details that appear when the disclosure is open.');

void main() {
  baselineGroup('FrostDisclosure', [
    BaselineCase(
      'FrostDisclosure/required',
      (_) => const FrostDisclosure(title: 'Advanced', child: _body),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostDisclosure/required#hover',
      (_) => const FrostDisclosure(title: 'Advanced', child: _body),
      act: baselineHover,
    ),
    BaselineCase(
      'FrostDisclosure/required#press',
      (_) => const FrostDisclosure(title: 'Advanced', child: _body),
      act: baselinePress,
    ),
    BaselineCase(
      'FrostDisclosure/required#focus',
      (_) => const FrostDisclosure(title: 'Advanced', child: _body),
      act: baselineFocus,
    ),
    BaselineCase(
      'FrostDisclosure/required#open',
      (_) => const FrostDisclosure(title: 'Advanced', child: _body),
      act: baselineTap,
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostDisclosure/initiallyExpanded',
      (_) => const FrostDisclosure(title: 'Advanced', initiallyExpanded: true, child: _body),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostDisclosure/initiallyExpanded#open',
      (_) => const FrostDisclosure(title: 'Advanced', initiallyExpanded: true, child: _body),
      act: baselineTap,
    ),
    BaselineCase('FrostDisclosure/onExpansionChanged', (_) => const FrostDisclosure(title: 'Advanced', onExpansionChanged: _noopChanged, child: _body)),
    BaselineCase(
      'FrostDisclosure/expanded=true+onExpansionChanged',
      (_) => const FrostDisclosure(title: 'Advanced', expanded: true, onExpansionChanged: _noopChanged, child: _body),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostDisclosure/expanded=false+onExpansionChanged',
      (_) => const FrostDisclosure(title: 'Advanced', expanded: false, onExpansionChanged: _noopChanged, child: _body),
    ),
    BaselineCase('FrostDisclosure/expanded=true', (_) => const FrostDisclosure(title: 'Advanced', expanded: true, child: _body)),
    BaselineCase('FrostDisclosure/expanded=false', (_) => const FrostDisclosure(title: 'Advanced', expanded: false, child: _body)),
  ]);
}
