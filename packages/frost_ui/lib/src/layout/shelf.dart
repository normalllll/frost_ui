import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/scope.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// A titled horizontal row of items. The title, its actions and the first and
/// last items share one inset, so the row lines up with the grid below it.
/// Pointer platforms also get previous/next buttons next to the title,
/// because a mouse wheel does not scroll a horizontal list.
class FrostShelf extends StatefulWidget {
  const FrostShelf({
    required this.title,
    required this.itemCount,
    required this.itemExtent,
    required this.height,
    required this.itemBuilder,
    this.action,
    this.spacing = FrostMetrics.itemGap,
    this.inset,
    super.key,
  });

  final String title;
  final int itemCount;
  final double itemExtent;
  final double height;
  final IndexedWidgetBuilder itemBuilder;
  final Widget? action;
  final double spacing;

  /// Defaults to [FrostMetrics.browseInset] for the shelf's own width.
  final double? inset;

  /// Item size that fills [width] with [count] items, within [min]..[max].
  static double fillingExtent({required double width, required int count, required double min, required double max, double spacing = FrostMetrics.itemGap}) {
    if (count <= 0 || !width.isFinite) return min;
    return ((width - spacing * (count - 1)) / count).clamp(min, max);
  }

  @override
  State<FrostShelf> createState() => _ContentShelfState();
}

class _ContentShelfState extends State<FrostShelf> {
  final _controller = ScrollController();
  bool _canGoBack = false;
  bool _canGoForward = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _updateEdges(ScrollMetrics metrics) {
    final back = metrics.extentBefore > .5;
    final forward = metrics.extentAfter > .5;
    if (back != _canGoBack || forward != _canGoForward) {
      setState(() {
        _canGoBack = back;
        _canGoForward = forward;
      });
    }
    return false;
  }

  void _page(int direction) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final step = math.max(widget.itemExtent + widget.spacing, position.viewportDimension - widget.itemExtent);
    final target = (position.pixels + step * direction).clamp(position.minScrollExtent, position.maxScrollExtent);
    final duration = FrostMotion.duration(context, FrostMotion.expand);
    if (duration == Duration.zero) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(target, duration: duration, curve: Curves.easeOutCubic);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pointer = switch (Theme.of(context).platform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => true,
      _ => false,
    };
    return LayoutBuilder(
      builder: (context, constraints) {
        final inset = widget.inset ?? FrostMetrics.browseInset(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FrostShelfHeader(
              title: widget.title,
              inset: inset,
              trailing: [
                if (pointer && (_canGoBack || _canGoForward)) ...[
                  IconButton(
                    tooltip: FrostScope.labelsOf(context).previous,
                    onPressed: _canGoBack ? () => _page(-1) : null,
                    icon: FrostIcon(FrostIconSet.of(context).chevronLeft),
                  ),
                  IconButton(
                    tooltip: FrostScope.labelsOf(context).next,
                    onPressed: _canGoForward ? () => _page(1) : null,
                    icon: FrostIcon(FrostIconSet.of(context).chevronRight),
                  ),
                ],
                ?widget.action,
              ],
            ),
            SizedBox(
              height: widget.height,
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: (notification) => _updateEdges(notification.metrics),
                child: NotificationListener<ScrollNotification>(
                  onNotification: (notification) => _updateEdges(notification.metrics),
                  child: ListView.separated(
                    controller: _controller,
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: inset),
                    itemCount: widget.itemCount,
                    separatorBuilder: (context, index) => SizedBox(width: widget.spacing),
                    itemBuilder: (context, index) => SizedBox(width: widget.itemExtent, child: widget.itemBuilder(context, index)),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Section title row shared by shelves, grids and their skeletons.
class FrostShelfHeader extends StatelessWidget {
  const FrostShelfHeader({required this.title, required this.inset, this.trailing = const [], this.skeleton = false, super.key});

  final String title;
  final double inset;
  final List<Widget> trailing;
  final bool skeleton;

  @override
  Widget build(BuildContext context) {
    final text = Text(title, style: Theme.of(context).textTheme.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis);
    return Padding(
      // Trailing buttons carry their own padding; keep their glyphs on the inset.
      padding: EdgeInsetsDirectional.fromSTEB(inset, FrostMetrics.compactGap, math.max(0, inset - 8), FrostMetrics.compactGap / 2),
      child: SizedBox(
        height: FrostMetrics.compactTargetHeight,
        child: Row(
          children: [
            Expanded(child: skeleton ? Skeletonizer.zone(child: text) : text),
            ...trailing,
          ],
        ),
      ),
    );
  }
}
