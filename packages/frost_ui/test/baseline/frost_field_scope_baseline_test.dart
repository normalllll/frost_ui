import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

// A field and a search entry: the two kinds of chrome the scope restyles.
const _fields = Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    FrostTextField(label: 'Name', placeholder: 'Type a name'),
    SizedBox(height: 8),
    FrostSearchEntry(placeholder: 'Search', onPressed: _noop),
  ],
);

void main() {
  baselineGroup('FrostFieldScope', [
    BaselineCase(
      'FrostFieldScope/required',
      (_) => const FrostFieldScope(appearance: FrostFieldAppearance.standard, child: _fields),
      envs: BaselineEnv.all,
    ),
    for (final appearance in FrostFieldAppearance.values.where((a) => a != FrostFieldAppearance.standard))
      BaselineCase(
        'FrostFieldScope/appearance=${appearance.name}',
        (_) => FrostFieldScope(appearance: appearance, child: _fields),
        envs: BaselineEnv.themes,
      ),
    BaselineCase(
      'FrostFieldScope/appearance=subtle#focus',
      (_) => const FrostFieldScope(appearance: FrostFieldAppearance.subtle, child: _fields),
      act: baselineFocus,
    ),
  ]);
}
