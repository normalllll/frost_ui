import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _header = SizedBox(height: 52, child: FrostText('Header', tone: FrostTextTone.primary));
const _toolbar = SizedBox(height: 44, child: FrostText('Toolbar', tone: FrostTextTone.primary));
const _stats = [FrostStat(value: '128', caption: 'Items'), FrostStat(value: '4.2', unit: 'GB', caption: 'Size')];

Widget _item(BuildContext context, int index) => SizedBox(height: 48, child: FrostText('Item $index', tone: FrostTextTone.primary));

List<Widget> _slivers() => [SliverList.builder(itemCount: 12, itemBuilder: _item)];

final _wide = BaselineEnv.standard.copyWith(width: 1280);
final _wideOrNarrow = [_wide, BaselineEnv.narrow];

void main() {
  baselineGroup('FrostCollectionLayout', [
    BaselineCase(
      'FrostCollectionLayout/required',
      (_) => FrostCollectionLayout(header: _header, slivers: _slivers()),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostCollectionLayout/toolbar',
      (_) => FrostCollectionLayout(header: _header, slivers: _slivers(), toolbar: _toolbar),
      height: 800,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostCollectionLayout/stats',
      (_) => FrostCollectionLayout(header: _header, slivers: _slivers(), stats: _stats),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostCollectionLayout/toolbar+stats',
      (_) => FrostCollectionLayout(header: _header, slivers: _slivers(), toolbar: _toolbar, stats: _stats),
      height: 800,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostCollectionLayout/stats+noSlivers',
      (_) => const FrostCollectionLayout(header: _header, slivers: [], stats: _stats),
      height: 800,
      envs: [_wide],
    ),
  ]);
}
