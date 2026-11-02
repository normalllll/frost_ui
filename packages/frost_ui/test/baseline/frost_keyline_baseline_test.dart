import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

/// A keyline offers its room to a bleeding row and its text start to dividers.
Widget _keyline({
  double leadingRoom = 16,
  double trailingRoom = 16,
  double edgeDistanceStart = 16,
  double edgeDistanceEnd = 16,
  bool insideContainer = false,
  double contentStart = 0,
}) => FrostKeyline(
  leadingRoom: leadingRoom,
  trailingRoom: trailingRoom,
  edgeDistanceStart: edgeDistanceStart,
  edgeDistanceEnd: edgeDistanceEnd,
  insideContainer: insideContainer,
  contentStart: contentStart,
  child: const Padding(
    padding: EdgeInsets.symmetric(horizontal: 16),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FrostListRow(title: 'Title', subtitle: FrostRowSubtitle('Subtitle'), onPressed: _noop),
        FrostDivider(inset: FrostDividerInset.keyline),
        FrostListRow(title: 'Second', onPressed: _noop),
      ],
    ),
  ),
);

void main() {
  baselineGroup('FrostKeyline', [
    BaselineCase('FrostKeyline/required', (_) => _keyline(), envs: BaselineEnv.all),
    BaselineCase('FrostKeyline/leadingRoom=0', (_) => _keyline(leadingRoom: 0)),
    BaselineCase('FrostKeyline/trailingRoom=0', (_) => _keyline(trailingRoom: 0)),
    BaselineCase('FrostKeyline/edgeDistanceStart=0', (_) => _keyline(edgeDistanceStart: 0)),
    BaselineCase('FrostKeyline/edgeDistanceEnd=0', (_) => _keyline(edgeDistanceEnd: 0)),
    BaselineCase('FrostKeyline/insideContainer', (_) => _keyline(insideContainer: true), envs: BaselineEnv.themes),
    BaselineCase('FrostKeyline/contentStart', (_) => _keyline(contentStart: 48), envs: BaselineEnv.themes),
    BaselineCase('FrostKeyline/leadingRoom=0+trailingRoom=0', (_) => _keyline(leadingRoom: 0, trailingRoom: 0)),
  ]);
}
