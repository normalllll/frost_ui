import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show FadeForwardsPageTransitionsBuilder, PredictiveBackPageTransitionsBuilder, Theme;

import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../primitives/_page_outline.dart';
import '../surface/ambient_backdrop.dart';
import '_material_reveal.dart';

/// Shared route transition. Media/Hero geometry stays stationary; ordinary
/// pointer pages use DrillIn. Glass keeps its existing close sequence.
Widget frostPageTransition(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
    frostOwnedPageTransition(context, animation, secondaryAnimation, child);

Widget frostOwnedPageTransition(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child, {
  FrostRevealHandle? revealHandle,
  PageRoute<Object?>? route,
  bool media = true,
}) {
  final pointer = FrostDensity.of(context).usesPointer;
  if (pointer && !media) {
    return _PointerPageTransition(
      animation: route?.isFirst == true ? kAlwaysCompleteAnimation : animation,
      secondary: secondaryAnimation,
      revealHandle: revealHandle,
      child: child,
    );
  }
  if (MediaQuery.disableAnimationsOf(context)) return child;
  final platform = Theme.of(context).platform;
  if (!media && route != null && (platform == TargetPlatform.android || platform == TargetPlatform.iOS)) {
    final predictive = FrostScope.configOf(context).predictiveBack;
    final builder = platform == TargetPlatform.iOS
        ? const CupertinoPageTransitionsBuilder()
        : predictive
        ? const PredictiveBackPageTransitionsBuilder()
        : const FadeForwardsPageTransitionsBuilder();
    final outline = FrostPageOutline.maybeOf(context);
    final panel = outline != null && outline.radius != BorderRadius.zero;
    // Keep the wrapper mounted across a compact/wide resize so page state,
    // scroll positions and focus survive when the panel outline changes.
    final page = ClipPath(
      clipBehavior: panel ? Clip.antiAlias : Clip.none,
      clipper: panel
          ? FrostPageViewportClip(radius: outline.radius, continuous: FrostScope.configOf(context).continuousCorners, channel: outline.scrollbarChannel)
          : null,
      child: _MovingBackdrop(animation: animation, opaque: route.opaque, child: child),
    );
    final media = MediaQuery.of(context);
    // A moving panel owns its outline, including the scrollbar channel and
    // continuous corners. Android's predictive transition otherwise applies
    // physical display corners to this inset viewport a second time. Scope the
    // rectangular native clip to the transition; page content keeps real device
    // metrics, and fullscreen routes keep Flutter's display-corner behavior.
    final native = platform == TargetPlatform.android
        ? MediaQuery(
            data: panel ? media.applyDisplayCornerRadii(BorderRadius.zero) : media,
            child: Builder(
              builder: (context) => builder.buildTransitions(route, context, animation, secondaryAnimation, MediaQuery(data: media, child: page)),
            ),
          )
        : builder.buildTransitions(route, context, animation, secondaryAnimation, page);
    final guarded = AnimatedBuilder(
      animation: animation,
      child: native,
      builder: (context, child) =>
          FrostMaterialReveal(opacity: 1, contentOnly: true, deferNestedBlur: animation.value < 1, handle: revealHandle, child: child!),
    );
    return guarded;
  }
  return _BackGestureBridge(
    child: _PageTransition(animation: animation, revealHandle: revealHandle, child: child),
  );
}

class FrostPageTransitionsBuilder extends PageTransitionsBuilder {
  const FrostPageTransitionsBuilder({this.reducedMotion = false});
  final bool reducedMotion;
  @override
  Duration get transitionDuration => reducedMotion ? const Duration(milliseconds: 100) : FrostMotion.page;
  @override
  Duration get reverseTransitionDuration => reducedMotion ? const Duration(milliseconds: 100) : FrostMotion.exit;
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) =>
      (reducedMotion || route.isFirst) && !FrostDensity.of(context).usesPointer
      ? child
      : frostOwnedPageTransition(context, animation, secondaryAnimation, child, route: route, media: false);
}

// Duration getters have no BuildContext. The theme resolves input capability
// once, keeping the native touch reduced-motion timing out of the public API.
PageTransitionsBuilder frostPageTransitionsBuilder({required bool reducedMotion, required bool pointer}) =>
    reducedMotion && !pointer ? const _ReducedTouchPageTransitions() : FrostPageTransitionsBuilder(reducedMotion: reducedMotion);

class _ReducedTouchPageTransitions extends FrostPageTransitionsBuilder {
  const _ReducedTouchPageTransitions() : super(reducedMotion: true);
  @override
  Duration get transitionDuration => Duration.zero;
  @override
  Duration get reverseTransitionDuration => Duration.zero;
}

/// Ordinary pointer routes share entering and outgoing motion. Media routes
/// retain their stationary Hero geometry and touch routes use native builders.
class _PointerPageTransition extends StatelessWidget {
  const _PointerPageTransition({required this.animation, required this.secondary, required this.child, this.revealHandle});
  final Animation<double> animation, secondary;
  final Widget child;
  final FrostRevealHandle? revealHandle;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([animation, secondary]),
    child: RepaintBoundary(child: child),
    builder: (context, child) {
      final reduced = MediaQuery.disableAnimationsOf(context);
      final entering = Curves.easeOutCubic.transform(animation.value.clamp(0.0, 1.0));
      final covered = secondary.value.clamp(0.0, 1.0);
      // Clear the outgoing details early, before the entering page is legible.
      final leaving = reduced ? covered : const Interval(0, .5, curve: Curves.easeOutCubic).transform(covered);
      final opacity = entering * (1 - leaving);
      final scale = reduced ? 1.0 : (.96 + .04 * entering) * (1 + .02 * Curves.easeOutCubic.transform(covered));
      final moving = animation.status != AnimationStatus.completed || secondary.status != AnimationStatus.dismissed;
      // The backdrop fades by its own alpha, outside the content's opacity
      // layer, so that layer covers the page's content, not the whole window.
      return Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(child: moving && ModalRoute.of(context)?.opaque != false ? FrostFadingAmbientBackdrop(opacity: opacity) : const SizedBox.shrink()),
          FrostMaterialReveal(
            contentOnly: true,
            handle: revealHandle,
            opacity: opacity,
            deferNestedBlur: moving,
            child: Transform.scale(scale: scale, child: child!),
          ),
        ],
      );
    },
  );
}

// A Frost page paints over the window backdrop, which the opaque route below
// covers until this route settles. While moving, the page carries the
// backdrop itself, as the pointer transitions do, so the route below never
// shows through it and nothing changes in the frame it settles.
class _MovingBackdrop extends StatelessWidget {
  const _MovingBackdrop({required this.animation, required this.opaque, required this.child});
  final Animation<double> animation;
  final bool opaque;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: animation,
    child: child,
    builder: (context, child) => Stack(
      fit: StackFit.passthrough,
      children: [
        Positioned.fill(child: opaque && animation.status != AnimationStatus.completed ? const FrostAmbientBackdrop() : const SizedBox.shrink()),
        child!,
      ],
    ),
  );
}

const _previousDimAlpha = .2;

// Route progress at which an opaque media page's content takes over from its
// backdrop.
const _dipSplit = .5;

// Content and scrim use raw route progress so a held gesture, its commit and
// its cancellation all paint the same opacity. Hero retains its geometric curve.
// The dim peaks midway and is clear at both ends, because a settled page paints none.
//
// An opaque page dips through its backdrop instead of fading its content over
// the route below: the backdrop fades in over that route for the first half,
// then the content shows at full opacity under a veil of the same backdrop
// that fades out. Both are single draws with an alpha, so a page whose content
// fills the window composites no window-sized offscreen pass. Over a system
// backdrop without artwork, where the backdrop hides nothing, and on a
// see-through page, the content fades over the route below as a whole.
class _PageTransition extends StatelessWidget {
  const _PageTransition({required this.animation, required this.child, this.revealHandle});
  final Animation<double> animation;
  final FrostRevealHandle? revealHandle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    return AnimatedBuilder(
      animation: animation,
      child: RepaintBoundary(child: child),
      builder: (context, child) {
        final moving = animation.status != AnimationStatus.completed;
        final opacity = animation.value.clamp(0.0, 1.0);
        final carried = moving && route?.opaque != false;
        final dip = carried && frostAmbientBackdropCovers(context);
        final emerged = dip ? ((opacity - _dipSplit) / (1 - _dipSplit)).clamp(0.0, 1.0) : 1.0;
        // The children keep their places whichever way the page moves, so the
        // content keeps its state.
        return Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: IgnorePointer(
                child: ColoredBox(color: FrostThemeTokens.of(context).onMediaScrim.withValues(alpha: _previousDimAlpha * 4 * opacity * (1 - opacity))),
              ),
            ),
            Positioned.fill(
              child: !carried ? const SizedBox.shrink() : FrostFadingAmbientBackdrop(opacity: dip ? (opacity / _dipSplit).clamp(0.0, 1.0) : opacity),
            ),
            FrostMaterialReveal(
              contentOnly: true,
              handle: revealHandle,
              opacity: dip ? (opacity < _dipSplit ? 0 : 1) : opacity,
              deferNestedBlur: dip && opacity < 1,
              child: child!,
            ),
            Positioned.fill(
              child: dip && emerged < 1 && opacity >= _dipSplit
                  ? IgnorePointer(child: FrostFadingAmbientBackdrop(opacity: 1 - emerged))
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }
}

// Only a binding for routes whose visual transition is the stationary media
// fade. Native ordinary transitions own their own binding. There are no release poses or substitute commit motions.
class _BackGestureBridge extends StatefulWidget {
  const _BackGestureBridge({required this.child});
  final Widget child;
  @override
  State<_BackGestureBridge> createState() => _BackGestureBridgeState();
}

class _BackGestureBridgeState extends State<_BackGestureBridge> with WidgetsBindingObserver {
  ModalRoute<Object?>? _route;
  VoidCallback? _finishGesture;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _route = ModalRoute.of(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _finishGesture?.call();
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent event) {
    final route = _route;
    if (Theme.of(context).platform != TargetPlatform.android ||
        event.isButtonEvent ||
        route == null ||
        !mounted ||
        !route.isCurrent ||
        !route.popGestureEnabled) {
      return false;
    }
    final root = Navigator.of(context, rootNavigator: true);
    if (route.navigator != root && root.canPop()) return false;
    if (!FrostScope.configOf(context).predictiveBack) return false;
    route.handleStartBackGesture(progress: 1 - event.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent event) {
    _route?.handleUpdateBackGestureProgress(progress: 1 - event.progress);
  }

  @override
  void handleCancelBackGesture() => _route?.handleCancelBackGesture();
  @override
  void handleCommitBackGesture() {
    final route = _route;
    final navigator = route?.navigator;
    if (route == null || navigator == null) return;
    // TransitionRoute.handleCommitBackGesture reverses from 1 for the
    // official Android visual preset. A media Hero must keep its current route
    // progress instead. Ordinary Navigator.pop already reverses continuously.
    // Keep the gesture alive until that reverse ends so HeroController.didPop
    // continues the existing flight rather than creating a second one.
    navigator.pop();
    final animation = route.animation!;
    if (!animation.isAnimating) {
      if (navigator.mounted && navigator.userGestureInProgress) navigator.didStopUserGesture();
      return;
    }
    var finished = false;
    late AnimationStatusListener status;
    void finish() {
      if (finished) return;
      finished = true;
      animation.removeStatusListener(status);
      _finishGesture = null;
      if (navigator.mounted && navigator.userGestureInProgress) navigator.didStopUserGesture();
    }

    status = (value) {
      if (value == AnimationStatus.dismissed || value == AnimationStatus.completed) finish();
    };
    _finishGesture = finish;
    animation.addStatusListener(status);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
