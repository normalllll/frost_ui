import 'package:flutter/widgets.dart';

import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import '../navigation/_navigation_tile.dart';
import '../primitives/_page_outline.dart';
import '_column_split.dart';
import '_local_back.dart';
import 'content_viewport.dart';

/// What a narrow [FrostSettingsSections] shows instead of the split panes.
@immutable
class FrostSectionsCompact {
  const FrostSectionsCompact({this.navigationBuilder, this.section, this.onClose, this.onNavigate});

  /// Replaces only the narrow navigation. Compose grouped settings rows
  /// with current values and badges, and use the same controlled onSelected
  /// callback held by the caller to open each section. Receives finite height.
  final WidgetBuilder? navigationBuilder;

  /// The routed section page, displayed when the split panes cannot fit.
  /// Its own header replaces the shared header. Wide windows keep the
  /// selected pane.
  final Widget? section;

  /// Closes [section] and returns to the narrow navigation. While the section
  /// shows, the shell's Back, system back and the section header's Back (when
  /// the shell does not own Back) call it. When null, Back is left to the
  /// app's routes, as for a section pushed as its own route.
  final VoidCallback? onClose;

  /// Narrow navigation opens a section route instead of replacing a pane.
  /// When omitted, the controlled onSelected callback is used.
  final ValueChanged<int>? onNavigate;
}

/// The next layer inside the selected section on wide windows, such as one
/// source's detail opened from its list. It replaces the selected pane with a
/// pane-only transition while the navigation column stays still; the section
/// content stays mounted underneath and returns with its scroll offset.
/// Narrow windows never show it: there the section is a routed page
/// ([FrostSectionsCompact.section]) and its next layer is a pushed route.
@immutable
class FrostSectionsDetail {
  const FrostSectionsDetail({required this.child, required this.onClose});
  final Widget child;

  /// Closes the detail. The shell's Back, system back and the page header's
  /// Back (when the shell does not own Back) call it while the detail shows,
  /// and so does choosing any section in the navigation column, before
  /// onSelected.
  final VoidCallback onClose;
}

/// A controlled section navigator. Sufficient local space builds the selected
/// content beside a navigation pane of 22% of the width, held between 236 and
/// 320 points, and a hairline, with a 32-point gap to the content keyline and
/// a content limit of 640 points that grows to 800 between widths of 1200 and
/// 1600. The section
/// owns its full-width scroll view; put FrostContentColumn inside that viewport
/// (or FrostSliverContentColumn around slivers) to consume the shared keyline.
/// Its first row aligns with the first navigation row.
/// Narrow available space shows only navigation; [onSelected] should push the
/// corresponding section page. Content is first built on a wide window and
/// stays mounted while that window narrows. Supply a finite-height body.
class FrostSettingsSections extends StatefulWidget {
  const FrostSettingsSections({
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    required this.sectionBuilder,
    this.icons,
    this.header,
    this.status,
    this.compact,
    this.detail,
    super.key,
  }) : assert(icons == null || icons.length == labels.length),
       assert(labels.length == 0 ? selectedIndex == 0 : selectedIndex >= 0 && selectedIndex < labels.length);

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final IndexedWidgetBuilder sectionBuilder;

  /// Optional navigation icons, in exactly the same order as [labels].
  final List<FrostIconData>? icons;

  /// Shared page chrome above navigation and the split panes.
  final Widget? header;

  /// A row kept above the selected section, such as a pending save or a sync
  /// state.
  final Widget? status;

  /// Narrow navigation, routed section page and navigation callback.
  final FrostSectionsCompact? compact;

  /// The next layer inside the selected section on wide windows.
  final FrostSectionsDetail? detail;

  @override
  State<FrostSettingsSections> createState() => _SettingsSectionsState();
}

class _SettingsSectionsState extends State<FrostSettingsSections> with SingleTickerProviderStateMixin {
  bool _builtSection = false;
  final List<FocusNode> _sectionFocus = [];

  // 0 shows the selected section, 1 its detail. The last detail stays built
  // while it animates out.
  late final _layer = AnimationController(vsync: this, value: widget.detail == null ? 0 : 1);
  Widget? _shownDetail;

  @override
  void initState() {
    super.initState();
    _shownDetail = widget.detail?.child;
    _syncFocus();
  }

  void _syncFocus() {
    while (_sectionFocus.length < widget.labels.length) {
      _sectionFocus.add(FocusNode());
    }
    while (_sectionFocus.length > widget.labels.length) {
      _sectionFocus.removeLast().dispose();
    }
  }

  @override
  void didUpdateWidget(FrostSettingsSections oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFocus();
    if (widget.detail case final detail?) _shownDetail = detail.child;
    if ((widget.detail == null) == (oldWidget.detail == null)) return;
    if (widget.detail != null) {
      _layer.duration = FrostMotion.duration(context, FrostMotion.page);
      _layer.forward();
    } else {
      _layer.reverseDuration = FrostMotion.duration(context, FrostMotion.exit);
      _layer.reverse().whenCompleteOrCancel(() {
        if (mounted && widget.detail == null && _layer.isDismissed) setState(() => _shownDetail = null);
      });
    }
  }

  @override
  void dispose() {
    for (final node in _sectionFocus) {
      node.dispose();
    }
    _layer.dispose();
    super.dispose();
  }

  void _select(int index) {
    widget.detail?.onClose();
    widget.onSelected(index);
  }

  /// The selected section with its detail layered above it. The section keeps
  /// one stable slot, so it never rebuilds its State when a detail opens.
  Widget _pane(BuildContext context, int selected) {
    final section = KeyedSubtree(key: ValueKey(selected), child: widget.sectionBuilder(context, selected));
    return AnimatedBuilder(
      animation: _layer,
      child: section,
      builder: (context, section) {
        final reduced = MediaQuery.disableAnimationsOf(context);
        final progress = _layer.value;
        // The same entering and covered motion as ordinary pointer routes,
        // applied to the pane alone.
        final entering = Curves.easeOutCubic.transform(progress);
        final leaving = reduced ? progress : const Interval(0, .5, curve: Curves.easeOutCubic).transform(progress);
        final detail = _shownDetail;
        final opened = widget.detail != null;
        return Stack(
          fit: StackFit.expand,
          children: [
            _layerOf(section!, visible: detail == null || progress < 1, active: !opened, opacity: 1 - leaving, scale: reduced ? 1 : 1 + .02 * entering),
            if (detail != null) _layerOf(detail, visible: progress > 0, active: opened, opacity: entering, scale: reduced ? 1 : .96 + .04 * entering),
          ],
        );
      },
    );
  }

  Widget _layerOf(Widget child, {required bool visible, required bool active, required double opacity, required double scale}) => Offstage(
    offstage: !visible,
    child: TickerMode(
      enabled: visible,
      child: ExcludeFocus(
        excluding: !active,
        child: IgnorePointer(
          ignoring: !active,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.scale(scale: scale, child: child),
          ),
        ),
      ),
    ),
  );

  /// Up and Down (Flutter's directional focus keys) step through the section
  /// list and stop at its ends; other directions keep Flutter's behaviour.
  Object? _moveFocus(DirectionalFocusIntent intent) {
    final delta = switch (intent.direction) {
      TraversalDirection.down => 1,
      TraversalDirection.up => -1,
      _ => 0,
    };
    final index = _sectionFocus.indexWhere((node) => node.hasFocus);
    if (delta == 0 || index < 0) {
      primaryFocus?.focusInDirection(intent.direction);
      return null;
    }
    final target = (index + delta).clamp(0, _sectionFocus.length - 1);
    _sectionFocus[target].requestFocus();
    if (_sectionFocus[target].context case final targetContext?) Scrollable.ensureVisible(targetContext);
    return null;
  }

  // A settings page is width-limited and centred; its panes keep their geometry.
  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: FrostMetrics.settingsMaxWidth),
      child: LayoutBuilder(builder: _layout),
    ),
  );

  Widget _layout(BuildContext context, BoxConstraints constraints) {
    if (widget.labels.isEmpty) return const SizedBox.shrink();
    final wide = frostColumnSplitIsWide(context, constraints.maxWidth);
    _builtSection |= wide;
    final gap = FrostGap.of(context);
    final selected = widget.selectedIndex;
    final compactNavigation = widget.compact?.navigationBuilder;
    final panes = FrostColumnPanes(
      wide: wide,
      width: constraints.maxWidth,
      navigation: !wide && compactNavigation != null
          ? compactNavigation(context)
          : Actions(
              actions: {DirectionalFocusIntent: CallbackAction<DirectionalFocusIntent>(onInvoke: _moveFocus)},
              child: Focus(
                child: ListView.builder(
                  primary: false,
                  padding: EdgeInsets.fromLTRB(
                    wide ? FrostGap.related : gap.page,
                    wide ? 0 : gap.section,
                    (wide ? FrostGap.related : gap.page) + (wide ? 0 : FrostPageOutline.channelOf(context)),
                    // A compact list is the page and ends above a bar over its bottom edge.
                    wide ? 0 : gap.section + MediaQuery.paddingOf(context).bottom,
                  ),
                  itemCount: widget.labels.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: FrostGap.inline),
                    child: FrostNavigationTile(
                      label: widget.labels[index],
                      selected: wide && selected == index,
                      icon: widget.icons?[index],
                      focusNode: _sectionFocus[index],
                      onTap: () => wide ? _select(index) : (widget.compact?.onNavigate ?? widget.onSelected)(index),
                    ),
                  ),
                ),
              ),
            ),
      content: !_builtSection
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.status case final status?) FrostContentColumn(child: status),
                Expanded(child: _pane(context, selected)),
              ],
            ),
    );
    // Only the wide pane shows the detail and only a narrow layout the routed
    // section, so each answers Back only while it shows.
    final detail = wide ? widget.detail : null;
    final section = widget.compact?.section;
    final closeSection = wide || section == null ? null : widget.compact?.onClose;
    Widget? header = widget.header;
    // Without a shell-owned Back, the shared header offers it instead.
    if (detail != null && header != null) header = FrostLocalBack.header(context, detail.onClose, header);
    return FrostLocalBack(
      onClose: detail?.onClose ?? closeSection,
      child: FrostColumnBody(
        wide: wide,
        panes: panes,
        header: header,
        narrowPage: section != null && closeSection != null ? FrostLocalBack.header(context, closeSection, section) : section,
      ),
    );
  }
}
