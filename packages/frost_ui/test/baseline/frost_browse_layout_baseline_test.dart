import 'package:flutter/widgets.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

const _header = SizedBox(height: 52, child: FrostText('Header', tone: FrostTextTone.primary));
const _filterBar = SizedBox(height: 44, child: FrostText('Filters', tone: FrostTextTone.primary));
const _empty = FrostText('Nothing here', tone: FrostTextTone.primary);

Widget _item(BuildContext context, int index) => SizedBox(height: 48, child: FrostText('Item $index', tone: FrostTextTone.primary));

List<Widget> _slivers() => [SliverList.builder(itemCount: 12, itemBuilder: _item)];

// Page-level layouts fill their parent: fixed height, wide and narrow.
final _wide = BaselineEnv.standard.copyWith(width: 1280);
final _wideOrNarrow = [_wide, BaselineEnv.narrow];
// Content column cap is 1080; contentInset follows the page inset at 600.
final _aroundInset = [BaselineEnv.standard.copyWith(width: 599), BaselineEnv.standard.copyWith(width: 600)];

void main() {
  baselineGroup('FrostBrowseLayout', [
    BaselineCase(
      'FrostBrowseLayout/required',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers()),
      height: 800,
      envs: [..._wideOrNarrow, ..._aroundInset],
    ),
    BaselineCase(
      'FrostBrowseLayout/filterBar',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers(), filterBar: _filterBar),
      height: 800,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostBrowseLayout/preloadExtent',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers(), preloadExtent: 0),
      height: 800,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostBrowseLayout/empty+isEmpty',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers(), empty: _empty, isEmpty: true),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostBrowseLayout/isEmpty',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers(), isEmpty: true),
      height: 800,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostBrowseLayout/maxWidth=720',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers(), maxWidth: 720),
      height: 800,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostBrowseLayout/maxWidth=infinity',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers(), maxWidth: double.infinity),
      height: 800,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostBrowseLayout/contentInset=keyline',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers(), filterBar: _filterBar, contentInset: FrostBrowseContentInset.keyline),
      height: 800,
      envs: _wideOrNarrow,
    ),
    BaselineCase(
      'FrostBrowseLayout/contentInset=edge',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers(), filterBar: _filterBar, contentInset: FrostBrowseContentInset.edge),
      height: 800,
      envs: [..._wideOrNarrow, ..._aroundInset],
    ),
    BaselineCase(
      'FrostBrowseLayout/contentInset=edge+maxWidth=infinity',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers(), contentInset: FrostBrowseContentInset.edge, maxWidth: double.infinity),
      height: 800,
      envs: [_wide],
    ),
    BaselineCase(
      'FrostBrowseLayout/contentInset=edge+isEmpty',
      (_) => FrostBrowseLayout(header: _header, slivers: _slivers(), empty: _empty, isEmpty: true, contentInset: FrostBrowseContentInset.edge),
      height: 800,
      envs: [_wide],
    ),
  ]);
}
