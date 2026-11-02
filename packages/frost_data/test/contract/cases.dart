// The frost_data components, checked by frost_ui's contract harness. Ids carry
// the frost_data: prefix, as the file field of this package's gate rows does.
import 'package:flutter/material.dart';
import 'package:frost_data/frost_data.dart';

import '../../../frost_ui/test/contract/harness.dart';

const _sliver = {'intrinsic': 'a sliver is placed in a viewport, which has no intrinsic size'};
const _layoutOnly = {'no-theme': 'pure layout or animation: it reads no Frost theme, scope or configuration'};

class _Source extends FrostListSource<int> {
  @override
  Future<List<int>> initList() => Future.value(List.generate(12, (i) => i));
  @override
  Future<List<int>> nextList() => Future.value([]);
}

const _box = SizedBox(width: 120, height: 40, child: ColoredBox(color: Colors.red));

/// A slivers-only component, hosted in a scroll view of bounded height.
Widget _inScroll(Widget sliver) => SizedBox(height: 400, width: 400, child: CustomScrollView(slivers: [sliver]));

Widget _rowItem(BuildContext context, int value, int index) => SizedBox(height: 40, child: Text('Item $value'));
Widget _gridItem(BuildContext context, int value, int index) => SizedBox(child: Text('Item $value'));

final displayCases = <DisplayCase>[
  DisplayCase(
    'frost_data:FrostSliverDataList.new',
    FrostSliverDataList<int>,
    (_) => _inScroll(FrostSliverDataList<int>(source: _Source(), itemBuilder: _rowItem, firstLoadSkeleton: const SizedBox(height: 40))),
    skip: _sliver,
  ),
  DisplayCase(
    'frost_data:FrostSliverDataGrid.new',
    FrostSliverDataGrid<int>,
    (_) => _inScroll(
      FrostSliverDataGrid<int>(
        source: _Source(),
        itemBuilder: _gridItem,
        firstLoadSkeleton: const SizedBox(height: 40),
        minTileWidth: 120,
        tileHeight: (_, _) => 60,
      ),
    ),
    skip: _sliver,
  ),
  DisplayCase(
    'frost_data:FrostSliverDataWaterfallGrid.new',
    FrostSliverDataWaterfallGrid<int>,
    (_) => _inScroll(FrostSliverDataWaterfallGrid<int>(source: _Source(), itemBuilder: _gridItem, firstLoadSkeleton: const SizedBox(height: 40))),
    skip: _sliver,
  ),
  DisplayCase(
    'frost_data:FrostLoadStateSwitcher.new',
    FrostLoadStateSwitcher,
    (_) => const FrostLoadStateSwitcher(phase: FrostLoadPhase.content, child: _box),
    skip: _layoutOnly,
  ),
  DisplayCase('frost_data:FrostLoadingMoreIndicator.new', FrostLoadingMoreIndicator, (_) => FrostLoadingMoreIndicator(source: _Source())),
];

/// Classes with no component case, with the category that says why.
const notApplicable = {'FrostCursorListSource': 'controller', 'FrostListSource': 'controller', 'FrostRetryAfter': 'data'};
