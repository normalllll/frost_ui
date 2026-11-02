import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

const _row = FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), onPressed: _noop);

/// A bleed extends its child into the room the nearest keyline offers.
Widget _bleed({double amount = 8, double room = 16, double edge = 16, bool insideContainer = false}) => FrostKeyline(
  leadingRoom: room,
  trailingRoom: room,
  edgeDistanceStart: edge,
  edgeDistanceEnd: edge,
  insideContainer: insideContainer,
  contentStart: 0,
  child: Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: FrostBleed(amount: amount, child: _row),
  ),
);

Widget _nested(BuildContext context) => const FrostKeyline(
  leadingRoom: 16,
  trailingRoom: 16,
  edgeDistanceStart: 16,
  edgeDistanceEnd: 16,
  insideContainer: false,
  contentStart: 0,
  child: Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: FrostBleed(amount: 8, child: FrostBleed(amount: 8, child: _row)),
  ),
);

void main() {
  baselineGroup('FrostBleed', [
    BaselineCase('FrostBleed/required', (_) => _bleed(), envs: BaselineEnv.all),
    BaselineCase('FrostBleed/required+noKeyline', (_) => const FrostBleed(amount: 8, child: _row)),
    BaselineCase('FrostBleed/amount=0', (_) => _bleed(amount: 0)),
    BaselineCase('FrostBleed/amount=16', (_) => _bleed(amount: 16), envs: BaselineEnv.themes),
    BaselineCase('FrostBleed/amount=32+room=16', (_) => _bleed(amount: 32)),
    BaselineCase('FrostBleed/required+room=0', (_) => _bleed(room: 0)),
    BaselineCase('FrostBleed/required+insideContainer', (_) => _bleed(insideContainer: true)),
    BaselineCase('FrostBleed/amount=16+edgeSnap', (_) => _bleed(amount: 16, edge: 18)),
    BaselineCase('FrostBleed/required#hover', (_) => _bleed(), act: baselineHover),
    const BaselineCase('FrostBleed/nested', _nested),
  ]);
}
