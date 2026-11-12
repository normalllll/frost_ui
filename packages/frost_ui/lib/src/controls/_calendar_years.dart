import 'dart:math' as math;

import 'package:flutter/material.dart' show MaterialLocalizations;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_key_bindings.dart';
import '../foundation/metrics.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_click_feedback.dart';
import '_calendar.dart';
import '_input_surface.dart';

/// The list of years a calendar shows in place of its day grid. It is one Tab
/// stop: arrow keys move inside it and Escape returns to the days.
class FrostCalendarYears extends StatefulWidget {
  const FrostCalendarYears({
    required this.first,
    required this.last,
    required this.shown,
    required this.currentYear,
    required this.columns,
    required this.rowHeight,
    required this.onSelected,
    required this.onDismissed,
    super.key,
  });
  final int first, last, shown, currentYear, columns;
  final double rowHeight;
  final ValueChanged<int> onSelected;
  final VoidCallback onDismissed;
  @override
  State<FrostCalendarYears> createState() => _CalendarYearsState();
}

class _CalendarYearsState extends State<FrostCalendarYears> {
  late int _focused = widget.shown.clamp(widget.first, widget.last);
  ScrollController? _scroll;
  final _nodes = <int, FocusNode>{};

  int _row(int year) => (year - widget.first) ~/ widget.columns;
  double get _contentHeight => (_row(widget.last) + 1) * widget.rowHeight;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _requestFocus(_focused);
    });
  }

  @override
  void dispose() {
    for (final node in _nodes.values) {
      node.dispose();
    }
    _scroll?.dispose();
    super.dispose();
  }

  void _requestFocus(int year) {
    final node = _nodes[year];
    if (node?.context != null) FocusTraversalPolicy.defaultTraversalRequestFocusCallback(node!);
  }

  FocusNode _node(int year) => _nodes.putIfAbsent(year, FocusNode.new)..skipTraversal = year != _focused;

  // A year far from the viewport has no cell yet: reveal its row first.
  void _move(int year) {
    year = year.clamp(widget.first, widget.last);
    final scroll = _scroll!, top = _row(year) * widget.rowHeight;
    final viewport = scroll.position.viewportDimension;
    if (top < scroll.offset) {
      scroll.jumpTo(top);
    } else if (top + widget.rowHeight > scroll.offset + viewport) {
      scroll.jumpTo(top + widget.rowHeight - viewport);
    }
    setState(() => _focused = year);
    _refocus();
  }

  void _refocus() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) _requestFocus(_focused);
  });

  // Scrolling disposes cells that leave the viewport, so focus moves with the
  // list before the focused cell goes: same column, nearest fully visible row.
  void _followScroll() {
    if (!(_nodes[_focused]?.hasPrimaryFocus ?? false)) return;
    final scroll = _scroll!, height = widget.rowHeight;
    final firstRow = (scroll.offset / height).ceil(), lastRow = ((scroll.offset + scroll.position.viewportDimension) / height).floor() - 1;
    if (lastRow < firstRow) return;
    final row = _row(_focused), target = row.clamp(firstRow, lastRow);
    if (target == row) return;
    setState(() => _focused = (_focused + (target - row) * widget.columns).clamp(widget.first, widget.last));
    _refocus();
  }

  static const _yearKeys = [
    LogicalKeyboardKey.arrowLeft,
    LogicalKeyboardKey.arrowRight,
    LogicalKeyboardKey.arrowUp,
    LogicalKeyboardKey.arrowDown,
    LogicalKeyboardKey.pageUp,
    LogicalKeyboardKey.pageDown,
    LogicalKeyboardKey.home,
    LogicalKeyboardKey.end,
  ];

  /// Arrows move by year and row, Page Up/Down by a screenful, Home and End to
  /// the ends of the row. Dismissing (Escape by default) returns to the days.
  Widget _keys(int year, Widget child) => Actions(
    actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => widget.onDismissed())},
    child: FrostKeyBindings(
      bindings: {
        for (final key in _yearKeys)
          FrostKeyPress(key): () {
            _move(_target(key, year));
            return true;
          },
      },
      child: child,
    ),
  );

  int _target(LogicalKeyboardKey key, int year) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final columns = widget.columns, column = (year - widget.first) % columns;
    final page = math.max(1, _scroll!.position.viewportDimension ~/ widget.rowHeight) * columns;
    return switch (key) {
      LogicalKeyboardKey.arrowLeft => year + (rtl ? 1 : -1),
      LogicalKeyboardKey.arrowRight => year + (rtl ? -1 : 1),
      LogicalKeyboardKey.arrowUp => year - columns,
      LogicalKeyboardKey.arrowDown => year + columns,
      LogicalKeyboardKey.pageUp => year - page,
      LogicalKeyboardKey.pageDown => year + page,
      LogicalKeyboardKey.home => year - column,
      _ => year + columns - 1 - column,
    };
  }

  Widget _year(BuildContext context, int index) {
    final year = widget.first + index, selected = year == widget.shown;
    final tokens = FrostThemeTokens.of(context), localizations = MaterialLocalizations.of(context);
    final text = localizations.formatYear(DateTime(year));
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: text,
      onTap: () => widget.onSelected(year),
      child: ExcludeSemantics(
        child: _keys(
          year,
          FrostInputSurface(
            focusNode: _node(year),
            onTap: () => widget.onSelected(year),
            builder: (context, states) => Padding(
              padding: const EdgeInsets.all(frostCalendarCircleInset / 2),
              child: FrostClickFeedbackVisual(
                states: states,
                shape: const StadiumBorder(),
                scalesOnPress: false,
                child: AnimatedContainer(
                  duration: FrostMotion.duration(context, FrostMotion.hover),
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(shape: const StadiumBorder(), color: selected ? tokens.actionFill : tokens.actionFill.withValues(alpha: 0)),
                  child: FrostSkeletonText(
                    child: Text(
                      text,
                      style: FrostTypography.of(context)
                          .style(FrostTextRole.callout, tabular: true)
                          .copyWith(
                            color: selected
                                ? tokens.onAction
                                : year == widget.currentYear
                                ? tokens.accentInk
                                : tokens.textPrimary,
                          ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final centered = (_row(_focused) + 0.5) * widget.rowHeight - constraints.maxHeight / 2;
      _scroll ??= ScrollController(initialScrollOffset: centered.clamp(0.0, math.max(0.0, _contentHeight - constraints.maxHeight)))..addListener(_followScroll);
      return GridView.builder(
        controller: _scroll,
        padding: EdgeInsets.zero,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: widget.columns, mainAxisExtent: widget.rowHeight),
        itemCount: widget.last - widget.first + 1,
        itemBuilder: _year,
      );
    },
  );
}
