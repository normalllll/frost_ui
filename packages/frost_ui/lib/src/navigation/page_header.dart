import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../controls/_toolbar_geometry.dart';
import '../foundation/_page_title_scope.dart';
import '../foundation/_touch_targets.dart';
import '../foundation/control_scope.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/_caption_search_scope.dart';
import '../layout/_header_row_span.dart';
import '../layout/_header_search_scope.dart';
import '../layout/auto_scaffold.dart';
import '../layout/column_placement.dart';
import '../layout/content_viewport.dart';
import '../primitives/_directional_icon.dart';
import '../primitives/_page_outline.dart';
import '../primitives/keyline.dart';
import '../primitives/text.dart';
import '_page_header_leading.dart';
import '_shell_back_scope.dart';
import '_toolbar_middle_scope.dart';
import 'back_to_first_button.dart';
import 'shell_navigation_scope.dart';
import 'toolbar.dart';
import 'toolbar_menu_button.dart';
import 'window_caption.dart';

/// Collapses a page header's expanded search from the App, for example after a
/// submitted query navigates. Cancel, system Back and Escape collapse it too.
class FrostPageHeaderSearchController extends ChangeNotifier {
  bool _expanded = false;
  _PageHeaderState? _header;

  /// Whether the header's search field currently covers its row.
  bool get expanded => _expanded;

  /// Restores the header row, keeping the query. Focus returns to where it was
  /// before the search took it.
  void collapse() => _header?._collapse();

  void _set(bool value) {
    if (_expanded == value) return;
    _expanded = value;
    notifyListeners();
  }
}

/// Page-owned navigation, title and actions in one adaptive toolbar row.
///
/// When [middle] holds a [FrostSearchInput] and the row cannot give it the
/// caption search's expanded width beside the other content, focusing the field
/// expands it over the whole row: leading, controls and actions fade out and
/// leave focus and semantics, and a Cancel text button appears at the end.
/// Cancel, Escape and system Back collapse it, keeping the query; submitting
/// does not, so an App that navigates after a query collapses it through
/// [searchController]. Rows with enough room keep their layout.
class FrostPageHeader extends StatefulWidget {
  const FrostPageHeader({
    this.leading = const [],
    this.leadingIcons = const [],
    this.controls = const [],
    this.title,
    this.middle,
    this.collapsedMiddle,
    this.actions = const [],
    this.onBack,
    this.searchController,
    super.key,
  });

  /// Natural-width controls after automatic back and before the title. Leading
  /// menus truncate before a source/title menu; trailing actions keep their own
  /// width. Truncated menus retain full tooltips and semantic labels.
  final List<Widget> leading;

  /// Bare icon targets after the back button, as [FrostToolbar.leadingIcons].
  final List<Widget> leadingIcons;

  /// Priority-aware choices after leading content; shares overflow with actions.
  /// Flexible search fields continue to use [middle].
  final List<FrostToolbarItem> controls;

  /// The middle slot grows up to 360. A header in search mode, one with a
  /// [searchController], lets it grow up to 640. Header height and
  /// action/overflow rules are the same in both.
  final Widget? title, middle, collapsedMiddle;
  final List<FrostToolbarItem> actions;
  final VoidCallback? onBack;

  /// Optional handle to read or collapse the expanded search.
  final FrostPageHeaderSearchController? searchController;
  static const horizontalHeight = 52.0;
  static const verticalHeight = 48.0;

  /// The Back control for a page header, or null when the page has none.
  /// While another page route moves over the page, a page that had Back keeps
  /// it, inert, so Back fades with the page; a page drawing its own Back from a
  /// non-null result should not act on it while [ModalRoute.isCurrentOf] is
  /// false. Under a popup or a covering page at rest there is none.
  static Widget? leadingFor(BuildContext context, {VoidCallback? onBack}) {
    if (FrostPageHeaderLeading.of(context) case final override?) return override.leading;
    final navigation = FrostShellNavigationScope.maybeOf(context);
    if (navigation?.ownsBackControl ?? false) return null;
    var route = ModalRoute.of(context);
    if (navigation != null) {
      // A retained branch can remain current in its own Navigator while an
      // enclosing page is covered. Only the visible chain owns shell Back.
      // While a route moves over the page, a page that had Back keeps it,
      // inert, so Back fades with the page instead of leaving first.
      final visited = <ModalRoute<Object?>>{};
      var covered = false, below = false;
      while (route != null && visited.add(route)) {
        if (!route.isCurrent) {
          if (!(route.secondaryAnimation?.isAnimating ?? false)) return null;
          covered = true;
        }
        if (!route.isFirst) below = true;
        final owner = route.navigator;
        route = owner == null ? null : ModalRoute.of(owner.context);
      }
      if (!navigation.canGoBack || covered && !below) return null;
      final back = FrostCompactBackButton(onPressed: navigation.goBack);
      return covered ? IgnorePointer(child: ExcludeFocus(child: back)) : back;
    }
    if (onBack != null) return FrostCompactBackButton(onPressed: onBack);
    final navigator = Navigator.maybeOf(context);
    final ownRoute = ModalRoute.of(context);
    final dismisses = ownRoute?.impliesAppBarDismissal ?? navigator?.canPop() ?? false;
    return navigator != null && dismisses ? FrostCompactBackButton(onPressed: () => navigator.maybePop()) : null;
  }

  @override
  State<FrostPageHeader> createState() => _PageHeaderState();
}

class _PageHeaderState extends State<FrostPageHeader> with SingleTickerProviderStateMixin {
  final _row = GlobalKey(), _field = GlobalKey(), _slot = GlobalKey();
  final _room = FrostToolbarMiddleRoom();
  late final _expansion = AnimationController(vsync: this);
  FocusNode? _search;

  /// A template placing section tabs in this row, if any.
  FrostHeaderRowSpan? _rowSpan;
  var _expanded = false;
  var _rest = Rect.zero;

  @override
  void initState() {
    super.initState();
    widget.searchController?._header = this;
  }

  @override
  void didUpdateWidget(FrostPageHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchController != widget.searchController) {
      if (oldWidget.searchController?._header == this) oldWidget.searchController!._header = null;
      // A controller handed over during build starts with the current state.
      widget.searchController
        ?.._header = this
        .._expanded = _expanded;
    }
    if (widget.middle == null && _expanded) {
      // Nothing is left to cover the row; restore it without a transition.
      _expanded = false;
      _expansion.value = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.searchController?._set(false);
        _rowSpan?.expanded = false;
      });
    }
  }

  @override
  void dispose() {
    if (widget.searchController?._header == this) widget.searchController!._header = null;
    if (_expanded) _rowSpan?.expanded = false;
    _expansion.dispose();
    super.dispose();
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject(), row = _row.currentContext?.findRenderObject();
    if (box is! RenderBox || row is! RenderBox || !box.hasSize || !box.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: row) & box.size;
  }

  void _focused(FocusNode node) {
    _search = node;
    // The caption search's expanded width: a row that already gives the field
    // that much room beside its other content keeps its layout.
    if (_expanded || _room.width >= frostCaptionSearchExpandedWidth) return;
    // Refocusing during the collapse keeps the slot captured when it began.
    if (_expansion.value == 0) _rest = _rectOf(_field) ?? Rect.zero;
    setState(() => _expanded = true);
    widget.searchController?._set(true);
    // A header row above section tabs stays shown while its search is open.
    _rowSpan?.expanded = true;
    _expansion.animateTo(1, duration: FrostMotion.duration(context, FrostMotion.standardDuration), curve: FrostMotion.hoverCurve);
  }

  void _collapse() {
    if (!_expanded || !mounted) return;
    _rest = _rectOf(_slot) ?? _rest;
    setState(() => _expanded = false);
    widget.searchController?._set(false);
    _rowSpan?.expanded = false;
    // As the caption search: return focus to where it was before the search.
    if (_search case final search? when search.hasFocus) search.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    _expansion.animateBack(0, duration: FrostMotion.duration(context, FrostMotion.standardDuration), curve: FrostMotion.hoverCurve);
  }

  @override
  Widget build(BuildContext context) {
    _rowSpan = FrostHeaderRowSpanScope.read(context);
    final height = FrostSizeClass.of(context) != FrostSizeClass.compact ? FrostPageHeader.horizontalHeight : FrostPageHeader.verticalHeight;
    final scaler = MediaQuery.textScalerOf(context);
    final back = FrostPageHeader.leadingFor(context, onBack: widget.onBack);
    final shell = FrostShellNavigationScope.maybeOf(context);
    final secondary = back != null || (shell?.canGoBack ?? false);
    final titleRole = secondary ? FrostTextRole.headline : FrostTextRole.title1;
    final headline = FrostTypography.of(context).style(titleRole);
    final fontSize = headline.fontSize!;
    final extraLine = (scaler.scale(fontSize) - fontSize * 1.3) * headline.height!;
    final scales = extraLine > 0;
    final title = widget.title;
    final field = widget.middle == null
        ? null
        : KeyedSubtree(
            key: _field,
            child: FrostHeaderSearchScope(expanded: _expanded, row: _row, onFocused: _focused, onDismissed: _collapse, child: widget.middle!),
          );
    Widget row = AnimatedBuilder(
      animation: _expansion,
      builder: (context, _) {
        final progress = _expansion.value;
        final covered = field != null && (_expanded || progress > 0);
        // The resting row stays laid out underneath: the header keeps its
        // height and the field returns to the very same slot.
        final toolbar = FrostToolbar(
          leadingIcons: [?back, if (back != null && (shell?.showsBackToFirst ?? false)) const FrostBackToFirstButton(), ...widget.leadingIcons],
          leading: widget.leading,
          // A bare FrostText title takes the page-title role. A composed title
          // (a column with a source line, say) keeps the roles it names: the
          // header is a fixed row, so a larger title would overflow it.
          title: title is FrostText ? FrostPageTitleScope(role: titleRole, child: title) : title,
          controls: widget.controls,
          middle: covered ? SizedBox(key: _slot, height: _rest.height) : field,
          collapsedMiddle: widget.collapsedMiddle,
          trailing: widget.actions,
        );
        return Stack(
          key: _row,
          // The toolbar keeps the constraints it had before the search layer.
          fit: StackFit.passthrough,
          // Cancel's press plate bleeds past the content edge.
          clipBehavior: Clip.none,
          children: [
            ExcludeSemantics(
              excluding: covered,
              // Traversal, not ExcludeFocus: the field is still in this subtree
              // when the row is first covered, and excluding focus here would
              // drop its focus before it moves to the search layer.
              child: FocusTraversalGroup(
                descendantsAreTraversable: !covered,
                child: IgnorePointer(
                  ignoring: covered,
                  child: TickerMode(
                    enabled: progress < 1,
                    child: Opacity(
                      opacity: 1 - progress,
                      child: FrostToolbarMiddleRoomScope(
                        room: _room,
                        child: FrostToolbarMiddleWidthScope(
                          maxWidth: widget.searchController == null ? frostToolbarMiddleMaxWidth : frostToolbarSearchMiddleMaxWidth,
                          child: toolbar,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (covered)
              Positioned.fill(
                child: _ExpandedSearch(progress: progress, rest: _rest, expanded: _expanded, onCancel: _collapse, field: field),
              ),
          ],
        );
      },
    );
    final keyline = FrostKeyline.maybeOf(context);
    if (keyline == null || keyline.insideContainer) {
      final inset = FrostGap.of(context).page;
      row = FrostKeyline(
        leadingRoom: inset,
        trailingRoom: inset,
        edgeDistanceStart: inset,
        edgeDistanceEnd: inset,
        insideContainer: false,
        contentStart: inset,
        child: Padding(
          padding: EdgeInsets.only(left: inset, right: inset + FrostPageOutline.channelOf(context)),
          child: row,
        ),
      );
    }
    // Back first restores the row, whether it comes from the system or from a
    // shell-owned title-bar Back; the next Back leaves the page.
    return FrostShellBackTarget(
      enabled: _expanded && (shell?.ownsBackControl ?? false),
      onBack: _collapse,
      child: PopScope<void>(
        canPop: !_expanded,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _collapse();
        },
        child: FrostNativeCaptionPadding(
          child: DefaultTextStyle(
            style: headline.copyWith(color: FrostThemeTokens.of(context).textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: scales ? height + extraLine : height, maxHeight: scales ? double.infinity : height),
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}

enum _ExpandedPart { field, cancel }

/// The search field over the whole row with Cancel at its end. The field moves
/// here from the toolbar slot with its State, so editing and focus continue.
class _ExpandedSearch extends StatelessWidget {
  const _ExpandedSearch({required this.progress, required this.rest, required this.expanded, required this.onCancel, required this.field});
  final double progress;
  final Rect rest;
  final bool expanded;
  final VoidCallback onCancel;
  final Widget field;
  @override
  Widget build(BuildContext context) => FrostControlScope(
    // The same control context the field had in the toolbar slot.
    size: FrostControlSize.compact,
    toolbar: true,
    child: Material(
      type: MaterialType.transparency,
      child: CustomMultiChildLayout(
        delegate: _ExpandedSearchLayout(progress: progress, rest: rest, direction: Directionality.of(context), bleed: FrostGap.of(context).hitInset),
        children: [
          LayoutId(id: _ExpandedPart.field, child: field),
          LayoutId(
            id: _ExpandedPart.cancel,
            child: Opacity(
              opacity: progress,
              child: IgnorePointer(
                ignoring: !expanded,
                child: ExcludeSemantics(
                  excluding: !expanded,
                  // Cancel never takes focus, and a tap on it is not a tap
                  // outside the field: focus can still return to where it was
                  // before the search. Keyboard users press Escape.
                  child: ExcludeFocus(
                    child: TextFieldTapRegion(
                      child: FrostToolbarEdge(
                        trailing: true,
                        child: FrostToolbarControl(label: FrostScope.labelsOf(context).cancel, onPressed: onCancel),
                      ),
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

class _ExpandedSearchLayout extends MultiChildLayoutDelegate {
  _ExpandedSearchLayout({required this.progress, required this.rest, required this.direction, required this.bleed});
  final double progress;
  final Rect rest;
  final TextDirection direction;

  /// Cancel's own text inset. Its press plate bleeds by this much so the text
  /// ends on the content edge, like the suggestion groups' title actions below.
  /// The expanded field is a container too: its edge reaches the same line.
  final double bleed;
  @override
  void performLayout(Size size) {
    final cancel = layoutChild(_ExpandedPart.cancel, BoxConstraints.loose(size));
    final ltr = direction == TextDirection.ltr;
    final width = math.max(0.0, size.width + bleed - (cancel.width - bleed) - FrostGap.related);
    final full = Rect.fromLTWH(ltr ? -bleed : size.width - width + bleed, rest.top, width, rest.height);
    final rect = Rect.lerp(rest, full, progress)!;
    final field = layoutChild(_ExpandedPart.field, BoxConstraints(minWidth: rect.width, maxWidth: rect.width, maxHeight: size.height));
    // Both stay on the resting field's centre line.
    final center = rest.isEmpty ? size.height / 2 : rest.center.dy;
    positionChild(_ExpandedPart.field, Offset(rect.left, center - field.height / 2));
    positionChild(_ExpandedPart.cancel, Offset(ltr ? size.width - cancel.width + bleed : -bleed, center - cancel.height / 2));
  }

  @override
  bool shouldRelayout(_ExpandedSearchLayout oldDelegate) =>
      progress != oldDelegate.progress || rest != oldDelegate.rest || direction != oldDelegate.direction || bleed != oldDelegate.bleed;
}

class FrostCompactBackButton extends StatelessWidget {
  const FrostCompactBackButton({required this.onPressed, super.key});
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => FrostTouchTarget(
    enabled: onPressed != null && FrostControlScope.enabledOf(context),
    child: FrostToolbarControl(label: FrostScope.labelsOf(context).back, icon: frostBackIcon(context), showsLabel: false, onPressed: onPressed),
  );
}

/// A page title that sits in the content column it is placed in, at the same
/// edges and width as the content below it.
class FrostInlinePageHeading extends StatelessWidget {
  const FrostInlinePageHeading({required this.title, this.actions = const [], super.key});
  final String title;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => FrostContentColumn(
    maxWidth: FrostPageColumnWidth.of(context),
    child: Padding(
      padding: const EdgeInsets.only(top: FrostGap.inline),
      child: Row(
        children: [
          Expanded(
            child: FrostText(title, role: FrostTextRole.title1, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          ...actions,
        ],
      ),
    ),
  );
}
