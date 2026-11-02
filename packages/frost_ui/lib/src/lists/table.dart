import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/_layout_scope.dart';
import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_measured_keyline.dart';
import '../primitives/click_surface.dart';
import '../primitives/divider.dart';
import '../primitives/glyph.dart';
import '../primitives/icon.dart';
import '../primitives/presence.dart';
import '_selection_presentation.dart';
import '_table_cells.dart';
import 'list_row.dart';
import 'selection.dart';

// A readable default column and a narrow pointer-only resize target.
const _tableMinimumColumnWidth = 80.0;
const _tableResizeHitWidth = 8.0;
// The rows whose text sizes the automatic columns. The table is lazy, so the
// width never comes from building rows; a long table is sized from its head.
const _tableMeasuredRows = 200;

/// [text] supplies compact-list content and cell context explicitly. Descendant
/// semantics are retained so controls keep their state and accessible actions. Cells
/// without it are omitted from the compact subtitle; a primary cell without
/// text becomes the leading widget with its column label as the row title.
///
/// A column without [width] that is not the primary column is as wide as its
/// header and the longest [text] among the first rows needs; a column without
/// [text] is as wide as its header. The primary column takes the room that is
/// left. When the room runs out the primary column narrows first, then the
/// others, down to their headers. Cells show one line and end in an ellipsis
/// where they do not fit.
class FrostTableColumn<T> {
  const FrostTableColumn({
    required this.label,
    required this.cell,
    this.text,
    this.sortKey,
    this.width,
    this.minWidth = _tableMinimumColumnWidth,
    this.numeric = false,
    this.primary = false,
  }) : assert(minWidth > 0 && minWidth < double.infinity),
       assert(width == null || (width > 0 && width < double.infinity));
  final String label;
  final Widget Function(BuildContext context, T row) cell;
  final String Function(T row)? text;
  final Comparable Function(T row)? sortKey;
  final double? width;
  final double minWidth;
  final bool numeric, primary;
}

/// Optional compact-row composition. The table still owns its lazy viewport,
/// keyboard navigation and activation; independent controls own their input.
/// Null [subtitle] retains the default summary of non-primary text columns.
class FrostTableCompactRow {
  const FrostTableCompactRow({this.leading, this.trailing, this.subtitle});
  final Widget? leading, trailing;
  final String? subtitle;
}

/// A lazy table with a fixed header; provide a finite height. Sorting belongs
/// to the caller. Header and rows scroll horizontally together. Resized widths
/// are stored under this widget's key in the nearest PageStorage bucket.
///
/// With selection, rows follow the shared selectable list's rules, taking effect
/// on pointer up: a plain click activates, Ctrl or Cmd toggles, Shift selects a
/// range, and a touch long press starts selecting.
class FrostTable<T> extends StatefulWidget {
  const FrostTable({
    required this.columns,
    required this.rows,
    this.sortColumn,
    this.sortAscending = true,
    this.onSort,
    this.selection,
    this.onActivate,
    this.compactRow,
    super.key,
  }) : assert(columns.length > 0);
  final List<FrostTableColumn<T>> columns;
  final List<T> rows;
  final int? sortColumn;
  final bool sortAscending;
  final ValueChanged<(int column, bool ascending)>? onSort;
  final FrostSelection<T>? selection;
  final ValueChanged<T>? onActivate;
  final FrostTableCompactRow Function(BuildContext context, T row)? compactRow;
  @override
  State<FrostTable<T>> createState() => _TableState<T>();
}

class _TableState<T> extends State<FrostTable<T>> {
  final _focus = FocusNode();
  final _vertical = ScrollController();
  final _horizontal = ScrollController();
  final _rowKeys = <int, GlobalKey>{};
  final _overrides = <int, double>{};
  // Widths of measured cell text, valid for the style, scale and direction
  // they were measured with.
  final _textWidths = <bool, Map<String, double>>{};
  Object? _textWidthsFor;
  int? _highlight;
  bool _restored = false;
  int _revealGeneration = 0;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      _restored = true;
      final saved = PageStorage.maybeOf(context)?.readState(context, identifier: widget.key);
      if (saved is Map<int, double>) _overrides.addAll(saved);
    }
  }

  @override
  void didUpdateWidget(FrostTable<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_highlight != null && _highlight! >= widget.rows.length) _highlight = widget.rows.isEmpty ? null : widget.rows.length - 1;
    _overrides.removeWhere((index, _) => index >= widget.columns.length);
  }

  @override
  void dispose() {
    _revealGeneration++;
    _focus.dispose();
    _vertical.dispose();
    _horizontal.dispose();
    super.dispose();
  }

  TextStyle _headerStyle(BuildContext context) => FrostTypography.of(context)
      .style(FrostTextRole.footnote)
      .copyWith(color: FrostThemeTokens.of(context).textSecondary, fontWeight: FrostTypography.of(context).style(FrostTextRole.callout).fontWeight);

  double _textWidth(BuildContext context, String text, {required bool numeric}) {
    final style = FrostTypography.of(context).style(FrostTextRole.body, tabular: numeric);
    final scaler = MediaQuery.textScalerOf(context), direction = Directionality.of(context);
    final signature = (style, scaler, direction);
    if (_textWidthsFor != signature) {
      _textWidths.clear();
      _textWidthsFor = signature;
    }
    final cache = _textWidths.putIfAbsent(numeric, () => {});
    if (cache.length > 4096) cache.clear();
    return cache.putIfAbsent(text, () {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final width = painter.width.ceilToDouble();
      painter.dispose();
      return width;
    });
  }

  /// The width the cells of [column] need, from the [FrostTableColumn.text] of
  /// the first rows; zero when the column supplies no text.
  double _contentWidth(BuildContext context, FrostTableColumn<T> column) {
    final text = column.text;
    if (text == null) return 0;
    var widest = 0.0;
    for (var row = 0; row < math.min(widget.rows.length, _tableMeasuredRows); row++) {
      final value = text(widget.rows[row]);
      if (value.isNotEmpty) widest = math.max(widest, _textWidth(context, value, numeric: column.numeric));
    }
    return widest == 0 ? 0 : widest + FrostGap.related * 2;
  }

  List<double> _widths(BuildContext context, double available) {
    final primary = widget.columns.indexWhere((column) => column.primary);
    final main = primary < 0 ? 0 : primary;
    final style = _headerStyle(context);
    final count = widget.columns.length;
    // The narrowest each column goes (its header) and what it wants (its text).
    final floors = List<double>.filled(count, 0), wants = List<double>.filled(count, 0);
    final automatic = <int>[];
    var fixed = 0.0;
    for (var i = 0; i < count; i++) {
      final column = widget.columns[i], explicit = _overrides[i] ?? column.width;
      if (explicit != null) {
        floors[i] = wants[i] = math.max(column.minWidth, explicit);
        fixed += floors[i];
        continue;
      }
      final painter = TextPainter(
        text: TextSpan(text: column.label, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      // Reserve the sort glyph even when hidden, so sorting never shifts columns.
      final sort = column.sortKey == null ? 0.0 : FrostGap.inline + FrostControlSize.compact.iconSize;
      floors[i] = math.max(column.minWidth, painter.width + sort + FrostGap.related * 2);
      painter.dispose();
      wants[i] = i == main ? floors[i] : math.max(floors[i], _contentWidth(context, column));
      if (i != main) automatic.add(i);
    }
    final result = List<double>.of(wants);
    final mainIsAutomatic = _overrides[main] == null && widget.columns[main].width == null;
    final wanted = automatic.fold(0.0, (sum, i) => sum + wants[i]);
    final floor = automatic.fold(0.0, (sum, i) => sum + floors[i]);
    var room = available - fixed - (mainIsAutomatic ? floors[main] : 0.0);
    if (mainIsAutomatic) {
      // The primary column takes what the others leave, and no less than its header.
      result[main] = math.max(floors[main], available - fixed - wanted);
      room = math.max(room, floor);
    }
    if (wanted > room) {
      // Out of room, the others give up what exceeds their headers, evenly.
      final share = wanted == floor ? 0.0 : ((room - floor) / (wanted - floor)).clamp(0.0, 1.0);
      for (final i in automatic) {
        result[i] = floors[i] + (wants[i] - floors[i]) * share;
      }
    }
    return result;
  }

  void _resize(int index, double? width) {
    setState(() {
      if (width == null) {
        _overrides.remove(index);
      } else {
        _overrides[index] = math.max(widget.columns[index].minWidth, width);
      }
    });
    PageStorage.maybeOf(context)?.writeState(context, Map<int, double>.of(_overrides), identifier: widget.key);
  }

  void _point(int index) {
    _revealGeneration++;
    _focus.requestFocus();
    if (_highlight != index) setState(() => _highlight = index);
  }

  void _reveal(int index, int generation) {
    if (!mounted || generation != _revealGeneration || !_vertical.hasClients) return;
    final target = _rowKeys[index]?.currentContext;
    if (target != null) {
      _revealRow(target, ScrollPositionAlignmentPolicy.keepVisibleAtEnd);
      return;
    }
    final position = _vertical.position;
    final step = frostControlGeometry(context, FrostControlSize.regular).height;
    final mountedRows = _rowKeys.entries.where((entry) => entry.value.currentContext != null).map((entry) => entry.key);
    if (mountedRows.isEmpty) return;
    final first = mountedRows.reduce(math.min), last = mountedRows.reduce(math.max);
    final delta = index > last ? index - last : index - first;
    final next = (position.pixels + delta * step).clamp(0.0, position.maxScrollExtent);
    if (next == position.pixels) return;
    position.jumpTo(next);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(index, generation));
  }

  /// Rows span the full table width, so revealing one must not move the table's
  /// own horizontal offset. Scrollables around the table still reveal it.
  void _revealRow(BuildContext target, ScrollPositionAlignmentPolicy policy) {
    var context = target;
    for (var scrollable = Scrollable.maybeOf(context); scrollable != null; scrollable = Scrollable.maybeOf(context)) {
      if (!_horizontal.hasClients || !identical(scrollable.position, _horizontal.position)) {
        scrollable.position.ensureVisible(context.findRenderObject()!, alignmentPolicy: policy);
      }
      context = scrollable.context;
    }
  }

  bool _rowVisible(int index) {
    final box = _rowKeys[index]?.currentContext?.findRenderObject();
    if (box == null || !box.attached || !_vertical.hasClients) return false;
    final viewport = RenderAbstractViewport.maybeOf(box);
    if (viewport == null) return false;
    final position = _vertical.position, top = viewport.getOffsetToReveal(box, 0).offset;
    return top >= position.pixels - .5 && top < position.pixels + position.viewportDimension;
  }

  /// Keyboard focus lands on a row the user can see, so Enter and Space have one to act on.
  void _focusChanged(bool focused) => setState(() {
    if (!focused || widget.rows.isEmpty) return;
    if (_highlight case final index? when _rowVisible(index)) return;
    final mounted = _rowKeys.keys.where((index) => index < widget.rows.length).toList()..sort();
    _highlight = mounted.where(_rowVisible).firstOrNull ?? 0;
  });

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
    // Independent cell controls own their activation keys.
    if (!_focus.hasPrimaryFocus || widget.rows.isEmpty || !FrostControlScope.enabledOf(context)) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp) {
      final old = _highlight;
      final next = old == null
          ? (key == LogicalKeyboardKey.arrowDown ? 0 : widget.rows.length - 1)
          : (old + (key == LogicalKeyboardKey.arrowDown ? 1 : -1)).clamp(0, widget.rows.length - 1);
      final generation = ++_revealGeneration;
      // Preserve direction until an offscreen lazy row has been reached.
      final target = _rowKeys[next]?.currentContext;
      if (target != null) {
        _revealRow(
          target,
          key == LogicalKeyboardKey.arrowDown ? ScrollPositionAlignmentPolicy.keepVisibleAtEnd : ScrollPositionAlignmentPolicy.keepVisibleAtStart,
        );
      } else if (_vertical.hasClients) {
        final position = _vertical.position;
        final estimate = frostControlGeometry(context, FrostControlSize.regular).height;
        position.jumpTo((next * estimate).clamp(0.0, position.maxScrollExtent));
        WidgetsBinding.instance.addPostFrameCallback((_) => _reveal(next, generation));
      }
      setState(() => _highlight = next);
      return KeyEventResult.handled;
    }
    if (_highlight case final index?) {
      if (key == LogicalKeyboardKey.space && widget.selection != null) {
        widget.selection!.toggle(widget.rows[index]);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.enter) {
        widget.onActivate?.call(widget.rows[index]);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Widget _compact(BuildContext context) {
    final primary = widget.columns.indexWhere((c) => c.primary);
    final index = primary < 0 ? 0 : primary, column = widget.columns[primary < 0 ? 0 : primary];
    Widget row(BuildContext context, T item, {int? position}) {
      final composition = widget.compactRow?.call(context, item);
      final subtitle =
          composition?.subtitle ??
          [
            for (var i = 0; i < widget.columns.length; i++)
              if (i != index && widget.columns[i].text != null) widget.columns[i].text!(item),
          ].where((text) => text.isNotEmpty).join(' · ');
      return FrostListRow(
        title: column.text?.call(item) ?? column.label,
        leading: switch (composition?.leading ?? (column.text == null ? column.cell(context, item) : null)) {
          null => null,
          final leading => FrostLeading.custom(leading),
        },
        trailing: composition?.trailing,
        subtitle: subtitle.isEmpty ? null : FrostRowSubtitle(subtitle),
        onPressed: widget.onActivate == null
            ? null
            : () {
                if (position != null) _point(position);
                widget.onActivate!(item);
              },
      );
    }

    final list = Focus(
      focusNode: _focus,
      canRequestFocus: FrostControlScope.enabledOf(context),
      onKeyEvent: _key,
      onFocusChange: _focusChanged,
      child: ListView.builder(
        controller: _vertical,
        itemCount: widget.rows.length,
        itemBuilder: (context, index) => FrostClickHighlight(
          key: _rowKeys.putIfAbsent(index, () => GlobalKey()),
          highlighted: _highlight == index && _focus.hasFocus,
          child: widget.selection == null
              ? row(context, widget.rows[index], position: index)
              : FrostSelectableItem<T>(
                  key: ValueKey(widget.rows[index]),
                  item: widget.rows[index],
                  child: Builder(
                    builder: (context) => Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        row(context, widget.rows[index], position: index),
                        if (index < widget.rows.length - 1)
                          FrostMeasuredKeyline(
                            target: FrostSelectionPresentation.of(context)!.textAnchor,
                            child: const FrostDivider(inset: FrostDividerInset.keyline),
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
    return widget.selection == null ? list : FrostSelectionScope<T>(selection: widget.selection!, items: widget.rows, child: list);
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) => constraints.maxWidth < FrostSizeClass.medium.minimumWidth ? _compact(context) : _columns(context));

  Widget _columns(BuildContext context) {
    Widget table = Focus(
      focusNode: _focus,
      canRequestFocus: FrostControlScope.enabledOf(context),
      onKeyEvent: _key,
      onFocusChange: _focusChanged,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final widths = _widths(context, constraints.maxWidth);
          final total = widths.fold(0.0, (a, b) => a + b);
          return SingleChildScrollView(
            controller: _horizontal,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: total,
              height: constraints.maxHeight,
              child: Semantics(
                role: SemanticsRole.table,
                container: true,
                explicitChildNodes: true,
                label: FrostScope.labelsOf(context).tableDimensions(widget.rows.length, widget.columns.length),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(context, widths),
                    Expanded(
                      child: Scrollable(
                        controller: _vertical,
                        excludeFromSemantics: true,
                        axisDirection: AxisDirection.down,
                        viewportBuilder: (context, offset) => Viewport(
                          offset: offset,
                          axisDirection: AxisDirection.down,
                          crossAxisDirection: Directionality.of(context) == TextDirection.ltr ? AxisDirection.right : AxisDirection.left,
                          slivers: [
                            SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) => _row(context, index, widths),
                                childCount: widget.rows.length,
                                addSemanticIndexes: false,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
    if (widget.selection case final selection?) table = FrostSelectionScope<T>(selection: selection, items: widget.rows, child: table);
    return table;
  }

  Widget _header(BuildContext context, List<double> widths) {
    final tokens = FrostThemeTokens.of(context), direction = Directionality.of(context);
    final geometry = frostControlGeometry(context, FrostControlSize.regular, role: FrostTextRole.footnote);
    var edge = 0.0;
    return Semantics(
      role: SemanticsRole.row,
      container: true,
      explicitChildNodes: true,
      child: Stack(
        children: [
          FrostTableCells(
            widths: widths,
            numeric: widget.columns.map((c) => c.numeric).toList(),
            minimumHeight: geometry.height,
            verticalInset: geometry.verticalInset,
            horizontalInset: FrostGap.related,
            direction: direction,
            children: [
              for (var i = 0; i < widget.columns.length; i++)
                Semantics(
                  role: SemanticsRole.columnHeader,
                  container: true,
                  button: widget.columns[i].sortKey != null && widget.onSort != null,
                  onTap: widget.columns[i].sortKey == null || widget.onSort == null
                      ? null
                      : () => widget.onSort!((i, widget.sortColumn == i ? !widget.sortAscending : true)),
                  label: widget.columns[i].label,
                  value: widget.sortColumn == i
                      ? (widget.sortAscending ? FrostScope.labelsOf(context).sortAscending : FrostScope.labelsOf(context).sortDescending)
                      : null,
                  excludeSemantics: true,
                  child: FrostClickSurface(
                    onTap: widget.columns[i].sortKey == null || widget.onSort == null
                        ? null
                        : () => widget.onSort!((i, widget.sortColumn == i ? !widget.sortAscending : true)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: FrostSkeletonText(
                            child: Text(widget.columns[i].label, style: _headerStyle(context), maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        if (widget.columns[i].sortKey != null)
                          FrostPresence(
                            visible: widget.sortColumn == i,
                            effect: FrostPresenceEffect.expand,
                            axis: Axis.horizontal,
                            child: Padding(
                              padding: const EdgeInsetsDirectional.only(start: FrostGap.inline),
                              child: AnimatedRotation(
                                turns: widget.sortAscending ? 0 : .5,
                                duration: FrostMotion.duration(context, FrostMotion.hover),
                                curve: FrostMotion.hoverCurve,
                                child: FrostIcon(FrostIconSet.of(context).chevronUp, size: FrostControlSize.compact.iconSize, color: tokens.textSecondary),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          for (var i = 0; i < widths.length; i++) ...[_resizeHandle(context, i, edge += widths[i], widths[i], direction)],
        ],
      ),
    );
  }

  Widget _resizeHandle(BuildContext context, int index, double edge, double width, TextDirection direction) {
    var current = width;
    return PositionedDirectional(
      start: edge - _tableResizeHitWidth / 2,
      top: 0,
      bottom: 0,
      width: _tableResizeHitWidth,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragStart: (_) => current = width,
            onHorizontalDragUpdate: (details) {
              current += (direction == TextDirection.ltr ? 1 : -1) * details.delta.dx;
              current = math.max(widget.columns[index].minWidth, current);
              _resize(index, current);
            },
            onDoubleTap: () => _resize(index, null),
            child: const Center(child: FrostDivider(axis: Axis.vertical)),
          ),
        ),
      ),
    );
  }

  Widget _row(BuildContext context, int index, List<double> widths) {
    final item = widget.rows[index];
    Widget buildRow(BuildContext context) {
      final presentation = widget.selection == null ? null : FrostSelectionPresentation.of(context);
      final tokens = FrostThemeTokens.of(context);
      final geometry = frostControlGeometry(context, FrostControlSize.regular);
      return _TableRow(
        key: _rowKeys.putIfAbsent(index, () => GlobalKey()),
        selected: presentation?.selected,
        highlighted: _highlight == index && _focus.hasFocus,
        point: () => _point(index),
        activate: switch ((presentation, widget.onActivate)) {
          (final presentation?, final open) => () => presentation.activate(open == null ? null : () => open(item)),
          (null, final open?) => () => open(item),
          (null, null) => null,
        },
        longPress: presentation?.longPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            FrostTableCells(
              widths: widths,
              numeric: widget.columns.map((c) => c.numeric).toList(),
              minimumHeight: geometry.height,
              verticalInset: geometry.verticalInset,
              horizontalInset: FrostGap.related,
              direction: Directionality.of(context),
              children: [
                for (final column in widget.columns)
                  Semantics(
                    role: SemanticsRole.cell,
                    container: true,
                    explicitChildNodes: true,
                    label: column.text?.call(item),
                    child: DefaultTextStyle(
                      style: FrostTypography.of(context).style(FrostTextRole.body, tabular: column.numeric).copyWith(color: tokens.textPrimary),
                      textAlign: column.numeric ? TextAlign.end : TextAlign.start,
                      // A word never breaks inside a cell: one line, then an ellipsis.
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      child: column.cell(context, item),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: FrostGap.related),
              child: const FrostDivider(),
            ),
          ],
        ),
      );
    }

    return widget.selection == null
        ? buildRow(context)
        : FrostTableSelectionItem<T>(
            item: item,
            child: Builder(builder: buildRow),
          );
  }
}

class _TableRow extends StatefulWidget {
  const _TableRow({
    required this.child,
    required this.point,
    required this.activate,
    required this.longPress,
    required this.selected,
    required this.highlighted,
    super.key,
  });
  final Widget child;
  final VoidCallback point;
  final VoidCallback? activate, longPress;
  final bool? selected;
  final bool highlighted;
  @override
  State<_TableRow> createState() => _TableRowState();
}

class _TableRowState extends State<_TableRow> {
  final _marker = Object();
  bool _hover = false, _pressed = false, _mainPress = false;
  bool get _enabled => FrostControlScope.enabledOf(context);
  bool _mainTarget(PointerEvent event) {
    final hit = HitTestResult();
    GestureBinding.instance.hitTestInView(hit, event.position, event.viewId);
    for (final entry in hit.path) {
      final target = entry.target;
      if (target is RenderMetaData && identical(target.metaData, _marker)) return true;
      if (target is RenderMouseRegion && target.cursor != MouseCursor.defer) return false;
    }
    return false;
  }

  void _down(PointerDownEvent event) {
    _mainPress = _enabled && event.buttons == kPrimaryButton && _mainTarget(event);
    if (_mainPress) setState(() => _pressed = true);
  }

  void _activate() {
    widget.point();
    widget.activate?.call();
  }

  void _release() {
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final row = MetaData(
      metaData: frostSelectionInputTarget,
      behavior: HitTestBehavior.translucent,
      child: Semantics(
        role: SemanticsRole.row,
        container: true,
        explicitChildNodes: true,
        selected: widget.selected,
        onTap: _enabled ? _activate : null,
        child: MouseRegion(
          cursor: _enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
          onEnter: (event) => setState(() => _hover = _mainTarget(event)),
          onHover: (event) {
            final hover = _mainTarget(event);
            if (hover != _hover) setState(() => _hover = hover);
          },
          onExit: (_) => setState(() => _hover = false),
          child: Listener(
            behavior: HitTestBehavior.translucent,
            onPointerDown: _down,
            onPointerUp: (_) => _release(),
            onPointerCancel: (_) => _release(),
            child: GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTap: _enabled
                  ? () {
                      if (_mainPress) _activate();
                    }
                  : null,
              onTapCancel: _release,
              child: AnimatedContainer(
                duration: FrostMotion.duration(context, FrostMotion.hover),
                curve: FrostMotion.hoverCurve,
                color: widget.selected == true ? tokens.selectionFill : (_hover || widget.highlighted ? tokens.fillSubtle : Colors.transparent),
                child: FrostClickFeedbackVisual(
                  states: {if (_pressed) WidgetState.pressed, if (widget.highlighted) WidgetState.focused},
                  scalesOnPress: false,
                  child: MetaData(metaData: _marker, behavior: HitTestBehavior.translucent, child: widget.child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return RawGestureDetector(
      excludeFromSemantics: true,
      gestures: {
        if (_enabled && widget.longPress != null)
          _TableLongPress: GestureRecognizerFactoryWithHandlers<_TableLongPress>(
            () => _TableLongPress(_mainTarget),
            (recognizer) => recognizer.onLongPress = widget.longPress,
          ),
      },
      child: row,
    );
  }
}

// Only touch long-presses a row, and a press on a nested cell control stays its own.
class _TableLongPress extends LongPressGestureRecognizer {
  _TableLongPress(this.mainTarget) : super(supportedDevices: const {PointerDeviceKind.touch, PointerDeviceKind.stylus, PointerDeviceKind.invertedStylus});
  final bool Function(PointerEvent) mainTarget;
  @override
  bool isPointerAllowed(PointerDownEvent event) => mainTarget(event) && super.isPointerAllowed(event);
}
