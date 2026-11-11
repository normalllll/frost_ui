import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:frost_window/frost_window.dart' show FrostCaptionMode;

import '../../controls/_button_control.dart';
import '../../controls/_button_types.dart';
import '../../controls/_toast_viewport.dart';
import '../../controls/buttons.dart';
import '../../controls/caption_search.dart';
import '../../controls/picker_option.dart';
import '../../display/count_badge.dart';
import '../../feedback/_skeleton_geometry.dart';
import '../../foundation/_control_geometry.dart';
import '../../foundation/_page_title_scope.dart';
import '../../foundation/_touch_targets.dart';
import '../../foundation/control_scope.dart';
import '../../foundation/density.dart';
import '../../foundation/icon_data.dart';
import '../../foundation/mask.dart';
import '../../foundation/metrics.dart';
import '../../foundation/radius.dart';
import '../../foundation/scope.dart';
import '../../foundation/sizes.dart';
import '../../foundation/spacing.dart';
import '../../foundation/tokens.dart';
import '../../foundation/typography.dart';
import '../../layout/_caption_search_scope.dart';
import '../../layout/auto_scaffold.dart';
import '../../layout/content_viewport.dart';
import '../../layout/window_caption_scope.dart';
import '../../motion/_layout_identity.dart';
import '../../motion/_material_reveal.dart';
import '../../motion/_selection_feedback.dart';
import '../../motion/layout_crossfade.dart';
import '../../overlays/_popover_surface.dart';
import '../../overlays/_value_picker.dart';
import '../../overlays/overlay_region.dart';
import '../../overlays/panel_action.dart';
import '../../overlays/popover.dart';
import '../../overlays/sheet.dart';
import '../../primitives/_directional_icon.dart';
import '../../primitives/_page_outline.dart';
import '../../primitives/click_surface.dart';
import '../../primitives/divider.dart';
import '../../primitives/glyph.dart';
import '../../primitives/icon.dart' show FrostIcon;
import '../../primitives/surface.dart';
import '../../primitives/text.dart';
import '../_destination_root.dart';
import '../_destination_status.dart';
import '../_navigation_tile.dart';
import '../_shell_back_scope.dart';
import '../_shell_page_title.dart';
import '../_tab_brand.dart';
import '../page_header.dart';
import '../shell_navigation_scope.dart';
import '../shell_tabs.dart';
import '../window_caption.dart';

part 'base_layer.dart';
part 'caption_row.dart';
part 'content_sheet.dart';
part 'destination.dart';
part 'mobile_bar.dart';
part 'sidebar.dart';
part 'task_entry.dart';
part 'task_panel.dart';

enum FrostSidebarAlignment { automatic, top, bottom }

/// One navigation destination: an icon and its caller-owned label.
@immutable
class FrostNavDestination {
  const FrostNavDestination({required this.icon, required this.label, this.badge = 0, this.badgeTone = FrostCountBadgeTone.accent, this.progress, this.builder})
    : assert(progress == null || (progress >= 0 && progress <= 1));

  final FrostIconData icon;
  final String label;

  /// Positive counts appear beside expanded labels or over collapsed icons.
  /// Zero (and negative counts) hide the count; the expanded ring is separate.
  final int badge;

  /// The count's tone: accent for new items, negative for failures. Expanded
  /// rows draw a negative count in negative ink.
  final FrostCountBadgeTone badgeTone;

  /// Determinate status, in 0–1. Only expanded sidebar rows show a ring.
  /// All forms include this value in their caller-localized announcement.
  final double? progress;

  /// Wraps the shared navigation target in every rendered navigation form.
  /// Use a stable wrapper to measure an animation destination or add local
  /// confirmation feedback. Preserve [child] so activation, status and semantics
  /// continue through the shared implementation. Hidden More-menu rows are not
  /// wrapped; a destination with no visible target has no measurement anchor.
  final Widget Function(BuildContext context, Widget child)? builder;
}

class _DestinationItem extends StatelessWidget {
  const _DestinationItem({required this.destination, required this.child});
  final FrostNavDestination destination;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    // One destination remains one semantic target in indexed lists, a
    // bottom-aligned scroll view and the bottom bar alike.
    final item = Semantics(
      container: true,
      child: FrostDestinationStatus(badge: destination.badge, badgeTone: destination.badgeTone, progress: destination.progress, child: child),
    );
    return destination.builder?.call(context, item) ?? item;
  }
}

// Sidebar geometry, the same in every app. The expanded width follows the
// longest destination label within these bounds (see _expandedWidth).
const _railWidth = 60.0;
const _expandedMinWidth = 176.0;
const _expandedMaxWidth = 240.0;
const _expandableMinWidth = 1200.0;

/// Compact content size-class boundary. Navigation placement is decided
/// independently by navigationPlacement and its automatic input/aspect policy.
const _mobileMaxWidth = 600.0;

/// Destinations kept off the phone's bottom bar: the More menu while the
/// sidebar is collapsed, a separate group below the destinations while it is
/// expanded. The collapsed More button carries their counts together and
/// announces them with their progress; its menu states each one in words.
@immutable
class FrostShellSecondary {
  const FrostShellSecondary({required this.destinations, required this.onSelected, this.selectedIndex});

  final List<FrostNavDestination> destinations;

  /// The secondary destination the current page belongs to, if any. With an
  /// optional base tab, supply it even while content tabs are in front; see
  /// [FrostShell.selectedIndex]. While it is set the sidebar highlights no
  /// primary destination.
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
}

/// The App's identity in the shell.
@immutable
class FrostShellBrand {
  const FrostShellBrand({this.expanded, this.icon, this.label});

  /// The full identity in the client title row, or beside Back in an expanded
  /// sidebar when the native host owns the title controls. Hosts without a
  /// window caption use the same sidebar placement.
  final Widget? expanded;

  /// Compact identity. In base-tab mode this is the base tab's icon, also
  /// shown in the tab overview; the caption has no separate brand icon.
  final Widget? icon;

  /// App name announced for the compact caption icon. The base tab combines it
  /// with its current destination title. Defaults to the enclosing WidgetsApp
  /// Title when present; supply this for a standalone shell.
  final String? label;
}

/// The app's navigation shell: a desktop sidebar (or a phone bottom bar)
/// around the current page. Routing stays in the app; the shell reports
/// selections and owns page-level Back. Keys stay with the app: the shell binds
/// none, and Escape is the app's to map. Desktop platforms keep one
/// Back control beside the brand in an available client title row. Native
/// window controls and hosts without a client title row use the sidebar header:
/// fixed Back on the navigation icon axis, with the brand revealed on expansion.
/// Bottom navigation keeps Back in the content page header.
///
/// The sidebar is 60 wide collapsed. From a 1200-wide window it may expand
/// beside the page, as wide as the longest destination label needs (with its
/// icon and room for a two-digit count) between 176 and 240; longer labels end
/// in an ellipsis. Counts and progress do not change the width.
class FrostShell extends StatefulWidget {
  const FrostShell({
    required this.destinations,
    required this.selectedIndex,
    required this.atDestinationRoot,
    required this.onDestinationSelected,
    required this.canGoBack,
    required this.onBack,
    required this.showsMobileNavigation,
    required this.child,
    this.secondary,
    this.initiallyExpanded = false,
    this.onExpandedChanged,
    this.brand,
    this.titleBarContent,
    this.titleBarSearch,
    this.titleBarSearchPlacement = FrostCaptionSearchPlacement.center,
    this.tabs,
    this.navigationPlacement,
    this.sidebarAlignment = FrostSidebarAlignment.automatic,
    this.routeDepth = 0,
    this.backToFirst,
    this.taskEntry,
    super.key,
  }) : assert(routeDepth >= 0);

  /// Empty for a page that stands alone, such as a start-up or sign-in page:
  /// with no secondary destinations either, the shell draws no sidebar or bottom
  /// bar, only the window's title row with the page below it.
  final List<FrostNavDestination> destinations;

  /// The primary destination the current page belongs to, if any. With an
  /// optional base tab, supply that tab's destination even while content tabs
  /// are in front. The sidebar then clears its highlight and activates the base
  /// before dispatching a destination change; returning to the same destination
  /// preserves its stack without invoking [onDestinationSelected].
  ///
  /// On a secondary page, keep the destination that opened it: the bottom bar
  /// under the page highlights it while the page moves in and out. The sidebar,
  /// which lists the secondary destinations too, highlights only the selected
  /// [FrostShellSecondary.selectedIndex].
  final int? selectedIndex;

  /// Whether the current page is the selected destination's own root page,
  /// with nothing pushed above it. Selecting that destination again then
  /// signals [FrostShellNavigationScope.primaryReselection] (scroll to top,
  /// refresh) instead of navigating. The sidebar highlights a destination only
  /// on its root page; the bottom bar keeps [selectedIndex] on every page.
  final bool atDestinationRoot;

  /// Called after the shell has removed, with no exit motion, every page and
  /// modal above the [FrostShellDestination] page. Change the selected index here.
  final ValueChanged<int> onDestinationSelected;

  /// Destinations in the More menu (collapsed) or the secondary group
  /// (expanded). Not shown on the phone's bottom bar.
  final FrostShellSecondary? secondary;

  /// Whether Back has somewhere to go: a pushed page or a parent location.
  final bool canGoBack;
  final VoidCallback onBack;

  /// Whether destination pages provide mobile navigation. Place one
  /// [FrostShellDestination] inside the content Navigator's retained root page.
  /// Secondary routes cover that page; [atDestinationRoot] does not hide the bar.
  final bool showsMobileNavigation;

  /// The saved choice of an expanded sidebar where the window makes room for
  /// it. Read once; the shell then owns the choice and reports changes
  /// through [onExpandedChanged].
  final bool initiallyExpanded;

  /// Called when the user expands or collapses the sidebar beside the page.
  /// Collapsing forced by a narrow window is not a choice and is not reported.
  final ValueChanged<bool>? onExpandedChanged;

  final FrostShellBrand? brand;

  /// Interactive title content, outside native drag regions and controls. It
  /// shows in the client title row of a sidebar layout when there is room. It is
  /// hidden otherwise, keeping its state, and returns when room does: place the
  /// page's own entry by [titleContentInCaptionOf]. Keep search state/controllers
  /// in the app. An open suggestion list closes while the content is hidden and
  /// returns with it.
  final Widget? titleBarContent;

  /// A search for the title row, usually a [FrostCaptionSearch] with any wrapper
  /// around it. Placed as [titleBarContent], but with the search geometry:
  /// a fixed resting width that folds to an icon, and room to expand. The title
  /// row has one content slot: passing this and [titleBarContent] throws.
  final Widget? titleBarSearch;

  /// Where [titleBarSearch] sits in the title row.
  final FrostCaptionSearchPlacement titleBarSearchPlacement;

  /// The pages. Retain the destinations in an [IndexedStack] or
  /// [FrostLazyIndexedStack] and select one by changing its index: the shell
  /// shows the change on the next frame, with no transition.
  final Widget child;
  final FrostShellTabs<Object>? tabs;
  final FrostNavigationPlacement? navigationPlacement;
  final FrostSidebarAlignment sidebarAlignment;
  final int routeDepth;

  /// Offered by page headers in bottom navigation from [routeDepth] 2.
  final FrostShellBackToFirst? backToFirst;

  /// A persistent app entry, such as downloads: at the bottom of the sidebar,
  /// or a draggable button over the content with the bottom bar. Null leaves
  /// the shell as it is without one.
  final FrostShellTaskEntry? taskEntry;

  /// Whether the title content of the enclosing shell is in its title row right
  /// now. When it is not, the page provides its own entry. False outside a shell.
  static bool titleContentInCaptionOf(BuildContext context) {
    final placement = context.dependOnInheritedWidgetOfExactType<_TitleContentPlacement>();
    return placement != null && placement.inCaption;
  }

  @override
  State<FrostShell> createState() => _FrostShellState();
}

class _TitleContentPlacement extends InheritedWidget {
  const _TitleContentPlacement({required this.inCaption, required super.child});
  final bool inCaption;
  @override
  bool updateShouldNotify(_TitleContentPlacement oldWidget) => inCaption != oldWidget.inCaption;
}

class _FrostShellState extends State<FrostShell> with SingleTickerProviderStateMixin {
  final _overlayBounds = FrostOverlayBounds();
  final _layoutIdentity = FrostLayoutIdentity();
  final _scaffoldKey = GlobalKey();
  final _pageKey = GlobalKey();
  final _titleContentKey = GlobalKey();
  final _pageTitle = FrostShellPageTitle();
  late final AnimationController _sidebarProgress = AnimationController(vsync: this, value: widget.initiallyExpanded ? 1 : 0);
  final FocusNode _moreButtonFocus = FocusNode(debugLabel: 'More navigation');
  final ValueNotifier<({int index, int sequence})> _primaryReselection = ValueNotifier((index: 0, sequence: 0));
  final _barExtent = _BarExtent();
  final _tabsOverviewKey = GlobalKey();
  final _destinationRoute = _DestinationRoute();

  /// Whether a popup route (sheet, dialog) is open in the content Navigator.
  bool _contentModal = false;

  /// Where the floating task entry rests for this run.
  FrostFloatingEntryPosition? _floatingPosition;

  /// A content Navigator's stack changed. Frost modals open on the root
  /// Navigator and cover the shell's own route instead; the layer sees those.
  bool _contentNavigated(NavigationNotification notification) {
    if (widget.taskEntry == null) return false;
    final modal = _contentModalOpen();
    if (modal != _contentModal) setState(() => _contentModal = modal);
    return false;
  }

  /// Whether a popup route is on top of the destination page's Navigator or a
  /// Navigator around it inside the content.
  bool _contentModalOpen() {
    final outer = Navigator.maybeOf(context);
    var navigator = _destinationRoute.value?.navigator;
    while (navigator != null && navigator != outer && navigator.mounted) {
      Route<Object?>? top;
      // Reads the top present route; a predicate that holds pops nothing.
      navigator.popUntil((route) {
        top = route;
        return true;
      });
      if (top is PopupRoute) return true;
      navigator = navigator.context.findAncestorStateOfType<NavigatorState>();
    }
    return false;
  }

  void _setFloatingPosition(FrostFloatingEntryPosition position) {
    if (position == _floatingPosition) return;
    // A panel closed by the shell's own removal still reports its move.
    if (mounted) {
      setState(() => _floatingPosition = position);
    } else {
      _floatingPosition = position;
    }
    widget.taskEntry?.onFloatingPositionChanged?.call(position);
  }

  /// The user's choice where the sidebar sits beside the page.
  late bool _expandedBeside = widget.initiallyExpanded;

  /// Whether the window made room for an expanded sidebar at the last
  /// layout; null before the first one.
  bool? _besidePage;

  /// The progress to draw until a layout switch lands on the controller.
  double? _settledProgress;

  bool get _expandedTarget => (_besidePage ?? true) && _expandedBeside;

  void _toggleExpansion() {
    _expandedBeside = !_expandedBeside;
    widget.onExpandedChanged?.call(_expandedBeside);
    _springToTarget();
  }

  void _springToTarget() {
    // One spring drives the width, the content start and every label, so
    // they stay in step; a toggle mid-way turns back at the current speed
    // instead of restarting.
    FrostMotion.springTo(context, _sidebarProgress, _expandedTarget ? 1.0 : 0.0, FrostMotion.standard);
  }

  /// Follows the window across the width that makes room for the sidebar.
  /// The switch jumps rather than animates, so the sidebar tracks a resize.
  void _updateBesidePage(bool besidePage) {
    if (_besidePage == besidePage) return;
    final first = _besidePage == null;
    _besidePage = besidePage;
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

  /// The primary destination the page belongs to; none on a secondary page,
  /// whose opener [FrostShell.selectedIndex] names only for the bottom bar.
  int? get _currentPrimary => widget.secondary?.selectedIndex != null ? null : widget.selectedIndex;

  void _selectIndex(int index) {
    final tabs = widget.tabs?.controller;
    if (tabs?.baseTab != null && !tabs!.isBaseTabActive) {
      tabs.activate(0);
      // Returning from a content tab to the same destination must preserve the
      // base tab's route stack and scroll. Reselection applies on the next tap.
      if (index == _currentPrimary) return;
      _destinationRoute.clearPagesAbove();
      widget.onDestinationSelected(index);
      return;
    }
    if (index == _currentPrimary && widget.atDestinationRoot) {
      _primaryReselection.value = (index: index, sequence: _primaryReselection.value.sequence + 1);
      return;
    }
    _destinationRoute.clearPagesAbove();
    widget.onDestinationSelected(index);
  }

  /// The secondary group as the sidebar shows it. Like a primary destination, it
  /// is current only with the base tab in front and selecting it brings that tab
  /// forward; returning to the same one preserves the base tab's route stack.
  FrostShellSecondary? _sidebarSecondary() {
    final secondary = widget.secondary;
    if (secondary == null) return null;
    final tabs = widget.tabs?.controller;
    final contentInFront = tabs?.baseTab != null && !tabs!.isBaseTabActive;
    return FrostShellSecondary(
      destinations: secondary.destinations,
      selectedIndex: contentInFront || !widget.atDestinationRoot ? null : secondary.selectedIndex,
      onSelected: (index) {
        if (contentInFront) {
          tabs.activate(0);
          if (index == secondary.selectedIndex) return;
        }
        _destinationRoute.clearPagesAbove();
        secondary.onSelected(index);
      },
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overlayBounds.setParent(FrostOverlayRegionData.maybeOf(context));
  }

  @override
  void dispose() {
    _pageTitle.dispose();
    _overlayBounds.dispose();
    _layoutIdentity.dispose();
    _sidebarProgress.dispose();
    _moreButtonFocus.dispose();
    _primaryReselection.dispose();
    _barExtent.dispose();
    super.dispose();
  }

  EdgeInsets _frame(BuildContext context) {
    final safe = MediaQuery.paddingOf(context);
    // System insets are often fractional; whole physical pixels keep the
    // page's pinned glass edges (and joins between them) crisp.
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    double snap(double value) => (value * pixelRatio).roundToDouble() / pixelRatio;
    // The sidebar lies on the reading start, so it takes the inset of that side.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return EdgeInsets.fromLTRB(rtl ? 0 : snap(safe.left), snap(safe.top), rtl ? snap(safe.right) : 0, snap(safe.bottom));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.titleBarContent != null && widget.titleBarSearch != null) {
      throw FlutterError('FrostShell has one title row slot: pass titleBarContent or titleBarSearch, not both.');
    }
    return FrostTabBrand(icon: widget.brand?.icon, name: _brandLabel(context), child: _buildShell(context));
  }

  String? _brandLabel(BuildContext context) => widget.brand?.label ?? context.findAncestorWidgetOfExactType<Title>()?.title;

  /// The expanded sidebar width: what the longest destination label needs
  /// beside its icon, in the label's own style and text scale, with room for
  /// a two-digit count after it, rounded up to a whole point and kept within
  /// the bounds. Counts and progress never enter it, so the sidebar keeps its
  /// width while they change. The second value tells whether the cap cut a
  /// label short.
  (double, bool) _expandedWidth(BuildContext context) {
    final style = FrostTypography.of(context).style(FrostTextRole.callout);
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    var widest = 0.0;
    // Labels only: a destination's current count or ring must not resize the
    // sidebar and reflow the page.
    for (final destination in [...widget.destinations, ...?widget.secondary?.destinations]) {
      final painter = TextPainter(
        text: TextSpan(text: destination.label, style: style),
        textScaler: scaler,
        textDirection: direction,
        maxLines: 1,
      )..layout();
      widest = math.max(widest, painter.width);
      painter.dispose();
    }
    final content = widest + FrostDestinationTrailing.countReserveOf(context);
    final row = FrostNavigationTile.expandedWidthFor(iconAxis: _railWidth / 2 - _SidebarNavigation._innerPadding, content: content);
    final needed = (row + 2 * _SidebarNavigation._innerPadding).ceilToDouble();
    return (needed.clamp(_expandedMinWidth, _expandedMaxWidth), needed > _expandedMaxWidth);
  }

  /// The sidebar footer: the task entry above the touch tabs overview. Without
  /// a task entry it is the tabs overview alone, as before. The overview keeps
  /// its State when the entry comes or goes.
  Widget? _sidebarFooter({required double progress, required bool bottomAligned, required Widget? tabsOverview}) {
    final overview = tabsOverview == null ? null : KeyedSubtree(key: _tabsOverviewKey, child: tabsOverview);
    final entry = widget.taskEntry;
    if (entry == null) return overview;
    final slot = _SidebarTaskSlot(entry: entry, progress: progress, reservesRoom: bottomAligned, gapBelow: overview != null);
    if (overview == null) return slot;
    return Column(mainAxisSize: MainAxisSize.min, children: [slot, overview]);
  }

  Widget _buildShell(BuildContext context) {
    return FrostAutoScaffold(
      navigationPlacement: widget.navigationPlacement,
      mobileBreakpoint: _mobileMaxWidth,
      builder: (context, layout, orientation, useHorizontalLayout) {
        // Capture the previous painted coordinates before updating the one live
        // subtree. Only a layout change fades; a selected destination appears on
        // its first frame.
        _layoutIdentity.update(useHorizontalLayout, viewport: layout.size);
        final hasNavigation = widget.destinations.isNotEmpty || (widget.secondary?.destinations.isNotEmpty ?? false);
        final besidePage = hasNavigation && useHorizontalLayout && layout.width >= _expandableMinWidth;
        _updateBesidePage(besidePage);
        final (expandedWidth, ellipsizesLabels) = _expandedWidth(context);
        final showSidebar = useHorizontalLayout && hasNavigation;
        final fullscreen = FrostWindowCaptionScope.stateOf(context)?.fullscreen ?? false;
        final hasCaption = FrostWindowCaptionScope.windowOf(context) != null && !fullscreen;
        final captionState = FrostWindowCaptionScope.stateOf(context);
        final nativeControls = captionState?.nativeControls ?? Rect.zero;
        final controlHeight = frostControlTextGeometry(
          baseHeight: FrostDensity.of(context).controlHeight,
          style: FrostTypography.of(context).style(FrostTextRole.callout),
          textScaler: MediaQuery.textScalerOf(context),
        ).height;
        final buttons = ((captionState?.leftButtons.length ?? 0) + (captionState?.rightButtons.length ?? 0)) * FrostCaptionMetrics.buttonWidth;
        final titleRoom = layout.width - buttons - nativeControls.width - _railWidth - expandedWidth - FrostGap.section;
        final titleRowHeight = math.max(
          _shellCaptionHeight,
          widget.tabs == null ? FrostDensity.of(context).controlHeight : math.max(FrostDensity.of(context).targetHeight, controlHeight),
        );
        // Only a sidebar layout has title content in its row, so this agrees with
        // FrostAutoScaffold.usesHorizontalLayoutOf: a phone-like page owns its entry.
        final titleInCaption = hasCaption && useHorizontalLayout && (widget.tabs != null || titleRoom >= 320) && controlHeight <= titleRowHeight;
        final titleWidget = widget.titleBarSearch ?? widget.titleBarContent;
        final titleContent = titleWidget == null ? null : KeyedSubtree(key: _titleContentKey, child: titleWidget);
        final usesCaptionNavigation =
            hasCaption && (captionState?.mode == FrostCaptionMode.client || captionState?.mode == FrostCaptionMode.nativeControls || widget.tabs != null);
        final touch = !FrostDensity.of(context).usesPointer;
        // Without a title row (a full-screen iPad, an Android tablet) a sidebar
        // layout gets a top bar of the same shape, without window buttons. A
        // full-screen window stays immersive.
        final syntheticCaption = !hasCaption && useHorizontalLayout && (widget.tabs != null || hasNavigation && !fullscreen);
        // macOS windows carry no app icon or name, as Finder and System Settings,
        // and a tablet's top bar none either; the tab strip keeps its brand.
        final captionBrand = captionState?.mode == FrostCaptionMode.nativeControls || syntheticCaption && widget.tabs == null ? null : widget.brand?.expanded;
        // The title row names the visible page; tabs name their own pages.
        final showsPageTitle = (usesCaptionNavigation || syntheticCaption) && useHorizontalLayout && widget.tabs == null;
        final showCaption = hasCaption || syntheticCaption;
        final captionInset = syntheticCaption ? MediaQuery.paddingOf(context).top : 0.0;
        final bottomAligned = widget.sidebarAlignment == FrostSidebarAlignment.bottom || widget.sidebarAlignment == FrostSidebarAlignment.automatic && touch;
        final floatingTask = !useHorizontalLayout && widget.showsMobileNavigation && widget.taskEntry != null;
        // The native-controls strip contains no app navigation. Keep its normal
        // 28px height, but grow for actual AppKit geometry rather than clipping it.
        final captionHeight = syntheticCaption && widget.tabs == null
            ? math.max(titleRowHeight, FrostDensity.of(context).targetHeight)
            : widget.tabs != null
            ? math.max(titleRowHeight, nativeControls.isEmpty ? 0.0 : nativeControls.bottom + FrostGap.inline)
            : captionState?.mode == FrostCaptionMode.nativeControls && widget.tabs == null && !useHorizontalLayout && !(titleInCaption && titleContent != null)
            ? math.max(_nativeCaptionHeight, nativeControls.isEmpty ? 0.0 : nativeControls.bottom + FrostGap.inline)
            : titleInCaption && titleContent != null
            ? titleRowHeight
            : widget.tabs != null
            ? titleRowHeight
            : captionState?.mode == FrostCaptionMode.nativeControls
            ? math.max(_shellCaptionHeight, nativeControls.isEmpty ? 0.0 : nativeControls.bottom + FrostGap.inline)
            : _shellCaptionHeight;
        return FrostOverlayRegionData(
          bounds: _overlayBounds,
          child: _FrostDestinationNavigation(
            route: _destinationRoute,
            enabled: !useHorizontalLayout && widget.showsMobileNavigation && widget.destinations.isNotEmpty,
            navigation: _MobileNavBar(
              destinations: widget.destinations,
              selectedIndex: widget.selectedIndex,
              onDestinationSelected: _selectIndex,
              extent: _barExtent,
            ),
            child: FrostShellBackHost(
              canGoBack: widget.canGoBack,
              onBack: widget.onBack,
              builder: (context, canGoBack, goBack) => FrostShellNavigationScope(
                ownsBackControl: useHorizontalLayout,
                routeDepth: widget.routeDepth,
                backToFirst: widget.backToFirst,
                canGoBack: canGoBack,
                goBack: goBack,
                primaryReselection: _primaryReselection,
                child: _TitleContentPlacement(
                  inCaption: titleContent != null && (titleInCaption || syntheticCaption),
                  child: FrostLayoutCrossfade(
                    layoutIdentity: _layoutIdentity,
                    child: _ShellBase(
                      enabled: useHorizontalLayout,
                      child: Scaffold(
                        key: _scaffoldKey,
                        backgroundColor: useHorizontalLayout ? Colors.transparent : FrostThemeTokens.of(context).canvas,
                        // The shell never shrinks for the keyboard: the sidebar
                        // stays put. Destination pages own mobile navigation; pages
                        // keep avoiding it through their own Scaffolds.
                        resizeToAvoidBottomInset: false,
                        extendBody: false,
                        body: AnimatedBuilder(
                          animation: Listenable.merge([_sidebarProgress, ?widget.tabs?.controller]),
                          builder: (context, _) {
                            final progress = besidePage ? (_settledProgress ?? _sidebarProgress.value) : 0.0;
                            final railWidth = lerpDouble(_railWidth, expandedWidth, progress)!;
                            final frame = _frame(context);
                            final rtl = Directionality.of(context) == TextDirection.rtl;
                            // Native window controls stay above application
                            // navigation; the sidebar header shares its icon axis.
                            final sidebarTop = (showCaption ? captionHeight : 0.0) + math.max(frame.top, !hasCaption ? FrostGap.related : 0.0);
                            // Only positioned layers: the Stack must take the body size.
                            return Stack(
                              fit: StackFit.expand,
                              children: [
                                // Pages start beside the sidebar so it never covers
                                // their hit targets. The tree keeps one shape so a
                                // fold or resize that switches layouts keeps state.
                                Positioned.fill(
                                  left: showSidebar && !rtl ? frame.left + railWidth : 0,
                                  top: showCaption
                                      ? captionHeight + captionInset
                                      : showSidebar
                                      ? sidebarTop
                                      : 0,
                                  right: showSidebar && rtl ? frame.right + railWidth : 0,
                                  bottom: showSidebar ? FrostGap.related : 0,
                                  child: MediaQuery.removePadding(
                                    context: context,
                                    removeLeft: showSidebar && !rtl,
                                    removeRight: showSidebar && rtl,
                                    removeTop: showSidebar,
                                    child: FrostCaptionClearance(
                                      child: _ContentSheet(
                                        enabled: showSidebar,
                                        radius: FrostRadius.borderRadius(FrostRadius.lg),
                                        child: FrostContentViewport(
                                          key: _pageKey,
                                          navigationReserve: besidePage ? expandedWidth - railWidth : 0,
                                          child: FrostOverlayRegionGeometry(
                                            onChanged: _overlayBounds.update,
                                            child: FrostToastViewport(
                                              key: const ValueKey('frost-toast-viewport'),
                                              child: Column(
                                                children: [
                                                  // Out of the row the content keeps its state and
                                                  // focus, and takes no room or Tab stop.
                                                  if (!titleInCaption && !syntheticCaption && titleContent != null)
                                                    Offstage(
                                                      child: TickerMode(
                                                        enabled: false,
                                                        child: FocusTraversalGroup(descendantsAreTraversable: false, child: titleContent),
                                                      ),
                                                    ),
                                                  Expanded(
                                                    child: NotificationListener<NavigationNotification>(
                                                      onNotification: _contentNavigated,
                                                      child: FrostShellPageTitleScope(title: showsPageTitle ? _pageTitle : null, child: widget.child),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (showSidebar)
                                  Positioned(
                                    left: rtl ? null : frame.left,
                                    right: rtl ? frame.right : null,
                                    top: sidebarTop,
                                    bottom: frame.bottom,
                                    width: railWidth,
                                    // Paints nothing. The sidebar that opened over the page
                                    // drew its shadow here; keeping the box keeps the render
                                    // tree the constructor baselines recorded for the inset
                                    // sidebar.
                                    child: DecoratedBox(
                                      decoration: const BoxDecoration(),
                                      child: _SidebarNavigation(
                                        destinations: widget.destinations,
                                        selectedIndex: widget.tabs?.controller.baseTab != null && !widget.tabs!.controller.isBaseTabActive
                                            ? null
                                            : widget.atDestinationRoot
                                            ? _currentPrimary
                                            : null,
                                        secondary: _sidebarSecondary(),
                                        expandedWidth: expandedWidth,
                                        ellipsizesLabels: ellipsizesLabels,
                                        progress: progress,
                                        bottomAligned: bottomAligned,
                                        footer: _sidebarFooter(
                                          progress: progress,
                                          bottomAligned: bottomAligned,
                                          tabsOverview: touch && widget.tabs != null
                                              ? Builder(
                                                  builder: (context) {
                                                    final tabs = widget.tabs!;
                                                    final label = (tabs.sidebarLabel ?? tabs.countLabel)(tabs.controller.length);
                                                    void open() => tabs.showOverview(context);
                                                    return Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: _SidebarNavigation._innerPadding),
                                                      child: Semantics(
                                                        key: const ValueKey('frost-shell-tabs-overview'),
                                                        button: true,
                                                        label: label,
                                                        onTap: open,
                                                        // This count is tabs, not the unread count announced
                                                        // by ordinary destination badges. Own its semantics.
                                                        excludeSemantics: true,
                                                        child: FrostDestinationStatus(
                                                          badge: progress < .5 ? tabs.controller.length : 0,
                                                          badgeTone: FrostCountBadgeTone.neutral,
                                                          progress: null,
                                                          child: FrostNavItem(
                                                            label: label,
                                                            icon: FrostIconSet.of(context).multiPage,
                                                            selected: false,
                                                            progress: progress,
                                                            onTap: open,
                                                          ),
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                )
                                              : null,
                                        ),
                                        header: usesCaptionNavigation || syntheticCaption
                                            ? null
                                            : _SidebarHeader(
                                                expandedWidth: expandedWidth,
                                                progress: progress,
                                                brand: widget.brand?.expanded,
                                                onBack: canGoBack ? goBack : null,
                                              ),
                                        controls: _SidebarToggle(expanded: _expandedTarget, onToggle: besidePage ? _toggleExpansion : null),
                                        onDestinationSelected: _selectIndex,
                                        moreButtonFocus: _moreButtonFocus,
                                      ),
                                    ),
                                  ),
                                if (showCaption)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: captionInset,
                                    height: captionHeight,
                                    child: _CaptionRow(
                                      titleContent: titleInCaption || syntheticCaption ? titleContent : null,
                                      tabs: useHorizontalLayout ? widget.tabs : null,
                                      brandIcon: widget.brand?.icon,
                                      expandsSearch: widget.titleBarSearch != null,
                                      searchAtEnd: widget.titleBarSearchPlacement == FrostCaptionSearchPlacement.end,
                                      brandLabel: _brandLabel(context),
                                      iconAxis: (rtl ? frame.right : frame.left) + _railWidth / 2,
                                      nativeCaption: hasCaption,
                                      showsBack: (usesCaptionNavigation || syntheticCaption) && useHorizontalLayout,
                                      onBack: canGoBack ? goBack : null,
                                      brand: usesCaptionNavigation || syntheticCaption ? captionBrand : null,
                                      pageTitle: showsPageTitle ? _pageTitle : null,
                                    ),
                                  ),
                                // Above the content Navigator, so pushed
                                // routes that cover the bar keep the entry.
                                if (floatingTask)
                                  Positioned.fill(
                                    child: _FloatingTaskLayer(
                                      key: const ValueKey('frost-shell-floating-task'),
                                      entry: widget.taskEntry!,
                                      position: _floatingPosition ??= widget.taskEntry!.initialFloatingPosition,
                                      barExtent: _barExtent,
                                      onPositionChanged: _setFloatingPosition,
                                      covered: _contentModal,
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
