import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _a = FrostModule(title: 'Storage', value: '1,234', note: 'Used');
const _b = FrostModule(title: 'Files', value: '56', note: 'Total files in the library with a longer note');
const _c = FrostModule(title: 'Activity', content: FrostText('A full width module with free-form content.'));

void main() {
  baselineGroup('FrostModuleGrid', [
    BaselineCase(
      'FrostModuleGrid/required',
      (_) => const FrostModuleGrid(
        items: [
          FrostModuleGridItem(child: _a),
          FrostModuleGridItem(child: _b),
        ],
      ),
      envs: BaselineEnv.all,
    ),
    BaselineCase('FrostModuleGrid/items=single-half', (_) => const FrostModuleGrid(items: [FrostModuleGridItem(child: _a)])),
    BaselineCase(
      'FrostModuleGrid/span=full',
      (_) => const FrostModuleGrid(
        items: [FrostModuleGridItem(child: _c, span: FrostModuleSpan.full)],
      ),
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostModuleGrid/span=mixed',
      (_) => const FrostModuleGrid(
        items: [
          FrostModuleGridItem(child: _a),
          FrostModuleGridItem(child: _b),
          FrostModuleGridItem(child: _c, span: FrostModuleSpan.full),
          FrostModuleGridItem(child: _a),
        ],
      ),
      envs: [BaselineEnv.standard, BaselineEnv.light, BaselineEnv.largeText, BaselineEnv.narrow],
    ),
    BaselineCase('FrostModuleGrid/items=empty', (_) => const FrostModuleGrid(items: [])),
  ]);
}
