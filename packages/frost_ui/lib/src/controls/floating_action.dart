import 'package:flutter/widgets.dart';

import '../foundation/density.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../motion/layout_crossfade.dart';
import '_button_control.dart';
import '_button_types.dart';

/// A page's primary action floating over its scroll view, at the end corner.
///
/// The button shows its label until the page scrolls down and then collapses
/// to its icon; scrolling back up (or reaching the top) shows the label again.
/// The layer also adds the button's height and gap to the bottom padding the
/// [child] scroll view sees, so the last item can always scroll clear of the
/// button. Scroll views that take their own explicit `padding` must add
/// [FrostFloatingActionLayer.reservedHeightOf] themselves.
class FrostFloatingActionLayer extends StatefulWidget {
  const FrostFloatingActionLayer({required this.child, required this.label, required this.icon, required this.onPressed, super.key});

  final Widget child;
  final String label;
  final FrostIconData icon;
  final VoidCallback? onPressed;

  /// The bottom space a [FrostFloatingActionLayer] reserves for its button.
  static double reservedHeightOf(BuildContext context) => _buttonHeight(context) + FrostGap.of(context).section + FrostGap.of(context).related;

  static double _buttonHeight(BuildContext context) => FrostControlSize.regular.height(context) > FrostDensity.of(context).targetHeight
      ? FrostControlSize.regular.height(context)
      : FrostDensity.of(context).targetHeight;

  @override
  State<FrostFloatingActionLayer> createState() => _FrostFloatingActionLayerState();
}

class _FrostFloatingActionLayerState extends State<FrostFloatingActionLayer> {
  static const _threshold = 2.0;
  bool _extended = true;

  bool _scrolled(ScrollNotification notification) {
    if (notification.depth != 0 || notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final next = notification.metrics.pixels <= notification.metrics.minScrollExtent
          ? true
          : delta > _threshold
          ? false
          : delta < -_threshold
          ? true
          : _extended;
      if (next != _extended) setState(() => _extended = next);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final gap = FrostGap.of(context).section;
    final reserved = FrostFloatingActionLayer.reservedHeightOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: _scrolled,
            child: MediaQuery(
              data: media.copyWith(padding: media.padding.copyWith(bottom: media.padding.bottom + reserved)),
              child: widget.child,
            ),
          ),
        ),
        PositionedDirectional(
          end: gap,
          bottom: gap + media.padding.bottom,
          child: FrostMotionSize(
            duration: FrostMotion.duration(context, FrostMotion.expand),
            curve: Curves.easeOutCubic,
            alignment: AlignmentDirectional.centerEnd,
            child: FrostButtonControl(
              label: widget.label,
              icon: widget.icon,
              onPressed: widget.onPressed,
              variant: FrostButtonVariant.prominent,
              shape: FrostButtonShape.pill,
              showsLabel: _extended,
            ),
          ),
        ),
      ],
    );
  }
}
