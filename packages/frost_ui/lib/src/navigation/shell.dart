import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frost_ui/src/controls/click_surface.dart';
import 'package:frost_ui/src/controls/icon.dart';
import 'package:frost_ui/src/foundation/density.dart';
import 'package:frost_ui/src/foundation/feedback.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/scope.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/layout/auto_scaffold.dart';
import 'package:frost_ui/src/layout/content_viewport.dart';
import 'package:frost_ui/src/layout/window_caption_scope.dart';
import 'package:frost_ui/src/motion/layout_crossfade.dart';
import 'package:frost_ui/src/motion/spring.dart';
import 'package:frost_ui/src/navigation/shell_navigation_scope.dart';
import 'package:frost_ui/src/surface/surface.dart';

/// One navigation destination: an icon and its always-visible label.
@immutable
class FrostNavDestination {
  const FrostNavDestination({required this.icon, required this.label});

  final FrostIconData icon;
  final String label;
}

/// Geometry of the navigation, shared by every sidebar style.
@immutable
class FrostNavigationMetrics {
  const FrostNavigationMetrics({
    required this.railWidth,
    required this.expandedWidth,
    required this.headerHeight,
    required this.expandableMinWidth,
    required this.mobileMaxWidth,
  });

  static const standard = FrostNavigationMetrics(railWidth: 80, expandedWidth: 176, headerHeight: 56, expandableMinWidth: 1200, mobileMaxWidth: 600);

  /// Collapsed sidebar width: icons with short labels below.
  final double railWidth;

  /// Expanded sidebar width: icons with labels beside them.
  final double expandedWidth;

  /// Height of the back button row at the top of the sidebar.
  final double headerHeight;

  /// The window width from which the sidebar may be expanded.
  final double expandableMinWidth;

  /// Below this window width the phone's bottom navigation replaces the sidebar.
  final double mobileMaxWidth;
}

/// Where the shell placed its sidebar, for overlays that line up with it
/// (such as a dock under the navigation).
@immutable
class FrostShellGeometry {
  const FrostShellGeometry({required this.sidebarRight, required this.iconAxis, required this.bottom});

  /// Right edge of the sidebar including its outer margin.
  final double sidebarRight;

  /// Horizontal centre of the sidebar's icon column, from the window's left.
  final double iconAxis;

  /// Distance from the window's bottom to the sidebar's bottom edge.
  final double bottom;
}

typedef FrostSidebarFrameBuilder = Widget Function(BuildContext context, Widget navigation);

/// How a navigation item marks its state.
enum FrostNavItemForm {
  /// Collapsed: an icon in a pill above a short label. Expanded: the pill
  /// grows into the row. Selection fills the pill.
  pill,

  /// Collapsed: the icon alone, its label in a tooltip. Expanded: icon and
  /// label in a row. Selection is a bar on the sidebar's edge and accent ink.
  indicator,
}

/// The outer form of the desktop sidebar. Every form shares the navigation
/// items, their spring, the More menu and the geometry; a form decides the
/// frame around them, how far it sits from the window edges, how items mark
/// their state and how the page's pinned bars sit beside it.
@immutable
sealed class FrostSidebarStyle {
  const FrostSidebarStyle();

  /// A floating glass capsule with a margin from the window edges.
  const factory FrostSidebarStyle.capsule() = FrostCapsuleSidebar;

  /// A full-height panel flush with the window's left edge: square corners,
  /// a solid surface and a hairline towards the content. Where the window is
  /// too narrow to push the page aside it still expands, over the page.
  const factory FrostSidebarStyle.flush() = FrostFlushSidebar;

  /// A frame of the app's own. [outerMargin] is the distance from the window's
  /// left, top and bottom edges; [gutter] the gap to the page.
  const factory FrostSidebarStyle.custom({
    required EdgeInsets outerMargin,
    required double gutter,
    required FrostSidebarFrameBuilder frameBuilder,
    FrostNavItemForm itemForm,
    bool expandsOverContent,
    bool floatingChrome,
    bool continuesIntoCaption,
  }) = FrostCustomSidebar;

  EdgeInsets margin(BuildContext context);
  double get gutter;
  Widget frame(BuildContext context, Widget navigation);
  FrostNavItemForm get itemForm;

  /// Whether the sidebar may expand over the page where the window is too
  /// narrow to make room for it; otherwise it stays collapsed there.
  bool get expandsOverContent;

  /// Whether pinned page bars float as rounded panels beside the sidebar
  /// (see [FrostPinnedChromeGlass]) rather than sitting flush.
  bool get floatingChrome;

  /// Whether a Flutter-drawn window caption continues the sidebar up to the
  /// top of the window (see [FrostWindowCaptionScope.sidebar]).
  bool get continuesIntoCaption;
}

final class FrostCapsuleSidebar extends FrostSidebarStyle {
  const FrostCapsuleSidebar();

  @override
  bool get continuesIntoCaption => false;

  @override
  FrostNavItemForm get itemForm => FrostNavItemForm.pill;

  @override
  bool get expandsOverContent => false;

  @override
  bool get floatingChrome => true;

  static const _margin = 8.0;

  @override
  EdgeInsets margin(BuildContext context) {
    // On Windows the title bar already separates the panel from the window
    // edge; elsewhere, where the status bar has no divider of its own, the
    // panel keeps the margin below it too.
    final top = Theme.of(context).platform == TargetPlatform.windows ? 0.0 : _margin;
    return EdgeInsets.fromLTRB(_margin, top, 0, _margin);
  }

  @override
  double get gutter => 4;

  @override
  Widget frame(BuildContext context, Widget navigation) =>
      FrostSurface(role: FrostSurfaceRole.chrome, borderRadius: BorderRadius.circular(FrostMetrics.groupRadius + 4), child: navigation);
}

final class FrostFlushSidebar extends FrostSidebarStyle {
  const FrostFlushSidebar();

  @override
  bool get continuesIntoCaption => true;

  @override
  EdgeInsets margin(BuildContext context) => EdgeInsets.zero;

  @override
  double get gutter => 0;

  @override
  FrostNavItemForm get itemForm => FrostNavItemForm.indicator;

  @override
  bool get expandsOverContent => true;

  @override
  bool get floatingChrome => false;

  @override
  Widget frame(BuildContext context, Widget navigation) {
    // A solid panel: glass here would stack a second material against the
    // page's own pinned glass along the whole window height.
    final tokens = FrostThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: tokens.surface,
        border: BorderDirectional(end: BorderSide(color: tokens.line)),
      ),
      child: Material(type: MaterialType.transparency, child: navigation),
    );
  }
}

final class FrostCustomSidebar extends FrostSidebarStyle {
  const FrostCustomSidebar({
    required this.outerMargin,
    required this.gutter,
    required this.frameBuilder,
    this.itemForm = FrostNavItemForm.pill,
    this.expandsOverContent = false,
    this.floatingChrome = true,
    this.continuesIntoCaption = false,
  });

  final EdgeInsets outerMargin;
  final FrostSidebarFrameBuilder frameBuilder;

  @override
  final double gutter;

  @override
  final FrostNavItemForm itemForm;

  @override
  final bool expandsOverContent;

  @override
  final bool floatingChrome;

  @override
  final bool continuesIntoCaption;

  @override
  EdgeInsets margin(BuildContext context) => outerMargin;

  @override
  Widget frame(BuildContext context, Widget navigation) => frameBuilder(context, navigation);
}

/// The app's navigation shell: a desktop sidebar (or a phone bottom bar)
/// around the current page. Routing stays in the app; the shell reports
/// selections and owns page-level Back and Escape.
class FrostShell extends StatefulWidget {
  const FrostShell({
    required this.destinations,
    required this.selectedIndex,
    required this.atDestinationRoot,
    required this.onDestinationSelected,
    required this.canGoBack,
    required this.onBack,
    required this.showsMobileNavigation,
    required this.sidebarStyle,
    required this.child,
    this.secondaryDestinations = const [],
    this.selectedSecondaryIndex,
    this.onSecondarySelected,
    this.metrics = FrostNavigationMetrics.standard,
    this.initiallyExpanded = false,
    this.onExpandedChanged,
    this.desktopOverlayBuilder,
    super.key,
  });

  final List<FrostNavDestination> destinations;

  /// The primary destination the current page belongs to, if any.
  final int? selectedIndex;

  /// Whether the current page is the selected destination's own root page,
  /// with nothing pushed above it. Selecting that destination again then
  /// signals [FrostShellNavigationScope.primaryReselection] (scroll to top,
  /// refresh) instead of navigating.
  final bool atDestinationRoot;
  final ValueChanged<int> onDestinationSelected;

  /// Destinations in the More menu (collapsed) or the secondary group
  /// (expanded). Not shown on the phone's bottom bar.
  final List<FrostNavDestination> secondaryDestinations;
  final int? selectedSecondaryIndex;
  final ValueChanged<int>? onSecondarySelected;

  /// Whether Back has somewhere to go: a pushed page or a parent location.
  final bool canGoBack;
  final VoidCallback onBack;

  /// Whether the phone layout shows the bottom navigation on this page
  /// (top-level pages) rather than leaving the page full height.
  final bool showsMobileNavigation;
  final FrostSidebarStyle sidebarStyle;
  final FrostNavigationMetrics metrics;

  /// The saved choice of an expanded sidebar where the window makes room for
  /// it. Read once; the shell then owns the choice and reports changes
  /// through [onExpandedChanged].
  final bool initiallyExpanded;

  /// Called when the user expands or collapses the sidebar beside the page.
  /// Collapsing forced by a narrow window, and opening over the page, are
  /// not choices and are not reported.
  final ValueChanged<bool>? onExpandedChanged;

  /// Desktop layers placed over the page, aligned with the sidebar.
  final Widget Function(BuildContext context, FrostShellGeometry geometry)? desktopOverlayBuilder;
  final Widget child;

  @override
  State<FrostShell> createState() => _FrostShellState();
}

class _FrostShellState extends State<FrostShell> with SingleTickerProviderStateMixin {
  late final AnimationController _sidebarProgress = AnimationController(vsync: this, value: widget.initiallyExpanded ? 1 : 0);
  final FocusNode _moreButtonFocus = FocusNode(debugLabel: 'More navigation');
  final ValueNotifier<({int index, int sequence})> _primaryReselection = ValueNotifier((index: 0, sequence: 0));

  /// The user's choice where the sidebar sits beside the page.
  late bool _expandedBeside = widget.initiallyExpanded;

  /// Whether the sidebar is open over the page in a narrow window.
  bool _expandedOver = false;

  /// Whether the window made room for an expanded sidebar at the last
  /// layout; null before the first one.
  bool? _besidePage;

  /// The progress to draw until a layout switch lands on the controller.
  double? _settledProgress;

  /// The caption that continues the sidebar, and what it needs from the last
  /// layout; the layout is null while there is no sidebar to continue.
  FrostCaptionSidebarNotifier? _caption;
  ({double left, FrostNavigationMetrics metrics, bool canExpand})? _captionLayout;

  FrostCaptionSidebar? _captionSidebarAt(double value) {
    final layout = _captionLayout;
    if (layout == null) return null;
    final progress = layout.canExpand ? value : 0.0;
    return FrostCaptionSidebar(
      width: layout.left + lerpDouble(layout.metrics.railWidth, layout.metrics.expandedWidth, progress)!,
      iconAxis: layout.left + _SidebarNavigation.iconAxis(layout.metrics, progress),
      expansion: progress,
      style: widget.sidebarStyle,
    );
  }

  /// Runs as the spring ticks, before the frame builds, so the caption and the
  /// sidebar move in the same frame.
  void _publishProgress() {
    if (_settledProgress == null) _caption?.value = _captionSidebarAt(_sidebarProgress.value);
  }

  /// Layout changes (resize, density, phone layout) reach the caption after
  /// the frame that made them; layout cannot notify another widget.
  void _publishLayout(double value) {
    final caption = _caption;
    if (caption == null || caption.value == _captionSidebarAt(value)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) caption.value = _captionSidebarAt(_settledProgress ?? _sidebarProgress.value);
    });
  }

  @override
  void initState() {
    super.initState();
    _sidebarProgress.addListener(_publishProgress);
  }

  bool get _expandedTarget => (_besidePage ?? true) ? _expandedBeside : _expandedOver;

  void _toggleExpansion() {
    if (_besidePage ?? true) {
      _expandedBeside = !_expandedBeside;
      widget.onExpandedChanged?.call(_expandedBeside);
    } else {
      _expandedOver = !_expandedOver;
    }
    _springToTarget();
  }

  void _closeOverlay() {
    if (!_expandedOver) return;
    _expandedOver = false;
    _springToTarget();
  }

  void _springToTarget() {
    // One spring drives the width, the content start, the overlays and
    // every label, so they stay in step; a toggle mid-way turns back at the
    // current speed instead of restarting.
    FrostMotion.springTo(context, _sidebarProgress, _expandedTarget ? 1.0 : 0.0, FrostMotion.standard);
  }

  /// Follows the window across the width that makes room for the sidebar.
  /// The switch jumps rather than animates, so the sidebar tracks a resize.
  void _updateBesidePage(bool besidePage) {
    if (_besidePage == besidePage) return;
    final first = _besidePage == null;
    _besidePage = besidePage;
    _expandedOver = false;
    final target = _expandedTarget ? 1.0 : 0.0;
    if (first && _sidebarProgress.value == target) return;
    // Layout cannot drive the controller; draw the target now and move the
    // controller there after the frame.
    _settledProgress = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _settledProgress = null;
      _sidebarProgress.value = _expandedTarget ? 1.0 : 0.0;
    });
  }

  void _selectIndex(int index) {
    _closeOverlay();
    if (index == widget.selectedIndex && widget.atDestinationRoot) {
      _primaryReselection.value = (index: index, sequence: _primaryReselection.value.sequence + 1);
      return;
    }
    widget.onDestinationSelected(index);
  }

  void _selectSecondary(int index) {
    _closeOverlay();
    widget.onSecondarySelected?.call(index);
  }

  @override
  void dispose() {
    final caption = _caption;
    if (caption?.value != null) WidgetsBinding.instance.addPostFrameCallback((_) => caption!.clear());
    _sidebarProgress.dispose();
    _moreButtonFocus.dispose();
    _primaryReselection.dispose();
    super.dispose();
  }

  EdgeInsets _frame(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    final margin = widget.sidebarStyle.margin(context);
    // System insets are often fractional; whole physical pixels keep the
    // page's pinned glass edges (and joins between them) crisp.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    double snap(double value) => (value * pixelRatio).roundToDouble() / pixelRatio;
    return EdgeInsets.fromLTRB(snap(safe.left + margin.left), snap(safe.top + margin.top), 0, snap(safe.bottom + margin.bottom));
  }

  @override
  Widget build(BuildContext context) {
    final metrics = widget.metrics;
    final style = widget.sidebarStyle;
    return FrostAutoScaffold(
      mobileBreakpoint: metrics.mobileMaxWidth,
      builder: (context, layout, orientation, useHorizontalLayout) {
        final besidePage = useHorizontalLayout && layout.width >= metrics.expandableMinWidth;
        _updateBesidePage(besidePage);
        final canExpand = besidePage || (useHorizontalLayout && style.expandsOverContent);
        final showSidebar = useHorizontalLayout;
        return FrostShellNavigationScope(
          ownsBackControl: useHorizontalLayout,
          canGoBack: widget.canGoBack,
          goBack: widget.onBack,
          primaryReselection: _primaryReselection,
          floatingChrome: style.floatingChrome,
          // Menus, dialogs, panels and viewers handle Escape inside their own
          // subtree first; only an unhandled Escape bubbles up to this
          // page-level shortcut, so each press closes one layer. It has its
          // own intent: the Scaffolds between here and the page map
          // DismissIntent to their drawers and would swallow it.
          child: Shortcuts(
            shortcuts: const {SingleActivator(LogicalKeyboardKey.escape): _PageBackIntent()},
            child: Actions(
              actions: {
                _PageBackIntent: _PageBackAction(
                  overlayOpen: () => _expandedOver,
                  closeOverlay: _closeOverlay,
                  canGoBack: () => widget.canGoBack,
                  goBack: widget.onBack,
                ),
              },
              child: FrostLayoutCrossfade(
                layoutIdentity: useHorizontalLayout,
                child: Scaffold(
                  // The shell never shrinks for the keyboard: the sidebar, its
                  // overlays and the phone's bottom navigation stay put. Pages
                  // keep avoiding it through their own Scaffolds.
                  resizeToAvoidBottomInset: false,
                  extendBody: !useHorizontalLayout && widget.showsMobileNavigation,
                  body: AnimatedBuilder(
                    animation: _sidebarProgress,
                    builder: (context, _) {
                      final progress = canExpand ? (_settledProgress ?? _sidebarProgress.value) : 0.0;
                      final railWidth = lerpDouble(metrics.railWidth, metrics.expandedWidth, progress)!;
                      // Open over the page, the sidebar leaves the page where
                      // the collapsed rail put it.
                      final pageRail = besidePage ? railWidth : metrics.railWidth;
                      final overPage = !besidePage && progress > 0;
                      final frame = _frame(context);
                      final overlay = widget.desktopOverlayBuilder;
                      final shadow = FrostThemeTokens.of(context).shadow;
                      _caption = FrostWindowCaptionScope.sidebarOf(context);
                      _captionLayout = showSidebar && style.continuesIntoCaption ? (left: frame.left, metrics: metrics, canExpand: canExpand) : null;
                      _publishLayout(_settledProgress ?? _sidebarProgress.value);
                      // Only positioned layers: the Stack must take the body size.
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          // Pages start beside the sidebar so it never covers
                          // their hit targets. The tree keeps one shape so a
                          // fold or resize that switches layouts keeps state.
                          Positioned.fill(
                            left: showSidebar ? frame.left + pageRail + style.gutter : 0,
                            top: showSidebar ? frame.top : 0,
                            child: MediaQuery.removePadding(
                              context: context,
                              removeLeft: showSidebar,
                              removeTop: showSidebar,
                              child: FrostContentViewport(navigationReserve: besidePage ? metrics.expandedWidth - railWidth : 0, child: widget.child),
                            ),
                          ),
                          // A click outside the open panel closes it.
                          if (overPage)
                            Positioned.fill(
                              child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: _closeOverlay),
                            ),
                          if (showSidebar)
                            Positioned(
                              left: frame.left,
                              top: frame.top,
                              bottom: frame.bottom,
                              width: railWidth,
                              child: DecoratedBox(
                                // A light shadow sets the open panel apart from
                                // the page it covers.
                                decoration: BoxDecoration(
                                  boxShadow: overPage
                                      ? [BoxShadow(color: shadow.withValues(alpha: shadow.a * progress.clamp(0.0, 1.0)), blurRadius: 16)]
                                      : null,
                                ),
                                child: style.frame(
                                  context,
                                  _SidebarNavigation(
                                    destinations: widget.destinations,
                                    selectedIndex: widget.selectedIndex,
                                    secondaryDestinations: widget.secondaryDestinations,
                                    selectedSecondaryIndex: widget.selectedSecondaryIndex,
                                    metrics: metrics,
                                    itemForm: style.itemForm,
                                    progress: progress,
                                    expandedTarget: _expandedTarget,
                                    canGoBack: widget.canGoBack,
                                    onBack: widget.onBack,
                                    canExpand: canExpand,
                                    onExpansionToggle: _toggleExpansion,
                                    onDestinationSelected: _selectIndex,
                                    onSecondarySelected: _selectSecondary,
                                    moreButtonFocus: _moreButtonFocus,
                                  ),
                                ),
                              ),
                            ),
                          if (useHorizontalLayout && overlay != null)
                            overlay(
                              context,
                              FrostShellGeometry(
                                sidebarRight: showSidebar ? frame.left + pageRail + style.margin(context).left : 0,
                                iconAxis: frame.left + _SidebarNavigation.iconAxis(metrics, besidePage ? progress : 0),
                                bottom: frame.bottom,
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  bottomNavigationBar: !useHorizontalLayout && widget.showsMobileNavigation
                      ? _MobileNavBar(destinations: widget.destinations, selectedIndex: widget.selectedIndex ?? 0, onDestinationSelected: _selectIndex)
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SidebarNavigation extends StatelessWidget {
  const _SidebarNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.secondaryDestinations,
    required this.selectedSecondaryIndex,
    required this.metrics,
    required this.itemForm,
    required this.progress,
    required this.expandedTarget,
    required this.canGoBack,
    required this.onBack,
    required this.canExpand,
    required this.onExpansionToggle,
    required this.onDestinationSelected,
    required this.onSecondarySelected,
    required this.moreButtonFocus,
  });

  final List<FrostNavDestination> destinations;
  final int? selectedIndex;
  final List<FrostNavDestination> secondaryDestinations;
  final int? selectedSecondaryIndex;
  final FrostNavigationMetrics metrics;
  final FrostNavItemForm itemForm;
  final double progress;
  final bool expandedTarget;
  final bool canGoBack;
  final VoidCallback onBack;
  final bool canExpand;
  final VoidCallback onExpansionToggle;
  final ValueChanged<int> onDestinationSelected;
  final ValueChanged<int> onSecondarySelected;
  final FocusNode moreButtonFocus;

  static const _innerPadding = 8.0;

  /// Width of the column the back and expand/collapse buttons are centred in.
  static double _iconColumnWidth(FrostNavigationMetrics metrics, double progress) => lerpDouble(metrics.railWidth - _innerPadding * 2, 48, progress)!;

  /// Horizontal centre of that column from the sidebar's left edge.
  static double iconAxis(FrostNavigationMetrics metrics, double progress) => _innerPadding + _iconColumnWidth(metrics, progress) / 2;

  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    // The flush form keeps More and the secondary group at the bottom, apart
    // from the destinations; the pill form keeps them after the list.
    final secondaryAtBottom = itemForm == FrostNavItemForm.indicator;
    final Widget? secondary = secondaryDestinations.isEmpty
        ? null
        : Stack(
            alignment: Alignment.topLeft,
            children: [
              IgnorePointer(
                ignoring: progress > .25,
                child: ExcludeFocus(
                  excluding: progress > .25,
                  child: Opacity(
                    opacity: (1 - progress * 4).clamp(0.0, 1.0),
                    child: Builder(
                      builder: (buttonContext) {
                        void open() => _showMore(buttonContext, secondaryDestinations, selectedSecondaryIndex, onSecondarySelected, moreButtonFocus);
                        return Focus(
                          focusNode: moreButtonFocus,
                          skipTraversal: true,
                          onKeyEvent: (node, event) {
                            if (event is! KeyDownEvent || (event.logicalKey != LogicalKeyboardKey.enter && event.logicalKey != LogicalKeyboardKey.space)) {
                              return KeyEventResult.ignored;
                            }
                            open();
                            return KeyEventResult.handled;
                          },
                          child: FrostNavItem(
                            form: itemForm,
                            indicatorInset: _innerPadding,
                            label: labels.more,
                            icon: icons.more,
                            selected: selectedSecondaryIndex != null,
                            progress: progress,
                            onTap: open,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                ignoring: progress <= .25,
                child: ExcludeFocus(
                  excluding: progress <= .25,
                  // While collapsed the hidden group takes no
                  // height, so a list that fits never scrolls; it
                  // grows with the sidebar as it expands.
                  child: ClipRect(
                    // Settled open, the items may mark selection on the panel edge.
                    clipBehavior: progress >= 1 ? Clip.none : Clip.hardEdge,
                    child: Align(
                      alignment: Alignment.topCenter,
                      heightFactor: progress.clamp(0.0, 1.0),
                      child: Opacity(
                        opacity: ((progress - .25) * 4 / 3).clamp(0.0, 1.0),
                        child: Column(
                          children: [
                            // Secondary destinations get a quiet group
                            // divider so they do not read as primary.
                            Divider(height: 1, indent: 12, endIndent: 12, color: FrostThemeTokens.of(context).line.withValues(alpha: .6)),
                            const SizedBox(height: 8),
                            for (final (index, destination) in secondaryDestinations.indexed) ...[
                              FrostNavItem(
                                form: itemForm,
                                indicatorInset: _innerPadding,
                                label: destination.label,
                                icon: destination.icon,
                                selected: selectedSecondaryIndex == index,
                                progress: progress,
                                labelOpacity: ((progress - .85) / .15).clamp(0.0, 1.0),
                                onTap: () => onSecondarySelected(index),
                              ),
                              const SizedBox(height: 4),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
    return MediaQuery.removePadding(
      context: context,
      removeLeft: true,
      removeTop: true,
      removeBottom: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: _innerPadding),
              child: SizedBox(
                height: metrics.headerHeight,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: SizedBox(
                    // Centred on the rail's icon axis, then on the expanded
                    // row's icon column, like the navigation icons below.
                    width: _iconColumnWidth(metrics, progress),
                    child: Center(
                      child: IconButton(tooltip: labels.back, onPressed: canGoBack ? onBack : null, icon: FrostIcon(icons.back)),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Expanded(
              child: _EdgeFadeScrollView(
                // The list spans the whole panel so an item can mark its
                // selection on the panel edge; the items keep the inset.
                padding: const EdgeInsets.fromLTRB(_innerPadding, 0, _innerPadding, 88),
                children: [
                  for (var index = 0; index < destinations.length; index++) ...[
                    if (index > 0) const SizedBox(height: 4),
                    FrostNavItem(
                      form: itemForm,
                      indicatorInset: _innerPadding,
                      label: destinations[index].label,
                      icon: destinations[index].icon,
                      selected: selectedIndex == index,
                      progress: progress,
                      onTap: () => onDestinationSelected(index),
                    ),
                  ],
                  if (secondary != null && !secondaryAtBottom) ...[
                    // Same rhythm as the primary items while collapsed; the
                    // expanded secondary group gets room for its divider.
                    SizedBox(height: lerpDouble(4, 16, progress)),
                    secondary,
                  ],
                ],
              ),
            ),
            if (secondary != null && secondaryAtBottom) Padding(padding: const EdgeInsets.fromLTRB(_innerPadding, 4, _innerPadding, 0), child: secondary),
            if (canExpand)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _innerPadding),
                child: SizedBox(
                  height: 44,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: SizedBox(
                      width: _iconColumnWidth(metrics, progress),
                      child: Center(
                        child: IconButton(
                          tooltip: expandedTarget ? labels.collapseNavigation : labels.expandNavigation,
                          onPressed: onExpansionToggle,
                          icon: FrostIcon(expandedTarget ? icons.sidebarCollapse : icons.sidebarExpand),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Short-height windows scroll the navigation list without a scrollbar; the
/// edges fade so clipped items read as more content rather than a cut.
class _EdgeFadeScrollView extends StatefulWidget {
  const _EdgeFadeScrollView({required this.children, this.padding = EdgeInsets.zero});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  State<_EdgeFadeScrollView> createState() => _EdgeFadeScrollViewState();
}

class _EdgeFadeScrollViewState extends State<_EdgeFadeScrollView> {
  static const _fadeExtent = 20.0;
  bool _fadeTop = false;
  bool _fadeBottom = false;

  bool _update(ScrollMetrics metrics) {
    final top = metrics.extentBefore > 0.5;
    final bottom = metrics.extentAfter > 0.5;
    if (top != _fadeTop || bottom != _fadeBottom) {
      setState(() {
        _fadeTop = top;
        _fadeBottom = bottom;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final list = NotificationListener<ScrollMetricsNotification>(
      onNotification: (notification) => _update(notification.metrics),
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) => _update(notification.metrics),
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: ListView(primary: false, padding: widget.padding, children: widget.children),
        ),
      ),
    );
    if (!_fadeTop && !_fadeBottom) return list;
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (bounds) {
        final edge = (_fadeExtent / math.max(1.0, bounds.height)).clamp(0.0, .5);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_fadeTop ? Colors.transparent : Colors.black, Colors.black, Colors.black, _fadeBottom ? Colors.transparent : Colors.black],
          stops: [0, edge, 1 - edge, 1],
        ).createShader(bounds);
      },
      child: list,
    );
  }
}

/// Navigation destination in one of the [FrostNavItemForm]s. One animation
/// progress drives size, positions and the state marks so nothing jumps.
class FrostNavItem extends StatelessWidget {
  const FrostNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.form = FrostNavItemForm.pill,
    this.indicatorInset = 0,
    this.progress = 0,
    this.labelOpacity = 1,
    super.key,
  });

  final String label;
  final FrostIconData icon;
  final bool selected;
  final FrostNavItemForm form;

  /// How far the item sits inside the sidebar's edge; the
  /// [FrostNavItemForm.indicator] bar is drawn that far out, on the edge.
  final double indicatorInset;
  final double progress;
  final double labelOpacity;
  final VoidCallback onTap;

  /// Icon start in the expanded indicator row: the back and expand buttons
  /// above and below centre on the same axis.
  static const _indicatorIconStart = 13.0;
  static const _iconSize = 22.0;

  @override
  Widget build(BuildContext context) => switch (form) {
    FrostNavItemForm.pill => _buildPill(context),
    FrostNavItemForm.indicator => _buildIndicator(context),
  };

  Widget _buildIndicator(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final theme = Theme.of(context);
    final density = FrostDensity.of(context);
    final amount = progress.clamp(0.0, 1.0);
    final style = theme.textTheme.labelLarge?.copyWith(
      color: selected ? tokens.selectionInk : tokens.textSecondary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    final ink = selected ? tokens.selectionInk : tokens.textSecondary;
    final painter = TextPainter(
      text: TextSpan(text: label, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final labelHeight = painter.height;
    painter.dispose();
    final height = math.max(density.controlHeight, labelHeight + 16);

    final item = Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: FrostClickSurface(
        feedback: FrostClickFeedback.media,
        borderRadius: BorderRadius.circular(FrostMetrics.controlRadius),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final hovered = FrostClickSurface.hoveredOf(context);
            final width = constraints.maxWidth;
            final iconStart = lerpDouble((width - _iconSize) / 2, _indicatorIconStart, amount)!;
            final labelStart = _indicatorIconStart + _iconSize + 12;
            return SizedBox(
              width: double.infinity,
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: FrostMotion.duration(context, FrostMotion.hover),
                      curve: FrostMotion.hoverCurve,
                      decoration: BoxDecoration(
                        color: frostButtonStateLayer(tokens, {if (hovered) WidgetState.hovered}, FrostFeedbackRole.quiet),
                        borderRadius: BorderRadius.circular(FrostMetrics.controlRadius),
                      ),
                    ),
                  ),
                  // The selection bar sits on the sidebar's edge, so it never
                  // reads as part of the hover shape.
                  PositionedDirectional(
                    start: -indicatorInset,
                    top: (height - 24) / 2,
                    width: FrostMetrics.selectionIndicatorWidth,
                    height: 24,
                    child: AnimatedOpacity(
                      opacity: selected ? 1 : 0,
                      duration: FrostMotion.duration(context, FrostMotion.hover),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: tokens.keyGraphicOn(tokens.surface),
                          borderRadius: const BorderRadiusDirectional.horizontal(
                            end: Radius.circular(FrostMetrics.selectionIndicatorWidth),
                          ).resolve(Directionality.of(context)),
                        ),
                      ),
                    ),
                  ),
                  PositionedDirectional(
                    start: iconStart,
                    top: (height - _iconSize) / 2,
                    child: FrostIcon(icon, size: _iconSize, color: ink),
                  ),
                  if (amount > 0)
                    PositionedDirectional(
                      start: labelStart,
                      end: 8,
                      top: (height - labelHeight) / 2,
                      child: Opacity(
                        // The label appears once the row has room for it.
                        opacity: ((amount - .4) / .6).clamp(0.0, 1.0) * labelOpacity,
                        child: Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false, style: style),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
    // Collapsed, the label is only in the tooltip. The tooltip stays in the
    // tree either way so the hover state survives the expansion.
    return TooltipVisibility(
      visible: amount < .5,
      child: Tooltip(message: label, excludeFromSemantics: true, waitDuration: const Duration(milliseconds: 300), child: item),
    );
  }

  Widget _buildPill(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final theme = Theme.of(context);
    final amount = progress.clamp(0.0, 1.0);
    final smallStyle = theme.textTheme.labelSmall;
    final largeStyle = theme.textTheme.labelLarge;
    final collapsedLabel = TextPainter(
      text: TextSpan(text: label, style: smallStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout(maxWidth: 60);
    final expandedLabel = TextPainter(
      text: TextSpan(text: label, style: largeStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: 108);
    final collapsedHeight = math.max(62.0, 4 + 32 + 4 + collapsedLabel.height + 8);
    final expandedHeight = math.max(44.0, expandedLabel.height + 16);
    final collapsedTextHeight = collapsedLabel.height;
    final expandedTextHeight = expandedLabel.height;
    collapsedLabel.dispose();
    expandedLabel.dispose();
    final height = lerpDouble(collapsedHeight, expandedHeight, amount)!;
    final ink = selected ? tokens.selectionInk : tokens.textSecondary;
    final labelStyle = TextStyle.lerp(smallStyle, largeStyle, amount)?.copyWith(
      color: selected ? Color.lerp(tokens.textPrimary, tokens.selectionInk, amount) : tokens.textSecondary,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );

    // Labels are always visible, so the item carries no duplicate tooltip.
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: FrostClickSurface(
        feedback: FrostClickFeedback.media,
        borderRadius: BorderRadius.circular(FrostMetrics.controlRadius),
        onTap: onTap,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Hover is read from the surface itself, so no second copy of it
            // can outlive the pointer that set it.
            final hovered = FrostClickSurface.hoveredOf(context);
            final pillColor = selected ? tokens.selectionFill : frostButtonStateLayer(tokens, {if (hovered) WidgetState.hovered}, FrostFeedbackRole.quiet);
            final width = constraints.maxWidth;
            final collapsedPill = Rect.fromLTWH((width - 52) / 2, 4, 52, 32);
            final pill = Rect.lerp(collapsedPill, Offset.zero & Size(width, height), amount)!;
            return SizedBox(
              width: double.infinity,
              height: height,
              child: Stack(
                children: [
                  Positioned.fromRect(
                    rect: pill,
                    child: AnimatedContainer(
                      duration: FrostMotion.duration(context, FrostMotion.hover),
                      curve: FrostMotion.hoverCurve,
                      decoration: BoxDecoration(color: pillColor, borderRadius: BorderRadius.circular(lerpDouble(16, FrostMetrics.controlRadius, amount)!)),
                    ),
                  ),
                  Positioned(
                    left: lerpDouble(width / 2 - 11, 13, amount)!,
                    top: lerpDouble(9, (height - 22) / 2, amount)!,
                    child: FrostIcon(icon, size: 22, color: ink),
                  ),
                  Positioned(
                    left: lerpDouble(0, 46, amount)!,
                    top: lerpDouble(40, (height - expandedTextHeight) / 2, amount)!,
                    width: lerpDouble(width, math.max(0, width - 52), amount)!,
                    height: lerpDouble(collapsedTextHeight, expandedTextHeight, amount),
                    child: Opacity(
                      opacity: labelOpacity,
                      child: Align(
                        alignment: Alignment.lerp(Alignment.topCenter, Alignment.centerLeft, amount)!,
                        child: Text(
                          label,
                          maxLines: amount >= .999 ? null : 1,
                          overflow: amount >= .999 ? TextOverflow.visible : TextOverflow.ellipsis,
                          textAlign: amount < .5 ? TextAlign.center : TextAlign.start,
                          style: labelStyle,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MobileNavBar extends StatelessWidget {
  const _MobileNavBar({required this.destinations, required this.selectedIndex, required this.onDestinationSelected});

  final List<FrostNavDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    return FrostSurface(
      role: FrostSurfaceRole.chrome,
      borderRadius: BorderRadius.zero,
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final style = (Theme.of(context).textTheme.labelSmall ?? const TextStyle(fontSize: 12)).copyWith(height: 1, fontWeight: FontWeight.w700);
            final labelWidth = math.max(1.0, constraints.maxWidth / destinations.length - 8);
            final labelHeight = destinations
                .map((destination) {
                  final painter = TextPainter(
                    text: TextSpan(text: destination.label, style: style),
                    textDirection: Directionality.of(context),
                    textAlign: TextAlign.center,
                    textScaler: MediaQuery.textScalerOf(context),
                  )..layout(maxWidth: labelWidth);
                  final height = painter.height;
                  painter.dispose();
                  return height;
                })
                .reduce(math.max);
            return SizedBox(
              height: math.max(64, 8 + 30 + 4 + labelHeight + 8),
              child: Row(
                children: [
                  for (var index = 0; index < destinations.length; index++)
                    Expanded(
                      child: _MobileNavItem(
                        label: destinations[index].label,
                        labelHeight: labelHeight,
                        icon: destinations[index].icon,
                        selected: selectedIndex == index,
                        onTap: () => onDestinationSelected(index),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MobileNavItem extends StatelessWidget {
  const _MobileNavItem({required this.label, required this.labelHeight, required this.icon, required this.selected, required this.onTap});

  final String label;
  final double labelHeight;
  final FrostIconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final duration = FrostMotion.duration(context, FrostMotion.hover);

    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: FrostClickSurface(
        feedback: FrostClickFeedback.media,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FrostSpringBuilder(
                value: selected ? 56 : 40,
                spring: FrostMotion.snappy,
                builder: (context, width, child) => SizedBox(width: width, height: 30, child: child),
                child: AnimatedContainer(
                  duration: duration,
                  decoration: BoxDecoration(
                    color: selected ? tokens.selectionFill : tokens.selectionFill.withValues(alpha: 0),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(child: FrostIcon(icon, size: 22, color: selected ? tokens.selectionInk : tokens.textSecondary)),
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: labelHeight,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    softWrap: true,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      height: 1,
                      color: selected ? tokens.textPrimary : tokens.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showMore(
  BuildContext context,
  List<FrostNavDestination> destinations,
  int? selectedIndex,
  ValueChanged<int> onSelected,
  FocusNode buttonFocus,
) async {
  buttonFocus.requestFocus();
  final button = context.findRenderObject() as RenderBox?;
  final overlay = Navigator.of(context).overlay?.context.findRenderObject() as RenderBox?;
  if (button == null || overlay == null) return;
  final buttonRect = Rect.fromPoints(
    button.localToGlobal(Offset.zero, ancestor: overlay),
    button.localToGlobal(button.size.bottomRight(Offset.zero), ancestor: overlay),
  );
  final selected = await showDialog<int>(
    context: context,
    animationStyle: AnimationStyle(duration: FrostMotion.page),
    useRootNavigator: false,
    barrierDismissible: true,
    barrierColor: Colors.transparent,
    barrierLabel: FrostScope.labelsOf(context).dismiss,
    requestFocus: true,
    builder: (dialogContext) => LayoutBuilder(
      builder: (dialogContext, constraints) {
        const margin = 8.0;
        final width = math.min(240.0, constraints.maxWidth - margin * 2);
        const itemHeight = FrostMetrics.compactTargetHeight;
        const padding = 6.0;
        final height = math.min(destinations.length * itemHeight + padding * 2, constraints.maxHeight - margin * 2);
        // The shell pads the page by the sidebar; anchor beside the sidebar.
        final left = (buttonRect.right + margin * 2).clamp(margin, constraints.maxWidth - width - margin);
        final top = buttonRect.top.clamp(margin, constraints.maxHeight - height - margin);
        final tokens = FrostThemeTokens.of(dialogContext);

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: width,
              height: height,
              // Grows out of the More button like the other menus; the dialog
              // route supplies the fade.
              child: ScaleTransition(
                alignment: AlignmentDirectional.topStart.resolve(Directionality.of(dialogContext)),
                scale: MediaQuery.disableAnimationsOf(dialogContext)
                    ? kAlwaysCompleteAnimation
                    : ModalRoute.of(
                        dialogContext,
                      )!.animation!.drive(CurveTween(curve: FrostSpringCurve(FrostMotion.snappy, FrostMotion.page))).drive(Tween(begin: .94, end: 1.0)),
                child: FrostSurface(
                  role: FrostSurfaceRole.overlay,
                  borderRadius: BorderRadius.circular(FrostMetrics.groupRadius),
                  child: FocusTraversalGroup(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final (index, destination) in destinations.indexed)
                            SizedBox(
                              height: itemHeight,
                              child: TextButton.icon(
                                autofocus: index == 0,
                                onPressed: () => Navigator.of(dialogContext).pop(index),
                                icon: FrostIcon(destination.icon),
                                label: Text(destination.label),
                                style: TextButton.styleFrom(
                                  alignment: AlignmentDirectional.centerStart,
                                  // The page on screen is marked, since More itself
                                  // is lit while it is one of these.
                                  backgroundColor: selectedIndex == index ? tokens.selectionFill : null,
                                  foregroundColor: selectedIndex == index ? tokens.selectionInk : Theme.of(dialogContext).colorScheme.onSurface,
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.standard,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius - padding + 2)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
  if (context.mounted) buttonFocus.requestFocus();
  if (selected != null && context.mounted) onSelected(selected);
}

/// Page-level Escape: close a sidebar open over the page, then leave a
/// focused text field, then go back one page. Top-level pages have nowhere
/// to go, so the key is left unhandled there.
class _PageBackIntent extends Intent {
  const _PageBackIntent();
}

class _PageBackAction extends Action<_PageBackIntent> {
  _PageBackAction({required this.overlayOpen, required this.closeOverlay, required this.canGoBack, required this.goBack});

  final bool Function() overlayOpen;
  final VoidCallback closeOverlay;
  final bool Function() canGoBack;
  final VoidCallback goBack;

  bool get _editing => FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<EditableTextState>() != null;

  @override
  bool isEnabled(_PageBackIntent intent) => overlayOpen() || _editing || canGoBack();

  @override
  Object? invoke(_PageBackIntent intent) {
    if (overlayOpen()) {
      closeOverlay();
    } else if (_editing) {
      FocusManager.instance.primaryFocus?.unfocus();
    } else {
      goBack();
    }
    return null;
  }
}
