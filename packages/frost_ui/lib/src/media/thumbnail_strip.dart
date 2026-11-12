import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../foundation/_key_bindings.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../motion/spring.dart';
import '../primitives/_media_selection.dart';
import '../primitives/_scroll_edge_fade.dart';
import 'thumbnail.dart';

// Leave room for the outside selection ring and its antialiased fringe (one
// more logical pixel) at the viewport's clipped edges.
const _thumbnailStripInset = frostMediaSelectionGap + frostThumbnailRingWidth + 1;
const _thumbnailSpacing = 8.0;

/// A controlled, lazy strip with one keyboard stop. Pointer selection preserves scroll; keyboard and
/// external paging reveal offscreen selections with the smallest movement.
class FrostThumbnailStrip extends StatefulWidget {
  const FrostThumbnailStrip({
    required this.itemCount,
    required this.itemBuilder,
    required this.selectedIndex,
    required this.onSelected,
    this.size = FrostThumbnailSize.regular,
    super.key,
  }) : assert(itemCount >= 0),
       assert(selectedIndex == null || (selectedIndex >= 0 && selectedIndex < itemCount));
  final int itemCount;

  /// Returns only image content; the strip supplies each thumbnail's chrome.
  final IndexedWidgetBuilder itemBuilder;
  final int? selectedIndex;
  final ValueChanged<int>? onSelected;
  final FrostThumbnailSize size;
  @override
  State<FrostThumbnailStrip> createState() => _FrostThumbnailStripState();
}

class _FrostThumbnailStripState extends State<FrostThumbnailStrip> {
  late final _controller = _VisibleController(widget.selectedIndex, frostThumbnailExtent(widget.size));
  final _focus = FocusNode();
  int? _pointerSelection;

  @override
  void didUpdateWidget(FrostThumbnailStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIndex != oldWidget.selectedIndex || widget.size != oldWidget.size) {
      if (widget.selectedIndex != _pointerSelection && widget.selectedIndex != null) {
        _reveal(widget.selectedIndex!);
      }
      _pointerSelection = null;
    }
  }

  void _reveal(int index) {
    if (!_controller.hasClients || !_controller.position.hasContentDimensions) return;
    final position = _controller.position;
    final extent = frostThumbnailExtent(widget.size);
    final start = index * (extent + _thumbnailSpacing);
    final end = start + extent + _thumbnailStripInset * 2;
    final offset =
        (start < position.pixels
                ? start
                : end > position.pixels + position.viewportDimension
                ? end - position.viewportDimension
                : position.pixels)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    if (offset == position.pixels) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpTo(offset);
    } else {
      _controller.animateTo(offset, duration: FrostMotion.standardDuration, curve: FrostSpringCurve(FrostMotion.standard, FrostMotion.standardDuration));
    }
  }

  void _select(int index, {bool pointer = false}) {
    _focus.requestFocus();
    _pointerSelection = pointer ? index : null;
    widget.onSelected?.call(index);
    if (!pointer) _reveal(index);
  }

  bool get _interactive => widget.onSelected != null && widget.itemCount > 0;

  /// Left and Right step the selection, mirrored in RTL; Home and End select
  /// the first and last. The strip is one focus stop and takes these keys
  /// before an enclosing pager.
  Map<ShortcutActivator, bool Function()> get _keys {
    bool to(int Function(int? current, int last, bool rtl) next) {
      if (!_interactive) return false;
      _select(next(widget.selectedIndex, widget.itemCount - 1, Directionality.of(context) == TextDirection.rtl));
      return true;
    }

    return {
      const FrostKeyPress(LogicalKeyboardKey.arrowRight): () =>
          to((current, last, rtl) => current == null ? (rtl ? last : 0) : (current + (rtl ? -1 : 1)).clamp(0, last)),
      const FrostKeyPress(LogicalKeyboardKey.arrowLeft): () =>
          to((current, last, rtl) => current == null ? (rtl ? 0 : last) : (current + (rtl ? 1 : -1)).clamp(0, last)),
      const FrostKeyPress(LogicalKeyboardKey.home): () => to((_, _, _) => 0),
      const FrostKeyPress(LogicalKeyboardKey.end): () => to((_, last, _) => last),
    };
  }

  @override
  void dispose() {
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final extent = frostThumbnailExtent(widget.size);
    return FrostKeyBindings(
      bindings: _keys,
      child: Focus(
        focusNode: _focus,
        canRequestFocus: _interactive,
        child: SizedBox(
          height: extent + _thumbnailStripInset * 2,
          child: FrostScrollEdgeFade(
            controller: _controller,
            child: ExcludeFocus(
              child: ListView.builder(
                controller: _controller,
                scrollDirection: Axis.horizontal,
                itemExtentBuilder: (index, _) => extent + (index == widget.itemCount - 1 ? 0 : _thumbnailSpacing),
                padding: const EdgeInsets.all(_thumbnailStripInset),
                itemCount: widget.itemCount,
                itemBuilder: (context, index) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FrostThumbnail(
                    size: widget.size,
                    image: widget.itemBuilder(context, index),
                    selected: index == widget.selectedIndex,
                    semanticLabel: FrostScope.labelsOf(context).pageOf(index + 1, widget.itemCount),
                    onPressed: widget.onSelected == null ? null : () => _select(index, pointer: true),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VisibleController extends ScrollController {
  _VisibleController(this.index, this.extent) : super(keepScrollOffset: false);
  final int? index;
  final double extent;
  @override
  ScrollPosition createScrollPosition(ScrollPhysics physics, ScrollContext context, ScrollPosition? oldPosition) =>
      _VisiblePosition(physics: physics, context: context, oldPosition: oldPosition, index: index, extent: extent);
}

class _VisiblePosition extends ScrollPositionWithSingleContext {
  _VisiblePosition({required super.physics, required super.context, super.oldPosition, required this.index, required this.extent})
    : super(keepScrollOffset: false);
  final int? index;
  final double extent;
  bool _placed = false;

  @override
  bool applyContentDimensions(double minScrollExtent, double maxScrollExtent) {
    if (!_placed && hasViewportDimension) {
      _placed = true;
      final target = index == null ? 0.0 : _thumbnailStripInset + index! * (extent + _thumbnailSpacing) + extent + _thumbnailStripInset - viewportDimension;
      final corrected = target.clamp(minScrollExtent, math.max(minScrollExtent, maxScrollExtent));
      if (corrected != pixels) {
        correctPixels(corrected.toDouble());
        super.applyContentDimensions(minScrollExtent, maxScrollExtent);
        return false;
      }
    }
    return super.applyContentDimensions(minScrollExtent, maxScrollExtent);
  }
}
