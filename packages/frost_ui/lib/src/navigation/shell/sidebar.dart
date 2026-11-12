part of 'shell.dart';

class _SidebarNavigation extends StatelessWidget {
  const _SidebarNavigation({
    required this.destinations,
    required this.selectedIndex,
    required this.secondary,
    required this.expandedWidth,
    required this.ellipsizesLabels,
    required this.progress,
    required this.controls,
    this.header,
    this.footer,
    this.bottomAligned = false,

    required this.onDestinationSelected,
    required this.moreButtonFocus,
  });

  final List<FrostNavDestination> destinations;
  final int? selectedIndex;
  final FrostShellSecondary? secondary;
  final double expandedWidth;

  /// Whether the expanded width was capped below the longest label.
  final bool ellipsizesLabels;
  final double progress;
  final Widget controls;
  final Widget? header, footer;
  final bool bottomAligned;

  final ValueChanged<int> onDestinationSelected;
  final FocusNode moreButtonFocus;

  static const _innerPadding = 8.0;
  // Keep the final destination clear of the fading edge in short windows.
  static const _navigationScrollTailSpace = 88.0;

  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    final secondaryDestinations = secondary?.destinations ?? const <FrostNavDestination>[];
    final selectedSecondaryIndex = secondary?.selectedIndex;
    final Widget? secondaryGroup = secondaryDestinations.isEmpty
        ? null
        : Stack(
            alignment: AlignmentDirectional.topStart,
            children: [
              IgnorePointer(
                ignoring: progress > .25,
                child: ExcludeFocus(
                  excluding: progress > .25,
                  child: Opacity(
                    opacity: (1 - progress * 4).clamp(0.0, 1.0),
                    child: Builder(
                      builder: (buttonContext) {
                        void open() => _showMore(buttonContext, secondaryDestinations, selectedSecondaryIndex, secondary!.onSelected, moreButtonFocus);
                        return Actions(
                          actions: {ActivateIntent: CallbackAction<ActivateIntent>(onInvoke: (_) => open())},
                          child: Focus(
                            focusNode: moreButtonFocus,
                            skipTraversal: true,
                            child: _MoreStatus(
                              destinations: secondaryDestinations,
                              child: FrostNavItem(
                                label: labels.more,
                                icon: icons.more,
                                selected: selectedSecondaryIndex != null,
                                progress: progress,
                                onTap: open,
                              ),
                            ),
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
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: FrostGap.group),
                              child: FrostDivider(),
                            ),
                            const SizedBox(height: FrostGap.related),
                            for (final (index, destination) in secondaryDestinations.indexed) ...[
                              _DestinationItem(
                                destination: destination,
                                child: FrostNavItem(
                                  label: destination.label,
                                  icon: destination.icon,
                                  selected: selectedSecondaryIndex == index,
                                  progress: progress,
                                  labelOpacity: ((progress - .85) / .15).clamp(0.0, 1.0),
                                  onTap: () => secondary!.onSelected(index),
                                ),
                              ),
                              const SizedBox(height: FrostGap.inline),
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
    return _SidebarIconAxis(
      value: _railWidth / 2 - _innerPadding,
      itemWidth: expandedWidth - 2 * _innerPadding,
      ellipsizes: ellipsizesLabels,
      child: MediaQuery.removePadding(
        context: context,
        removeLeft: Directionality.of(context) == TextDirection.ltr,
        removeRight: Directionality.of(context) == TextDirection.rtl,
        removeTop: true,
        removeBottom: true,
        child: Padding(
          padding: const EdgeInsets.only(bottom: FrostGap.related),
          child: Column(
            children: [
              ?header,
              const SizedBox(height: 6),
              Expanded(
                child: _EdgeFadeScrollView(
                  bottomAligned: bottomAligned, // The list spans the whole panel so an item can mark its
                  // selection on the panel edge; the items keep the inset.
                  padding: const EdgeInsets.fromLTRB(_innerPadding, 0, _innerPadding, _navigationScrollTailSpace),
                  children: [
                    for (var index = 0; index < destinations.length; index++) ...[
                      if (index > 0) const SizedBox(height: 6),
                      _DestinationItem(
                        destination: destinations[index],
                        child: FrostNavItem(
                          label: destinations[index].label,
                          icon: destinations[index].icon,
                          selected: selectedIndex == index,
                          progress: progress,
                          onTap: () => onDestinationSelected(index),
                        ),
                      ),
                    ],
                    if (secondaryGroup != null) ...[
                      // Same rhythm as the primary items while collapsed; the
                      // expanded secondary group gets room for its divider.
                      SizedBox(height: lerpDouble(4, 16, progress)),
                      secondaryGroup,
                    ],
                  ],
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SizedBox(
                  width: _railWidth,
                  child: Center(child: controls),
                ),
              ),
              ?footer,
            ],
          ),
        ),
      ),
    );
  }
}

/// What the destinations behind the More button report, on the button: their
/// counts together, in the negative tone if any failure is among them, and their
/// average progress.
class _MoreStatus extends StatelessWidget {
  const _MoreStatus({required this.destinations, required this.child});
  final List<FrostNavDestination> destinations;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final counted = destinations.where((destination) => destination.badge > 0);
    final progress = [for (final destination in destinations) ?destination.progress];
    return FrostDestinationStatus(
      badge: counted.fold(0, (sum, destination) => sum + destination.badge),
      badgeTone: counted.any((destination) => destination.badgeTone == FrostCountBadgeTone.negative)
          ? FrostCountBadgeTone.negative
          : FrostCountBadgeTone.accent,
      progress: progress.isEmpty ? null : progress.reduce((a, b) => a + b) / progress.length,
      dot: true,
      child: child,
    );
  }
}

/// Short-height windows scroll the navigation list without a scrollbar; the
/// edges fade so clipped items read as more content rather than a cut.
class _EdgeFadeScrollView extends StatefulWidget {
  const _EdgeFadeScrollView({required this.children, this.padding = EdgeInsets.zero, this.bottomAligned = false});
  final bool bottomAligned;

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
          child: !widget.bottomAligned
              ? ListView(primary: false, padding: widget.padding, children: widget.children)
              : LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    primary: false,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Padding(
                        padding: widget.padding.copyWith(bottom: FrostGap.related),
                        child: Column(mainAxisAlignment: MainAxisAlignment.end, crossAxisAlignment: CrossAxisAlignment.stretch, children: widget.children),
                      ),
                    ),
                  ),
                ),
        ),
      ),
    );
    return _EdgeFadeMask(
      fades: _fadeTop || _fadeBottom,
      shader: (bounds) {
        final edge = (_fadeExtent / math.max(1.0, bounds.height)).clamp(0.0, .5);
        return LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_fadeTop ? frostClear : FrostMask.opaque, FrostMask.opaque, FrostMask.opaque, _fadeBottom ? frostClear : FrostMask.opaque],
          stops: [0, edge, 1 - edge, 1],
        ).createShader(bounds);
      },
      child: list,
    );
  }
}

/// A mask that is in the tree whether or not it fades, so the list under it keeps
/// its state and focus as the fades come and go. It takes a layer only to fade.
class _EdgeFadeMask extends SingleChildRenderObjectWidget {
  const _EdgeFadeMask({required this.fades, required this.shader, required super.child});
  final bool fades;
  final ShaderCallback shader;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEdgeFadeMask(shader, fades);

  @override
  void updateRenderObject(BuildContext context, _RenderEdgeFadeMask renderObject) => renderObject
    ..shaderCallback = shader
    ..fades = fades;
}

class _RenderEdgeFadeMask extends RenderShaderMask {
  _RenderEdgeFadeMask(ShaderCallback shader, this._fades) : super(shaderCallback: shader, blendMode: BlendMode.dstIn);
  bool _fades;
  set fades(bool value) {
    if (value == _fades) return;
    _fades = value;
    markNeedsCompositingBitsUpdate();
    markNeedsPaint();
  }

  @override
  bool get alwaysNeedsCompositing => _fades && super.alwaysNeedsCompositing;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_fades) return super.paint(context, offset);
    layer = null;
    if (child case final child?) context.paintChild(child, offset);
  }
}

/// Navigation destination: a square icon tile that expands into a labelled
/// row; selection fills it. One animation progress drives size, positions
/// and the state marks so nothing jumps.
class FrostNavItem extends StatelessWidget {
  const FrostNavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
    this.progress = 0,
    this.labelOpacity = 1,
    super.key,
  });

  final String label;
  final FrostIconData icon;
  final bool selected;
  final double progress;
  final double labelOpacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Widget item = FrostNavigationTile(
      label: label,
      icon: icon,
      selected: selected,
      onTap: onTap,
      progress: progress,
      labelOpacity: labelOpacity,
      iconAxis: _SidebarIconAxis.maybeOf(context) ?? 24,
      physicalIconAxis: _SidebarIconAxis.maybeOf(context) != null,
      expandedLayoutWidth: _SidebarIconAxis.itemWidthOf(context),
      labelOverflow: _SidebarIconAxis.ellipsizesOf(context) ? TextOverflow.ellipsis : TextOverflow.fade,
    );
    return onTap == null ? ExcludeFocus(child: Opacity(opacity: .38, child: item)) : item;
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
  await showFrostValueSheet<int>(
    context: context,
    title: FrostScope.labelsOf(context).more,
    items: [
      for (final (index, destination) in destinations.indexed)
        FrostPickerOption(
          value: index,
          label: destination.label,
          leading: FrostGlyph.icon(destination.icon),
          subtitle: FrostDestinationStatus.describe(context, destination.badge, destination.progress),
        ),
    ],
    value: selectedIndex,
    onSelected: onSelected,
  );
  if (context.mounted && buttonFocus.canRequestFocus) buttonFocus.requestFocus();
}

// Internal metadata keeps the icons on one stationary axis and the expanded
// rows on the width the sidebar chose for its labels.
class _SidebarIconAxis extends InheritedWidget {
  const _SidebarIconAxis({required this.value, required this.itemWidth, required this.ellipsizes, required super.child});
  final double value, itemWidth;

  /// Whether labels end in an ellipsis: the width was capped below the longest.
  final bool ellipsizes;
  static double? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SidebarIconAxis>()?.value;
  static double? itemWidthOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SidebarIconAxis>()?.itemWidth;
  static bool ellipsizesOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SidebarIconAxis>()?.ellipsizes ?? false;
  @override
  bool updateShouldNotify(_SidebarIconAxis oldWidget) => value != oldWidget.value || itemWidth != oldWidget.itemWidth || ellipsizes != oldWidget.ellipsizes;
}
