import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/_page_scroll_behavior.dart';
import '../layout/content_viewport.dart' show FrostSliverFillPage;
import '../primitives/icon.dart';
import '../primitives/text.dart';
import '_pull_refresh.dart';
import 'refresh_dots.dart';

const frostRefreshPhysics = FrostRefreshPhysics();

/// A refresh viewport's scrollbar over the surrounding drag devices, so an app
/// that wants mouse drag configures it in its own [ScrollBehavior].
Widget frostRefreshScrollConfiguration(BuildContext context, {required Widget child, bool scrollbars = false}) => ScrollConfiguration(
  behavior: _DataRefreshScrollBehavior(scrollbars: scrollbars, parent: ScrollConfiguration.of(context)),
  child: child,
);

class _DataRefreshScrollBehavior extends ScrollBehavior {
  const _DataRefreshScrollBehavior({required this.parent, this.scrollbars = false});
  final ScrollBehavior parent;
  final bool scrollbars;

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) =>
      scrollbars ? frostPageScrollbar(context, parent.buildScrollbar(context, child, details)) : child;

  @override
  TargetPlatform getPlatform(BuildContext context) => parent.getPlatform(context);
  @override
  Set<PointerDeviceKind> get dragDevices => parent.dragDevices;
  @override
  Set<LogicalKeyboardKey> get pointerAxisModifiers => parent.pointerAxisModifiers;
  @override
  MultitouchDragStrategy getMultitouchDragStrategy(BuildContext context) => parent.getMultitouchDragStrategy(context);
  @override
  GestureVelocityTrackerBuilder velocityTrackerBuilder(BuildContext context) => parent.velocityTrackerBuilder(context);
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) => parent.getScrollPhysics(context);
  @override
  ScrollViewKeyboardDismissBehavior getKeyboardDismissBehavior(BuildContext context) => parent.getKeyboardDismissBehavior(context);
  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) => parent.buildOverscrollIndicator(context, child, details);

  @override
  bool shouldNotify(_DataRefreshScrollBehavior oldDelegate) => scrollbars != oldDelegate.scrollbars || parent != oldDelegate.parent;
}

class FrostRefreshSliverHeader extends StatelessWidget {
  const FrostRefreshSliverHeader({super.key});

  static const refreshOffset = FrostPullRefresh.holdExtent;
  static const maxDragOffset = FrostPullRefresh.maxExtent;

  @override
  Widget build(BuildContext context) {
    final state = FrostPullRefresh.maybeOf(context);
    if (state == null) return const _EmptyHeader();
    return ValueListenableBuilder<FrostPullRefreshValue>(
      valueListenable: state.value,
      builder: (context, value, _) {
        if (value.phase == FrostPullRefreshPhase.idle && value.extent <= 0) return const _EmptyHeader();
        return SliverToBoxAdapter(
          child: _DataPullRefreshHeaderBody(value: value, onRetry: state.refresh),
        );
      },
    );
  }
}

class _EmptyHeader extends StatelessWidget {
  const _EmptyHeader();

  @override
  Widget build(BuildContext context) => const SliverToBoxAdapter(child: SizedBox.shrink());
}

class _DataPullRefreshHeaderBody extends StatelessWidget {
  const _DataPullRefreshHeaderBody({required this.value, required this.onRetry});

  final FrostPullRefreshValue value;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final translations = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    final phase = value.phase;
    final height = value.extent.clamp(0.0, FrostRefreshSliverHeader.maxDragOffset);
    final statusText = switch (phase) {
      FrostPullRefreshPhase.armed => translations.releaseToRefresh,
      FrostPullRefreshPhase.refreshing => translations.refreshing,
      FrostPullRefreshPhase.done => translations.refreshComplete,
      FrostPullRefreshPhase.failed => translations.refreshFailed,
      FrostPullRefreshPhase.idle || FrostPullRefreshPhase.drag => translations.pullToRefresh,
    };

    final indicator = switch (phase) {
      FrostPullRefreshPhase.refreshing => const ExcludeSemantics(child: FrostRefreshDots()),
      FrostPullRefreshPhase.done => FrostIcon(icons.check, size: 22, color: FrostThemeTokens.of(context).textPrimary),
      FrostPullRefreshPhase.failed => FrostIcon(icons.error, size: 22, color: FrostThemeTokens.of(context).negativeInk),
      FrostPullRefreshPhase.idle || FrostPullRefreshPhase.drag || FrostPullRefreshPhase.armed => AnimatedRotation(
        // Keep the same arrow mounted for drag <-> armed so interrupted
        // transitions continue from the currently painted angle.
        turns: phase == FrostPullRefreshPhase.armed ? .5 : 0,
        duration: FrostMotion.duration(context, FrostMotion.hover),
        curve: FrostMotion.hoverCurve,
        child: FrostIcon(icons.arrowDown, size: 22, color: FrostThemeTokens.of(context).textPrimary),
      ),
    };

    final child = SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          height: FrostRefreshSliverHeader.refreshOffset,
          child: Center(
            child: _InlineRefreshStatus(icon: indicator, label: statusText),
          ),
        ),
      ),
    );

    if (phase == FrostPullRefreshPhase.failed) {
      return GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => unawaited(onRetry()), child: child);
    }

    return child;
  }
}

class _InlineRefreshStatus extends StatelessWidget {
  const _InlineRefreshStatus({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: 22, child: Center(child: icon)),
        const SizedBox(width: FrostGap.related),
        Flexible(
          child: FrostText(label, role: FrostTextRole.footnote, tone: FrostTextTone.secondary),
        ),
      ],
    );
  }
}

class FrostLoadingScrollView extends StatelessWidget {
  const FrostLoadingScrollView({
    required this.slivers,
    this.controller,
    this.physics,
    this.primary,
    this.shrinkWrap = false,
    this.cacheExtent,
    this.preloadExtent = 480,
    this.clipBehavior = Clip.hardEdge,
    super.key,
  });

  final List<Widget> slivers;
  final ScrollController? controller;
  final ScrollPhysics? physics;
  final bool? primary;
  final bool shrinkWrap;
  final double? cacheExtent;
  final double preloadExtent;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    return frostRefreshScrollConfiguration(
      context,
      scrollbars: true,
      child: CustomScrollView(
        controller: controller,
        physics: physics ?? frostRefreshPhysics,
        primary: primary,
        shrinkWrap: shrinkWrap,
        scrollCacheExtent: ScrollCacheExtent.pixels(math.max(cacheExtent ?? 0, preloadExtent)),
        clipBehavior: clipBehavior,
        // Content scrolls beneath a floating bottom bar (mobile navigation),
        // but the last items and the load-more footer must end above it.
        slivers: [
          ...slivers,
          SliverToBoxAdapter(child: SizedBox(height: MediaQuery.paddingOf(context).bottom)),
        ],
      ),
    );
  }
}

class FrostSliverFillBody extends StatelessWidget {
  const FrostSliverFillBody({required this.child, this.physics, this.sliverHeader, this.leadingSlivers = const [], super.key});

  final Widget child;
  final ScrollPhysics? physics;
  final Widget? sliverHeader;
  final List<Widget> leadingSlivers;

  @override
  Widget build(BuildContext context) {
    return FrostLoadingScrollView(
      physics: physics,
      slivers: [...leadingSlivers, ?sliverHeader, FrostSliverFillPage(child: child)],
    );
  }
}
