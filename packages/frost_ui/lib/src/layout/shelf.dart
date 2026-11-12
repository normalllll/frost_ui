import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../controls/buttons.dart';
import '../display/section_header.dart';
import '../foundation/density.dart';
import '../foundation/input_feedback.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../primitives/_directional_icon.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/_scroll_edge_fade.dart';
import '../primitives/keyline.dart';
import '../primitives/presence.dart';

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
    this.spacing = FrostGap.group,
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
  static double fillingExtent({required double width, required int count, required double min, required double max, double spacing = FrostGap.group}) {
    if (count <= 0 || !width.isFinite) return min;
    return ((width - spacing * (count - 1)) / count).clamp(min, max);
  }

  @override
  State<FrostShelf> createState() => _ContentShelfState();
}

class _ContentShelfState extends State<FrostShelf> {
  // This private horizontal position must never read the page's vertical key.
  final _controller = ScrollController(keepScrollOffset: false);
  final _edges = ValueNotifier((back: false, forward: false));
  ({bool back, bool forward}) _pendingEdges = (back: false, forward: false);
  bool _edgeUpdateScheduled = false;

  @override
  void dispose() {
    _controller.dispose();
    _edges.dispose();
    super.dispose();
  }

  bool _updateEdges(ScrollMetrics metrics) {
    _pendingEdges = (back: metrics.extentBefore > 0, forward: metrics.extentAfter > 0);
    // Applying viewport dimensions can synchronously emit scroll notifications
    // during layout. Even a ValueNotifier would rebuild its listeners there;
    // coalesce those notifications until the frame ends, using latest metrics.
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      if (!_edgeUpdateScheduled) {
        _edgeUpdateScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _edgeUpdateScheduled = false;
          if (mounted) _edges.value = _pendingEdges;
        });
      }
    } else {
      _edges.value = _pendingEdges;
    }
    return false;
  }

  double get _spacing => widget.spacing == FrostGap.group ? FrostGap.of(context).group : widget.spacing;

  void _page(int direction) {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final step = math.max(widget.itemExtent + _spacing, position.viewportDimension - widget.itemExtent);
    final target = (position.pixels + step * direction).clamp(position.minScrollExtent, position.maxScrollExtent);
    final duration = FrostMotion.duration(context, FrostMotion.expand);
    if (duration == Duration.zero) {
      _controller.jumpTo(target);
    } else {
      _controller.animateTo(target, duration: duration, curve: Curves.easeOutCubic);
    }
  }

  /// A vertical wheel moves the shelf only where no page can use it: over a
  /// scrolling page it keeps scrolling the page.
  void _wheel(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dx != 0 || event.scrollDelta.dy == 0 || !_controller.hasClients) return;
    final page = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (page != null && page.maxScrollExtent > page.minScrollExtent) return;
    final position = _controller.position, delta = event.scrollDelta.dy;
    if ((position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent) == position.pixels) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) => position.pointerScroll(delta));
  }

  // The fixed item geometry also establishes cold-frame and resize button states
  // before ScrollPosition applies new dimensions.
  ({bool back, bool forward}) _edgesAt(double width, double inset) {
    final maximum = math.max(0.0, inset * 2 + widget.itemCount * widget.itemExtent + math.max(0, widget.itemCount - 1) * _spacing - width);
    final pixels = _controller.hasClients ? _controller.position.pixels.clamp(0.0, maximum) : 0.0;
    return (back: pixels > 0, forward: pixels < maximum);
  }

  @override
  Widget build(BuildContext context) {
    final naturalInset = widget.inset ?? FrostMetrics.browseInset(0);
    final header = frostTextLineSize(context, widget.title, FrostTypography.of(context).style(FrostTextRole.headline)).height;
    return FrostMeasuredLayoutBuilder(
      naturalSize: Size(
        naturalInset * 2 + widget.itemCount * widget.itemExtent + math.max(0, widget.itemCount - 1) * _spacing,
        math.max(header, FrostDensity.of(context).targetHeight) + FrostGap.group * 2 + widget.height,
      ),
      builder: (context, constraints) {
        final inset = widget.inset ?? FrostMetrics.browseInset(constraints.maxWidth);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ValueListenableBuilder(
              valueListenable: _edges,
              builder: (context, _, _) {
                final edges = _edgesAt(constraints.maxWidth, inset);
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: inset),
                  child: FrostKeyline(
                    leadingRoom: inset,
                    trailingRoom: inset,
                    edgeDistanceStart: inset,
                    edgeDistanceEnd: inset,
                    insideContainer: false,
                    contentStart: inset,
                    child: FrostSectionHeader(
                      title: widget.title,
                      trailing: [
                        ?widget.action,
                        if (FrostDensity.of(context).usesPointer) ...[
                          FrostButton.icon(
                            label: FrostScope.labelsOf(context).previous,
                            size: FrostControlSize.compact,
                            onPressed: edges.back ? () => _page(-1) : null,
                            icon: frostStepChevron(context, previous: true),
                          ),
                          FrostButton.icon(
                            label: FrostScope.labelsOf(context).next,
                            size: FrostControlSize.compact,
                            onPressed: edges.forward ? () => _page(1) : null,
                            icon: frostStepChevron(context, previous: false),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            SizedBox(
              height: widget.height,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  NotificationListener<ScrollMetricsNotification>(
                    onNotification: (notification) => _updateEdges(notification.metrics),
                    child: NotificationListener<ScrollNotification>(
                      onNotification: (notification) => _updateEdges(notification.metrics),
                      child: FrostScrollEdgeFade(
                        controller: _controller,
                        repaint: _edges,
                        child: Listener(
                          onPointerSignal: _wheel,
                          child: ListView.separated(
                            controller: _controller,
                            scrollDirection: Axis.horizontal,
                            padding: EdgeInsets.symmetric(horizontal: inset),
                            itemCount: widget.itemCount,
                            separatorBuilder: (context, index) => SizedBox(width: _spacing),
                            itemBuilder: (context, index) => SizedBox(width: widget.itemExtent, child: widget.itemBuilder(context, index)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // A mouse that arrives late on a touch device finds the same paging
                  // over the strip, so nothing in the shelf moves to make room.
                  if (!FrostDensity.of(context).usesPointer)
                    FrostInputBuilder(
                      builder: (context, input) => !input.hoverAvailable
                          ? const SizedBox.shrink()
                          : ValueListenableBuilder(
                              valueListenable: _edges,
                              builder: (context, _, _) {
                                final edges = _edgesAt(constraints.maxWidth, inset);
                                return Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: FrostGap.related),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      FrostPresence(
                                        visible: edges.back,
                                        child: FrostButton.iconOnMedia(
                                          label: FrostScope.labelsOf(context).previous,
                                          size: FrostControlSize.compact,
                                          onPressed: () => _page(-1),
                                          icon: frostStepChevron(context, previous: true),
                                        ),
                                      ),
                                      FrostPresence(
                                        visible: edges.forward,
                                        child: FrostButton.iconOnMedia(
                                          label: FrostScope.labelsOf(context).next,
                                          size: FrostControlSize.compact,
                                          onPressed: () => _page(1),
                                          icon: frostStepChevron(context, previous: false),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
