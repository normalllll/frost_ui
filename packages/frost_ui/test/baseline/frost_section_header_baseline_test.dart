import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}
void _toggle(bool _) {}

const _trailing = [FrostButton.icon(icon: baselineIcon, label: 'Add', onPressed: _noop)];

Finder _button(Finder subject) => find.descendant(of: subject, matching: find.byType(FrostButton)).first;
Future<void> _hoverButton(WidgetTester tester, Finder subject) => baselineHover(tester, _button(subject));
Future<void> _pressButton(WidgetTester tester, Finder subject) => baselinePress(tester, _button(subject));

void main() {
  baselineGroup('FrostSectionHeader', [
    BaselineCase('FrostSectionHeader/required', (_) => const FrostSectionHeader(title: 'Recent'), envs: BaselineEnv.all),
    BaselineCase(
      'FrostSectionHeader/onAction',
      (_) => const FrostSectionHeader(title: 'Recent', onAction: _noop),
      envs: BaselineEnv.all,
    ),
    BaselineCase(
      'FrostSectionHeader/onAction#hover',
      (_) => const FrostSectionHeader(title: 'Recent', onAction: _noop),
      act: _hoverButton,
    ),
    BaselineCase(
      'FrostSectionHeader/onAction#press',
      (_) => const FrostSectionHeader(title: 'Recent', onAction: _noop),
      act: _pressButton,
    ),
    BaselineCase(
      'FrostSectionHeader/onAction#focus',
      (_) => const FrostSectionHeader(title: 'Recent', onAction: _noop),
      act: baselineFocus,
    ),
    BaselineCase('FrostSectionHeader/actionLabel', (_) => const FrostSectionHeader(title: 'Recent', actionLabel: 'See more')),
    BaselineCase(
      'FrostSectionHeader/actionLabel+onAction',
      (_) => const FrostSectionHeader(title: 'Recent', actionLabel: 'See more', onAction: _noop),
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostSectionHeader/trailing',
      (_) => const FrostSectionHeader(title: 'Recent', trailing: _trailing),
      envs: [BaselineEnv.standard, BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostSectionHeader/onAction+trailing',
      (_) => const FrostSectionHeader(title: 'Recent', onAction: _noop, trailing: _trailing),
      envs: [BaselineEnv.standard, BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostSectionHeader/title=long+onAction',
      (_) => const FrostSectionHeader(title: 'A section title that is much too long to share a row with its action', onAction: _noop),
      envs: [BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostSectionHeader.collapsible/expanded',
      (_) => const FrostSectionHeader.collapsible(title: 'Recent', expanded: true, onExpansionChanged: _toggle, trailing: _trailing, child: SizedBox(height: 40)),
      envs: [BaselineEnv.standard, BaselineEnv.touch],
    ),
    BaselineCase(
      'FrostSectionHeader.collapsible/collapsed',
      (_) => const FrostSectionHeader.collapsible(title: 'Recent', expanded: false, onExpansionChanged: _toggle, child: SizedBox(height: 40)),
    ),
    BaselineCase(
      'FrostSectionHeader/pathTitle=long',
      (_) => const FrostSectionHeader(title: r'D:\work\clients\organisation\repositories\gitbound', pathTitle: true, trailing: _trailing),
      envs: [BaselineEnv.narrow],
    ),
  ]);
}
