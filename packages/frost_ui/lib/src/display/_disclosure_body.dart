import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../motion/_material_reveal.dart';
import '../motion/layout_crossfade.dart';
import '../motion/spring.dart';
import '../primitives/keyline.dart';

/// The rotation that turns a disclosure's directional chevron into a down
/// arrow while expanded: a quarter turn, mirrored for right-to-left text.
double frostDisclosureTurns(BuildContext context) => Directionality.of(context) == TextDirection.rtl ? -.25 : .25;

/// The revealed content of a disclosure: it springs open and closed from the
/// top, and while collapsed it takes no focus, semantics or tickers. Nested
/// glass finishes closing before the content is clipped away.
class FrostDisclosureBody extends StatefulWidget {
  const FrostDisclosureBody({required this.expanded, required this.gap, required this.child, super.key});
  final bool expanded;

  /// Space between the toggle and the content, collapsing with it.
  final double gap;
  final Widget child;
  @override
  State<FrostDisclosureBody> createState() => _DisclosureBodyState();
}

class _DisclosureBodyState extends State<FrostDisclosureBody> {
  final _glass = FrostRevealHandle();
  late bool _visualExpanded = widget.expanded;

  @override
  void didUpdateWidget(FrostDisclosureBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expanded == oldWidget.expanded) return;
    if (widget.expanded) {
      _glass.cancelClose();
      _visualExpanded = true;
    } else if (_glass.hasNestedGlass && _glass.nestedProgress > 0) {
      _glass.prepareClose().then((ready) {
        if (ready && mounted && !widget.expanded) setState(() => _visualExpanded = false);
      });
    } else {
      _visualExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final expanded = widget.expanded;
    // Only the height reveals. Rows bleed past the content line into the keyline's
    // margin, so the clip reaches as far sideways as that margin does.
    final keyline = FrostKeyline.maybeOf(context);
    final bleeds = keyline != null && !keyline.insideContainer;
    return FrostSpringBuilder(
      value: _visualExpanded ? 1 : 0,
      spring: FrostMotion.standard,
      child: ExcludeFocus(
        excluding: !expanded,
        child: ExcludeSemantics(
          excluding: !expanded,
          child: TickerMode(
            enabled: expanded,
            child: FrostMotionSize(
              duration: FrostMotion.duration(context, FrostMotion.layoutFade),
              alignment: AlignmentDirectional.topStart,
              child: Padding(
                padding: EdgeInsets.only(top: widget.gap),
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
      builder: (context, progress, child) => ClipRect(
        clipper: _RevealClipper(
          leading: bleeds ? keyline.leadingRoom : 0,
          trailing: bleeds ? keyline.trailingRoom : 0,
          textDirection: Directionality.of(context),
        ),
        child: Align(
          alignment: AlignmentDirectional.topStart,
          heightFactor: progress.clamp(0.0, 1.0),
          child: Offstage(
            offstage: progress <= 0,
            child: FrostMaterialReveal(opacity: progress.clamp(0.0, 1.0), handle: _glass, contentOnly: true, child: child!),
          ),
        ),
      ),
    );
  }
}

/// Clips the reveal to the body's height and, sideways, to the margin a
/// bleeding row may paint into.
class _RevealClipper extends CustomClipper<Rect> {
  const _RevealClipper({required this.leading, required this.trailing, required this.textDirection});
  final double leading, trailing;
  final TextDirection textDirection;

  @override
  Rect getClip(Size size) {
    final rtl = textDirection == TextDirection.rtl;
    return Rect.fromLTRB(rtl ? -trailing : -leading, 0, size.width + (rtl ? leading : trailing), size.height);
  }

  @override
  bool shouldReclip(_RevealClipper oldClipper) => leading != oldClipper.leading || trailing != oldClipper.trailing || textDirection != oldClipper.textDirection;
}
