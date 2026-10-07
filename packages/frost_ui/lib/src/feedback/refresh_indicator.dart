import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/layout/content_viewport.dart';
import 'package:frost_ui/src/feedback/skeleton.dart';
import 'package:frost_ui/src/feedback/refresh_dots.dart';
import 'package:frost_ui/src/layout/waterfall_grid.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:frost_ui/src/feedback/compact_message.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/feedback/list_source.dart';
import 'package:loading_more_list/loading_more_list.dart';
import 'package:pull_to_refresh_notification/pull_to_refresh_notification.dart';

import 'package:frost_ui/src/feedback/error_content.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:frost_ui/src/foundation/scope.dart';

typedef FrostLoadingItemBuilder<T> = Widget Function(BuildContext context, T item, int index);

const frostRefreshPhysics = AlwaysScrollableClampingScrollPhysics();
const frostRefreshScrollBehavior = _DataRefreshScrollBehavior();

class _DataRefreshScrollBehavior extends MaterialScrollBehavior {
  const _DataRefreshScrollBehavior();

  @override
  Widget buildScrollbar(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
    PointerDeviceKind.unknown,
  };
}

class FrostRefreshSliverHeader extends StatelessWidget {
  const FrostRefreshSliverHeader({super.key});

  static const refreshOffset = 56.0;
  static const reachToRefreshOffset = 84.0;
  static const maxDragOffset = 120.0;

  @override
  Widget build(BuildContext context) {
    return PullToRefreshContainer((info) {
      final mode = info?.mode;
      final offset = info?.dragOffset ?? 0.0;

      if ((mode == null || mode == PullToRefreshIndicatorMode.canceled) && offset <= 0) {
        return const SliverToBoxAdapter(child: SizedBox.shrink());
      }

      return SliverToBoxAdapter(child: _DataPullRefreshHeaderBody(info: info));
    });
  }
}

class _DataPullRefreshHeaderBody extends StatelessWidget {
  const _DataPullRefreshHeaderBody({required this.info});

  final PullToRefreshScrollNotificationInfo? info;

  @override
  Widget build(BuildContext context) {
    final translations = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    final mode = info?.mode;
    final offset = info?.dragOffset ?? 0.0;
    final height = offset.clamp(0.0, FrostRefreshSliverHeader.maxDragOffset);
    final statusText = switch (mode) {
      PullToRefreshIndicatorMode.armed => translations.releaseToRefresh,
      PullToRefreshIndicatorMode.snap || PullToRefreshIndicatorMode.refresh => translations.refreshing,
      PullToRefreshIndicatorMode.done => translations.refreshComplete,
      PullToRefreshIndicatorMode.error => translations.refreshFailed,
      _ => translations.pullToRefresh,
    };

    final colorScheme = Theme.of(context).colorScheme;
    final indicator = switch (mode) {
      PullToRefreshIndicatorMode.snap || PullToRefreshIndicatorMode.refresh => const FrostRefreshDots(),
      PullToRefreshIndicatorMode.done => FrostIcon(icons.success, size: 22, color: FrostThemeTokens.of(context).textPrimary),
      PullToRefreshIndicatorMode.error => FrostIcon(icons.error, size: 22, color: colorScheme.error),
      _ => const FrostRefreshDots(),
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

    if (mode == PullToRefreshIndicatorMode.error && info != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => info!.pullToRefreshNotificationState.show(notificationDragOffset: FrostRefreshSliverHeader.reachToRefreshOffset),
        child: child,
      );
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
    final textStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(dimension: 22, child: Center(child: icon)),
        const SizedBox(width: 8),
        Text(label, style: textStyle),
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
    return ScrollConfiguration(
      behavior: frostRefreshScrollBehavior,
      child: LoadingMoreCustomScrollView(
        controller: controller,
        physics: physics ?? frostRefreshPhysics,
        primary: primary,
        shrinkWrap: shrinkWrap,
        cacheExtent: cacheExtent,
        preloadExtent: preloadExtent,
        showGlowLeading: false,
        getConfigFromSliverContext: true,
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

class FrostSliverDataList<T> extends StatelessWidget {
  const FrostSliverDataList({
    required this.source,
    required this.itemBuilder,
    required this.firstLoadSkeleton,
    this.padding,
    this.itemExtent,
    this.autoLoadMore = true,
    super.key,
  });

  /// See [FrostLoadingMoreIndicator.firstLoadSkeleton].
  final Widget firstLoadSkeleton;

  final FrostListSource<T> source;
  final FrostLoadingItemBuilder<T> itemBuilder;
  final EdgeInsetsGeometry? padding;
  final double? itemExtent;
  final bool autoLoadMore;

  @override
  Widget build(BuildContext context) {
    return LoadingMoreSliverList<T>(
      SliverListConfig<T>(
        sourceList: source,
        itemBuilder: itemBuilder,
        indicatorBuilder: _indicatorBuilder(source, firstLoadSkeleton),
        padding: padding,
        itemExtent: itemExtent,
        autoRefresh: false,
        autoLoadMore: autoLoadMore,
      ),
    );
  }
}

class FrostSliverDataWaterfallGrid<T> extends StatelessWidget {
  const FrostSliverDataWaterfallGrid({
    required this.source,
    required this.itemBuilder,
    required this.firstLoadSkeleton,
    this.preferredTileWidth = FrostMetrics.gridExtent,
    this.crossAxisSpacing = FrostMetrics.gridGap,
    this.mainAxisSpacing = FrostMetrics.gridGap,
    this.padding,
    this.autoLoadMore = true,
    super.key,
  });

  final FrostListSource<T> source;
  final FrostLoadingItemBuilder<T> itemBuilder;

  /// See [FrostLoadingMoreIndicator.firstLoadSkeleton].
  final Widget firstLoadSkeleton;
  final double preferredTileWidth;
  final double crossAxisSpacing;
  final double mainAxisSpacing;

  /// Defaults to [frostBrowseGridPadding] for the grid's own width.
  final EdgeInsetsGeometry? padding;
  final bool autoLoadMore;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final padding = this.padding ?? frostBrowseGridPadding(constraints.crossAxisExtent);
        final availableWidth = FrostContentColumnBudget.columnWidth(
          context,
          constraints.crossAxisExtent - padding.resolve(Directionality.of(context)).horizontal,
        );
        final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final count = frostWaterfallColumnCount(width: availableWidth, preferredTileWidth: preferredTileWidth, gap: crossAxisSpacing, textScale: textScale);
        return LoadingMoreSliverList<T>(
          SliverListConfig<T>(
            sourceList: source,
            itemBuilder: itemBuilder,
            indicatorBuilder: _indicatorBuilder(source, firstLoadSkeleton),
            padding: padding,
            autoRefresh: false,
            autoLoadMore: autoLoadMore,
            extendedListDelegate: SliverWaterfallFlowDelegateWithFixedCrossAxisCount(
              crossAxisCount: count,
              crossAxisSpacing: crossAxisSpacing,
              mainAxisSpacing: mainAxisSpacing,
            ),
          ),
        );
      },
    );
  }
}

/// A paged grid of equal cards in fixed rows (not a waterfall): as many
/// columns as fit at [minTileWidth], a single column on phones and narrow
/// windows, and every tile [tileHeight] tall for the resolved tile width so
/// the cards in a row line up.
class FrostSliverDataGrid<T> extends StatelessWidget {
  const FrostSliverDataGrid({
    required this.source,
    required this.itemBuilder,
    required this.firstLoadSkeleton,
    required this.minTileWidth,
    required this.tileHeight,
    this.spacing = FrostMetrics.gridGap,
    super.key,
  });

  final FrostListSource<T> source;
  final FrostLoadingItemBuilder<T> itemBuilder;

  /// See [FrostLoadingMoreIndicator.firstLoadSkeleton].
  final Widget firstLoadSkeleton;
  final double minTileWidth;
  final double Function(BuildContext context, double tileWidth) tileHeight;
  final double spacing;

  /// Padding, column count and tile width for a grid [crossAxisExtent] wide;
  /// loading skeletons use the same numbers so they match the loaded grid.
  static ({EdgeInsets padding, int columns, double tileWidth}) geometry(
    BuildContext context,
    double crossAxisExtent, {
    required double minTileWidth,
    double spacing = FrostMetrics.gridGap,
  }) {
    final padding = frostBrowseGridPadding(crossAxisExtent);
    final width = crossAxisExtent - padding.horizontal;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;
    // The column count follows the sidebar budget so it does not change
    // while the sidebar animates; tiles still fill the actual width.
    final columns = frostFittedColumnCount(
      width: FrostContentColumnBudget.columnWidth(context, width),
      minTileWidth: minTileWidth,
      gap: spacing,
      textScale: textScale,
    );
    return (padding: padding, columns: columns, tileWidth: (width - spacing * (columns - 1)) / columns);
  }

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final layout = geometry(context, constraints.crossAxisExtent, minTileWidth: minTileWidth, spacing: spacing);
        return LoadingMoreSliverList<T>(
          SliverListConfig<T>(
            sourceList: source,
            itemBuilder: itemBuilder,
            indicatorBuilder: _indicatorBuilder(source, firstLoadSkeleton),
            padding: layout.padding,
            autoRefresh: false,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: layout.columns,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing,
              mainAxisExtent: tileHeight(context, layout.tileWidth),
            ),
          ),
        );
      },
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
      slivers: [
        ...leadingSlivers,
        ?sliverHeader,
        SliverFillRemaining(hasScrollBody: false, child: child),
      ],
    );
  }
}

LoadingMoreIndicatorBuilder _indicatorBuilder<T>(FrostListSource<T> source, Widget firstLoadSkeleton) {
  return (context, status) {
    return FrostLoadingMoreIndicator(status: status, source: source, firstLoadSkeleton: firstLoadSkeleton);
  };
}

class FrostLoadingMoreIndicator<T> extends StatelessWidget {
  const FrostLoadingMoreIndicator({required this.status, required this.source, required this.firstLoadSkeleton, super.key});

  final IndicatorStatus status;
  final FrostListSource<T> source;

  /// Shown during the first load. It must match the loaded content's outline
  /// (tile size, shape and spacing), so it is supplied by the list's owner.
  final Widget firstLoadSkeleton;

  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    return switch (status) {
      IndicatorStatus.none => const SizedBox.shrink(),
      IndicatorStatus.loadingMoreBusying => _FooterIndicator(icon: const FrostSkeletonBlock(width: 18, height: 18), label: labels.loading),
      // A failed next page keeps what is loaded and offers an explicit retry
      // with the technical cause, instead of a bare tappable status line.
      IndicatorStatus.error => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: switch (source.lastError) {
              final error? => FrostCompactMessage.error(error: error, onAction: source.errorRefresh),
              null => FrostCompactMessage(icon: icons.error, message: labels.loadFailed, actionLabel: labels.retry, onAction: source.errorRefresh),
            },
          ),
        ),
      ),
      IndicatorStatus.noMoreLoad => _FooterIndicator(
        icon: FrostIcon(icons.check, size: 18, color: Theme.of(context).colorScheme.onSurfaceVariant),
        label: labels.noMoreItems,
      ),
      IndicatorStatus.fullScreenBusying => SliverToBoxAdapter(child: firstLoadSkeleton),
      IndicatorStatus.fullScreenError => SliverFillRemaining(
        hasScrollBody: false,
        child: switch (source.lastError) {
          final error? => FrostErrorContent.fromError(error: error, onRetry: () => source.refresh(true)),
          null => FrostErrorContent(message: labels.loadFailed, onRetry: () => source.refresh(true)),
        },
      ),
      IndicatorStatus.empty => SliverFillRemaining(
        hasScrollBody: false,
        child: FrostEmptyContent(icon: icons.empty, title: labels.noMoreItems),
      ),
    };
  }
}

class _FooterIndicator extends StatelessWidget {
  const _FooterIndicator({required this.icon, required this.label});

  final Widget icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 56),
      child: Center(
        child: _InlineRefreshStatus(icon: icon, label: label),
      ),
    );
  }
}

/// A full-page empty or failed state: icon, title, optional message and an
/// optional action. Shared geometry for every page's empty and error states.
class FrostEmptyContent extends StatelessWidget {
  const FrostEmptyContent({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
    this.actionIcon,
    this.leading,
    this.error = false,
    super.key,
  });

  final FrostIconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Defaults to the refresh icon.
  final FrostIconData? actionIcon;

  /// Replaces the icon, for a picture of the app's own.
  final Widget? leading;

  /// Marks a failure: the icon takes the error colour and the content is
  /// announced as it appears.
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final actionLabel = this.actionLabel;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.all(FrostMetrics.sectionGap),
          child: Semantics(
            liveRegion: error,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ExcludeSemantics(child: leading ?? FrostIcon(icon, size: 48, color: error ? colorScheme.error : colorScheme.onSurfaceVariant)),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
                if (message case final message?) ...[
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                  ),
                ],
                if (onAction != null && actionLabel != null) ...[
                  const SizedBox(height: 20),
                  FilledButton.tonalIcon(
                    onPressed: onAction,
                    icon: FrostIcon(actionIcon ?? FrostIconSet.of(context).refresh, size: FrostMetrics.iconSize),
                    label: Text(actionLabel),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
