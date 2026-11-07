import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../foundation/_layout_scope.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../motion/_material_reveal.dart';
import '../motion/page_transition.dart';
import '_destination_root.dart';

/// A pushed detail page with the shared page transition. It is a plain
/// [Page], so any router that takes pages (go_router's pageBuilder,
/// Navigator 2.0) can use it. Media Hero flights run independently of the
/// ordinary page motion.
///
/// Prefer this page for content containing Frost glass surfaces. Nested blur
/// starts after the page transition has completed. Before dismissal it fades out
/// over 140 ms while content stays opaque, then the usual route exit runs. Predictive back
/// keeps its interactive pose and cancellation behavior. Plain or solid pages
/// keep their original exit duration.
class FrostDetailPage<T> extends Page<T> {
  const FrostDetailPage({required this.child, this.opaque = true, super.key, super.name, super.arguments, super.restorationId})
    : _media = false,
      _secondaryDestination = false;

  /// Stationary Hero-compatible content timing, with native route progress.
  /// Android gestures drive route progress directly and commit through normal
  /// Navigator.pop, so the in-flight Hero never restarts at full size.
  const FrostDetailPage.media({required this.child, this.opaque = true, super.key, super.name, super.arguments, super.restorationId})
    : _media = true,
      _secondaryDestination = false;

  /// The root page of a [FrostShellSecondary] destination. In the sidebar
  /// layout, where the secondary destinations sit beside the primary ones,
  /// selecting one is a switch: this page replaces the page with no motion, as
  /// a primary destination does, and covers it from its first frame. With the
  /// bottom bar, where the page is opened from another one, it is pushed and
  /// goes back as an ordinary detail page. Pages pushed above it move as usual.
  const FrostDetailPage.secondaryDestination({required this.child, super.key, super.name, super.arguments, super.restorationId})
    : _media = false,
      opaque = true,
      _secondaryDestination = true;

  final bool _media, _secondaryDestination;

  final Widget child;

  /// Whether this page fully obscures the route below it after its transition.
  /// Set false for media viewers whose background fades during drag dismissal.
  /// This retains the owned glass exit sequence and predictive back behavior.
  final bool opaque;

  @override
  Route<T> createRoute(BuildContext context) => _FrostDetailRoute<T>(page: this, context: context);
}

class _FrostDetailRoute<T> extends PageRoute<T> {
  _FrostDetailRoute({required FrostDetailPage<T> page, required BuildContext context})
    : _switches = _switchesIn(page, context),
      _duration = _durationFor(page, context, forward: true),
      _reverseDuration = _durationFor(page, context, forward: false),
      super(settings: page);

  /// A secondary destination's root in the sidebar layout; read when the
  /// page is pushed.
  static bool _switchesIn(FrostDetailPage<Object?> page, BuildContext context) => page._secondaryDestination && FrostAdaptiveLayoutData.horizontalOf(context);

  static Duration _durationFor(FrostDetailPage<Object?> page, BuildContext context, {required bool forward}) {
    if (_switchesIn(page, context)) return Duration.zero;
    if (!page._media && FrostDensity.of(context).usesPointer && MediaQuery.disableAnimationsOf(context)) return const Duration(milliseconds: 100);
    final native = _nativeBuilder(page, context);
    return FrostMotion.duration(context, forward ? native?.transitionDuration ?? FrostMotion.page : native?.reverseTransitionDuration ?? FrostMotion.exit);
  }

  static PageTransitionsBuilder? _nativeBuilder(FrostDetailPage<Object?> page, BuildContext context) {
    final platform = Theme.of(context).platform;
    // Cupertino owns its edge recognizer, including media Hero progress.
    if (platform == TargetPlatform.iOS) return const CupertinoPageTransitionsBuilder();
    if (!page._media && platform == TargetPlatform.android) {
      return FrostScope.configOf(context).predictiveBack ? const PredictiveBackPageTransitionsBuilder() : const FadeForwardsPageTransitionsBuilder();
    }
    return null;
  }

  final bool _switches;
  final _glass = FrostRevealHandle();
  final Duration _duration;
  final Duration _reverseDuration;
  FrostDetailPage<T> get _page => settings as FrostDetailPage<T>;
  @override
  Duration get transitionDuration => _duration;
  @override
  Duration get reverseTransitionDuration => _reverseDuration + (_glass.hasNestedGlass && _glass.nestedProgress > 0 ? frostNestedGlassDuration : Duration.zero);

  @override
  Simulation? createSimulation({required bool forward}) =>
      (forward || navigator?.userGestureInProgress == true) ? null : frostGlassExitSimulation(_glass, controller!.value, _reverseDuration);

  @override
  bool get opaque => _page.opaque;
  @override
  bool get maintainState => true;
  // A transparent viewer reveals the live route below; fading that route out
  // through secondaryAnimation would leave only the ambient background.
  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) => opaque && super.canTransitionFrom(previousRoute);
  @override
  Color? get barrierColor => null;
  @override
  String? get barrierLabel => null;
  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      _page._secondaryDestination ? FrostDestinationRoot(route: this, child: _page.child) : _page.child;
  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) => frostOwnedPageTransition(
    context,
    // A switch has no entrance; pages pushed above still move it out.
    _switches ? kAlwaysCompleteAnimation : animation,
    secondaryAnimation,
    child,
    revealHandle: _glass,
    route: this,
    media: _page._media && Theme.of(context).platform != TargetPlatform.iOS,
  );
}
