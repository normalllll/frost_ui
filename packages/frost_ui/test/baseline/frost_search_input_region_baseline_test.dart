import 'package:flutter/widgets.dart' show Widget;
import 'package:frost_ui/frost_ui.dart';
import 'package:frost_ui/src/controls/search_input.dart' show FrostSearchInputRegion;

import 'baseline.dart';
import 'controls_support.dart';

void _submitted(String _) {}

Widget _region({String text = ''}) => BaselineField(
  text: text,
  builder: (_, controller, focus) => FrostSearchInputRegion(
    child: FrostSearchInput(controller: controller, focusNode: focus, placeholder: 'Search', onSubmitted: _submitted),
  ),
);

void main() {
  baselineGroup('FrostSearchInputRegion', [
    BaselineCase('FrostSearchInputRegion/required', (_) => _region(), envs: BaselineEnv.all),
    BaselineCase('FrostSearchInputRegion/required+wide', (_) => _region(), envs: [BaselineEnv.standard.copyWith(width: 1280)]),
    BaselineCase('FrostSearchInputRegion/child=text', (_) => _region(text: 'sunset')),
    BaselineCase('FrostSearchInputRegion/required#focus', (_) => _region(), act: baselineFocus),
  ]);
}
