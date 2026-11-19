part of 'shell.dart';

/// The page area beside the sidebar. It runs to the window's end and bottom
/// edges, so only the corner that lies inside the window, between the title
/// row and the sidebar, is rounded; the window rounds its own outer corners.
class _ContentSheet extends StatelessWidget {
  const _ContentSheet({required this.enabled, required this.child});
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    const corner = Radius.circular(FrostRadius.lg);
    final radius = Directionality.of(context) == TextDirection.rtl
        ? const BorderRadius.only(topRight: corner)
        : const BorderRadius.only(topLeft: corner);
    return FrostPageOutline(
      radius: radius,
      scrollbarChannel: FrostGap.related,
      child: FrostSurface(role: FrostSurfaceRole.panel, borderRadius: radius, child: child),
    );
  }
}
