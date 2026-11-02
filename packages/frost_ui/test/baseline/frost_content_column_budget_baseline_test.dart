import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/layout/content_viewport.dart' show FrostContentColumnBudget;

import 'baseline.dart';

Widget _probe(BuildContext context) =>
    FrostText('reserved=${FrostContentColumnBudget.of(context)} column=${FrostContentColumnBudget.columnWidth(context, 1000)}', tone: FrostTextTone.primary);

Widget _required(BuildContext context) => const FrostContentColumnBudget(reservedWidth: 0, child: Builder(builder: _probe));
Widget _reserved(BuildContext context) => const FrostContentColumnBudget(reservedWidth: 236, child: Builder(builder: _probe));

void main() {
  baselineGroup('FrostContentColumnBudget', [
    const BaselineCase('FrostContentColumnBudget/required', _required),
    const BaselineCase('FrostContentColumnBudget/reservedWidth=236', _reserved),
  ]);
}
