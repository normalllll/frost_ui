import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _noop() {}

void _changed(bool? _) {}

// One control per default the scope supplies: size (button), enabled
// (checkbox) and toolbar (text field appearance).
const _controls = Column(
  mainAxisSize: MainAxisSize.min,
  crossAxisAlignment: CrossAxisAlignment.start,
  spacing: 8,
  children: [
    FrostButton(label: 'Save', onPressed: _noop),
    FrostCheckbox(value: true, onChanged: _changed, semanticLabel: 'Agree'),
    SizedBox(width: 240, child: FrostTextField(label: 'Name')),
  ],
);

void main() {
  baselineGroup('FrostControlScope', [
    BaselineCase('FrostControlScope/required', (_) => const FrostControlScope(child: _controls), envs: BaselineEnv.all),
    for (final size in FrostControlSize.values) BaselineCase('FrostControlScope/size=${size.name}', (_) => FrostControlScope(size: size, child: _controls)),
    BaselineCase('FrostControlScope/enabled=false', (_) => const FrostControlScope(enabled: false, child: _controls), envs: BaselineEnv.themes),
    BaselineCase('FrostControlScope/enabled=true', (_) => const FrostControlScope(enabled: true, child: _controls)),
    BaselineCase('FrostControlScope/toolbar=true', (_) => const FrostControlScope(toolbar: true, child: _controls), envs: BaselineEnv.themes),
    BaselineCase('FrostControlScope/toolbar=false', (_) => const FrostControlScope(toolbar: false, child: _controls)),
    BaselineCase(
      'FrostControlScope/size+enabled+toolbar',
      (_) => const FrostControlScope(size: FrostControlSize.compact, enabled: false, toolbar: true, child: _controls),
      envs: BaselineEnv.themes,
    ),
    // Nullable fields inherit independently from the nearest scope that sets them.
    BaselineCase(
      'FrostControlScope/nested',
      (_) => const FrostControlScope(
        size: FrostControlSize.large,
        enabled: false,
        child: FrostControlScope(size: FrostControlSize.compact, child: _controls),
      ),
    ),
  ]);
}
