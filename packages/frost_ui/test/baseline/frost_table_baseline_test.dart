import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frost_ui/frost_ui.dart';

import 'baseline.dart';

void _activate(int _) {}
void _sort((int, bool) _) {}

const _height = 280.0;
const _rows = [0, 1, 2, 3, 4];
final _wide = BaselineEnv.standard.copyWith(width: 900);

Widget _text(BuildContext context, int row) => Text('Item $row');
Widget _size(BuildContext context, int row) => Text('${(row + 1) * 100} KB');
Widget _kind(BuildContext context, int row) => Text(row.isEven ? 'Image' : 'Video');

FrostTableColumn<int> _name({bool primary = true, bool sortable = true, double? width, double minWidth = 80, bool withText = true}) => FrostTableColumn<int>(
  label: 'Name',
  cell: _text,
  text: withText ? (row) => 'Item $row' : null,
  sortKey: sortable ? (row) => row : null,
  width: width,
  minWidth: minWidth,
  primary: primary,
);
FrostTableColumn<int> _sizeColumn({bool numeric = true, double? width, bool sortable = true, bool primary = false}) => FrostTableColumn<int>(
  label: 'Size',
  cell: _size,
  text: (row) => '${(row + 1) * 100} KB',
  sortKey: sortable ? (row) => row : null,
  numeric: numeric,
  primary: primary,
  width: width,
);
final _kindColumn = FrostTableColumn<int>(label: 'Kind', cell: _kind, text: (row) => row.isEven ? 'Image' : 'Video');

List<FrostTableColumn<int>> _columns() => [_name(), _sizeColumn(), _kindColumn];

/// [compactClass] gives the table the compact size class; the size class follows the window, not the parent width.
Widget _table({
  bool compactClass = false,
  List<FrostTableColumn<int>>? columns,
  List<int> rows = _rows,
  int? sortColumn,
  bool sortAscending = true,
  ValueChanged<(int, bool)>? onSort,
  FrostSelection<int>? selection,
  ValueChanged<int>? onActivate,
  FrostTableCompactRow Function(BuildContext, int)? compactRow,
}) {
  final table = FrostTable<int>(
    columns: columns ?? _columns(),
    rows: rows,
    sortColumn: sortColumn,
    sortAscending: sortAscending,
    onSort: onSort,
    selection: selection,
    onActivate: onActivate,
    compactRow: compactRow,
  );
  if (!compactClass) return table;
  return Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(size: const Size(360, 800)),
      child: table,
    ),
  );
}

FrostSelection<int> _selection(Set<int> selected) {
  final selection = FrostSelection<int>();
  selected.forEach(selection.toggle);
  return selection;
}

FrostTableCompactRow _compact(BuildContext context, int row) => FrostTableCompactRow(leading: _box, trailing: Text('#$row'), subtitle: 'Row $row subtitle');

void main() {
  baselineGroup('FrostTable', [
    BaselineCase('FrostTable/required', (_) => _table(), height: _height, envs: [...BaselineEnv.all, _wide]),
    BaselineCase(
      'FrostTable/required+empty',
      (_) => _table(rows: const []),
      height: _height,
      envs: [BaselineEnv.standard, BaselineEnv.narrow],
    ),
    BaselineCase('FrostTable/required+overflowingRows', (_) => _table(rows: [for (var i = 0; i < 40; i++) i]), height: _height),
    BaselineCase('FrostTable/required+singleColumn', (_) => _table(columns: [_name()]), height: _height),

    // Sorting.
    BaselineCase('FrostTable/sortColumn=0', (_) => _table(sortColumn: 0), height: _height, envs: BaselineEnv.themes),
    BaselineCase('FrostTable/sortColumn=1', (_) => _table(sortColumn: 1), height: _height),
    BaselineCase('FrostTable/sortColumn=0+sortAscending=false', (_) => _table(sortColumn: 0, sortAscending: false), height: _height, envs: BaselineEnv.themes),
    BaselineCase('FrostTable/onSort', (_) => _table(onSort: _sort), height: _height),
    BaselineCase(
      'FrostTable/onSort#hover',
      (_) => _table(onSort: _sort),
      height: _height,
      act: (tester, subject) => baselineHover(tester, find.text('Size')),
    ),
    BaselineCase(
      'FrostTable/onSort#press',
      (_) => _table(onSort: _sort),
      height: _height,
      act: (tester, subject) => baselinePress(tester, find.text('Size')),
    ),

    // Row interaction.
    BaselineCase(
      'FrostTable/onActivate',
      (_) => _table(onActivate: _activate),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTable/onActivate#hover',
      (_) => _table(onActivate: _activate),
      height: _height,
      act: (tester, subject) => baselineHover(tester, find.text('Item 2')),
    ),
    BaselineCase(
      'FrostTable/onActivate#press',
      (_) => _table(onActivate: _activate),
      height: _height,
      act: (tester, subject) => baselinePress(tester, find.text('Item 2')),
    ),
    BaselineCase(
      'FrostTable/onActivate#focus',
      (_) => _table(onActivate: _activate),
      height: _height,
      act: baselineFocus,
    ),

    // Selection.
    BaselineCase('FrostTable/selection', (_) => _table(selection: _selection({})), height: _height),
    BaselineCase(
      'FrostTable/selection=selected',
      (_) => _table(selection: _selection({1, 2})),
      height: _height,
      envs: BaselineEnv.themes,
    ),
    BaselineCase(
      'FrostTable/selection=selected+onActivate',
      (_) => _table(selection: _selection({1}), onActivate: _activate),
      height: _height,
    ),
    BaselineCase(
      'FrostTable/selection=selected#hover',
      (_) => _table(selection: _selection({1}), onActivate: _activate),
      height: _height,
      act: (tester, subject) => baselineHover(tester, find.text('Item 3')),
    ),

    // Column arguments.
    BaselineCase('FrostTable/column.width', (_) => _table(columns: [_name(width: 300), _sizeColumn(width: 160), _kindColumn]), height: _height),
    BaselineCase('FrostTable/column.minWidth', (_) => _table(columns: [_name(minWidth: 200), _sizeColumn(), _kindColumn]), height: _height),
    BaselineCase('FrostTable/column.numeric=false', (_) => _table(columns: [_name(), _sizeColumn(numeric: false), _kindColumn]), height: _height),
    BaselineCase('FrostTable/column.primary=none', (_) => _table(columns: [_name(primary: false), _sizeColumn(), _kindColumn]), height: _height),
    BaselineCase('FrostTable/column.primary=second', (_) => _table(columns: [_name(primary: false), _sizeColumn(primary: true), _kindColumn]), height: _height),
    BaselineCase(
      'FrostTable/column.sortKey=none',
      (_) => _table(columns: [_name(sortable: false), _sizeColumn(sortable: false), _kindColumn], sortColumn: 0),
      height: _height,
    ),
    BaselineCase(
      'FrostTable/columnsWiderThanViewport',
      (_) => _table(columns: [_name(width: 400), _sizeColumn(width: 400), _kindColumn]),
      height: _height,
      envs: [BaselineEnv.standard],
    ),

    // Compact layout (narrow parent).
    BaselineCase(
      'FrostTable/compact',
      (_) => _table(compactClass: true),
      height: _height,
      envs: [
        BaselineEnv.narrow,
        BaselineEnv.narrow.copyWith(brightness: Brightness.light),
      ],
    ),
    BaselineCase(
      'FrostTable/compact+primaryWithoutText',
      (_) => _table(compactClass: true, columns: [_name(withText: false), _sizeColumn(), _kindColumn]),
      height: _height,
      envs: [BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostTable/compactRow',
      (_) => _table(compactClass: true, compactRow: _compact),
      height: _height,
      envs: [BaselineEnv.narrow, BaselineEnv.narrow.copyWith(textScale: 2)],
    ),
    BaselineCase(
      'FrostTable/compactRow+onActivate',
      (_) => _table(compactClass: true, compactRow: _compact, onActivate: _activate),
      height: _height,
      envs: [BaselineEnv.narrow, BaselineEnv.touch.copyWith(width: 360)],
    ),
    BaselineCase(
      'FrostTable/compactRow+selection=selected',
      (_) => _table(compactClass: true, compactRow: _compact, selection: _selection({1})),
      height: _height,
      envs: [BaselineEnv.narrow],
    ),
    BaselineCase(
      'FrostTable/compactRow#hover',
      (_) => _table(compactClass: true, compactRow: _compact, onActivate: _activate),
      height: _height,
      envs: [BaselineEnv.narrow],
      act: (tester, subject) => baselineHover(tester, find.text('Row 2 subtitle')),
    ),
  ]);
}

/// Self-sized leading content for compact rows.
const _box = SizedBox.square(
  dimension: 28,
  child: DecoratedBox(decoration: BoxDecoration(color: Color(0xFF3366CC))),
);
