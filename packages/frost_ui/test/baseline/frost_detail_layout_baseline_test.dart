import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import '../media_test_image.dart';
import 'baseline.dart';

const _stage = ColoredBox(
  color: Color(0x33888888),
  child: Center(child: FrostText('Stage', tone: FrostTextTone.primary)),
);
const _primary = SizedBox(height: 40, child: FrostText('Primary information', tone: FrostTextTone.primary));
const _actions = SizedBox(height: 40, child: FrostText('Actions', tone: FrostTextTone.primary));
const _technical = SizedBox(height: 40, child: FrostText('Technical details', tone: FrostTextTone.primary));
const _header = SizedBox(height: 52, child: FrostText('Header', tone: FrostTextTone.primary));
const _modules = [
  FrostModuleGridItem(
    child: SizedBox(height: 60, child: FrostText('Module A', tone: FrostTextTone.primary)),
  ),
  FrostModuleGridItem(
    child: SizedBox(height: 60, child: FrostText('Module B', tone: FrostTextTone.primary)),
  ),
  FrostModuleGridItem(
    span: FrostModuleSpan.full,
    child: SizedBox(height: 60, child: FrostText('Module C', tone: FrostTextTone.primary)),
  ),
];
final _sections = [for (var i = 0; i < 4; i++) SizedBox(height: 160, child: FrostText('Section $i', tone: FrostTextTone.primary))];

Widget _mediaHeader(BuildContext context, bool scrolledPastStage) =>
    SizedBox(height: 52, child: FrostText('Media header past=$scrolledPastStage', tone: FrostTextTone.primary));

// Stacks below the medium size class by default: 600 points of local width.
final _wide = BaselineEnv.standard.copyWith(width: 1280);
final _wideOrNarrow = [_wide, BaselineEnv.narrow];
final _stackLimit = [BaselineEnv.standard.copyWith(width: 599), BaselineEnv.standard.copyWith(width: 600)];
// stackBelow: expanded moves the limit to 900.
final _expandedLimit = [BaselineEnv.standard.copyWith(width: 899), BaselineEnv.standard.copyWith(width: 900)];

void main() {
  baselineGroup('FrostDetailLayout', [
    BaselineCase(
      'FrostDetailLayout/required',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary),
      height: 800,
      envs: [..._wideOrNarrow, ..._stackLimit, BaselineEnv.light.copyWith(width: 1280)],
    ),
    BaselineCase(
      'FrostDetailLayout/actions',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary, actions: _actions),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostDetailLayout/modules',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary, modules: _modules),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostDetailLayout/sections',
      (_) => FrostDetailLayout(stage: _stage, primary: _primary, sections: _sections),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostDetailLayout/technical',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary, technical: _technical),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostDetailLayout/backdrop',
      (_) => FrostDetailLayout(stage: _stage, primary: _primary, backdrop: mediaTestImage),
      height: 800,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostDetailLayout/header',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary, header: _header),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostDetailLayout/mediaHeader',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary, mediaHeader: _mediaHeader),
      height: 800,
      envs: [..._wideOrNarrow, ..._stackLimit],
    ),
    BaselineCase(
      'FrostDetailLayout/header+mediaHeader',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary, header: _header, mediaHeader: _mediaHeader),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostDetailLayout/stackBelow=expanded',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary, header: _header, stackBelow: FrostSizeClass.expanded),
      height: 800,
      envs: _expandedLimit,
    ),
    BaselineCase(
      'FrostDetailLayout/stackBelow=compact',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary, header: _header, stackBelow: FrostSizeClass.compact),
      height: 800,
      envs: [BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostDetailLayout/headerPlacement=information',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary, header: _header, headerPlacement: FrostDetailHeaderPlacement.information),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostDetailLayout/headerPlacement=page',
      (_) => const FrostDetailLayout(stage: _stage, primary: _primary, header: _header, headerPlacement: FrostDetailHeaderPlacement.page),
      height: 800,
      envs: _wideOrNarrow,
    ),
    for (final sizing in FrostDetailStageSizing.values)
      BaselineCase(
        'FrostDetailLayout/compactStageSizing=${sizing.name}',
        (_) => FrostDetailLayout(stage: _stage, primary: _primary, sections: _sections, compactStageSizing: sizing),
        height: 800,
        envs: [BaselineEnv.narrow, BaselineEnv.standard.copyWith(width: 560)],
      ),
    BaselineCase(
      'FrostDetailLayout/actions+modules+sections+technical+header',
      (_) => FrostDetailLayout(
        stage: _stage,
        primary: _primary,
        actions: _actions,
        modules: _modules,
        sections: _sections,
        technical: _technical,
        header: _header,
      ),
      height: 800,
      envs: _wideOrNarrow,
    ),
  ]);
}
