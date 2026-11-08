part of 'shell.dart';

// A shared title-row height aligns navigation with or without native actions.
const _shellCaptionHeight = 40.0;
const _nativeCaptionHeight = 28.0;

class _CaptionRow extends StatelessWidget {
  const _CaptionRow({
    required this.iconAxis,
    required this.nativeCaption,
    required this.showsBack,
    required this.onBack,
    this.brand,
    this.titleContent,
    this.brandIcon,
    this.brandLabel,
    this.expandsSearch = false,
    this.searchAtEnd = false,
    this.tabs,
  });
  final double iconAxis;
  final bool nativeCaption, showsBack, expandsSearch, searchAtEnd;
  final Widget? brand, titleContent, brandIcon;
  final String? brandLabel;
  final FrostShellTabs<Object>? tabs;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    Widget drag(Widget child) => nativeCaption ? FrostCaptionRegion(kind: FrostHitKind.caption, child: child) : child;
    final state = FrostWindowCaptionScope.stateOf(context);
    final rightButtons = nativeCaption && ((state?.failed ?? false) || (state?.rightButtons.isNotEmpty ?? true));
    if (state?.mode == FrostCaptionMode.nativeControls && titleContent == null && tabs == null) {
      // AppKit excludes its own buttons from native dragging. The remaining
      // strip is a single drag region, including empty space around the buttons.
      return Row(
        children: [
          Expanded(child: drag(const SizedBox.expand())),
          if (state!.failed) const FrostCaptionButtons(),
        ],
      );
    }
    // Native window buttons keep the sides the platform put them on. Between
    // them the row follows the reading direction, like the sidebar below it.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final leftButtons = nativeCaption && (state?.leftButtons.isNotEmpty ?? false);
    final endButtons = rtl ? leftButtons : rightButtons;
    return FrostNativeCaptionPadding(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final flow = <Widget>[
            if (showsBack)
              tabs != null && tabs!.hasVisibleTabs
                  ? Padding(
                      padding: const EdgeInsets.symmetric(horizontal: FrostGap.related),
                      child: _ShellCaptionBack(width: math.max(40, FrostDensity.of(context).targetHeight), onBack: onBack),
                    )
                  : _ShellCaptionBack(width: iconAxis * 2, onBack: onBack),
            if (tabs != null || expandsSearch)
              Expanded(
                child: _TabbedCaptionContent(
                  tabs: tabs,
                  // The window centre, measured from the content's left edge.
                  searchCenter:
                      constraints.maxWidth / 2 -
                      (showsBack && !rtl
                          ? (tabs != null && tabs!.hasVisibleTabs ? 16 + math.max(40, FrostDensity.of(context).targetHeight) : iconAxis * 2)
                          : 0) -
                      (nativeCaption ? (state?.leftButtons.length ?? 0) * FrostCaptionMetrics.buttonWidth : 0),
                  brand: brand,
                  brandIcon: brandIcon,
                  brandLabel: brandLabel,
                  titleContent: titleContent,
                  nativeCaption: nativeCaption,
                  searchAtEnd: searchAtEnd,
                  // Match the leading clearance of Back in either caption mode.
                  endInset: endButtons
                      ? FrostGap.related
                      : tabs != null && tabs!.hasVisibleTabs
                      ? FrostGap.related + math.max(0, FrostDensity.of(context).targetHeight - 40) / 2
                      : math.max(FrostGap.related, iconAxis - _shellCaptionHeight / 2),
                ),
              )
            else ...[
              Expanded(child: drag(_CaptionBrand(child: brand))),
              if (titleContent != null) ...[
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: constraints.maxWidth * .45),
                  child: FrostCaptionRegion(
                    kind: FrostHitKind.client,
                    child: Center(child: titleContent),
                  ),
                ),
                SizedBox(width: FrostGap.section, child: drag(const SizedBox.expand())),
              ],
            ],
          ];
          return Row(
            textDirection: TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (leftButtons) const FrostCaptionButtons(side: FrostCaptionSide.left),
              ...(rtl ? flow.reversed : flow),
              if (rightButtons) const FrostCaptionButtons(),
            ],
          );
        },
      ),
    );
  }
}

// The App's brand in whatever slot the shell gives it, start-aligned and
// vertically centred. It gets the slot's width but never less than its own
// minimum width, so text still ellipsizes in a short slot while an ordinary
// icon-and-text Row never overflows: a slot narrower than that minimum clips
// the brand at its end edge, and its last few points fade it out, while a
// caption or sidebar animates the room away.
class _CaptionBrand extends SingleChildRenderObjectWidget {
  const _CaptionBrand({super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCaptionBrand(Directionality.of(context));
  @override
  void updateRenderObject(BuildContext context, _RenderCaptionBrand renderObject) => renderObject.direction = Directionality.of(context);
}

class _RenderCaptionBrand extends RenderShiftedBox {
  _RenderCaptionBrand(this._direction) : super(null);
  static const _fade = 24.0;
  TextDirection _direction;
  set direction(TextDirection value) {
    if (_direction == value) return;
    _direction = value;
    markNeedsLayout();
  }

  final _clip = LayerHandle<ClipRectLayer>();
  final _opacity = LayerHandle<OpacityLayer>();

  @override
  void performLayout() {
    final brand = child;
    if (brand == null) {
      size = constraints.smallest;
      return;
    }
    final height = constraints.maxHeight;
    final minimum = _floor(brand, height.isFinite ? height : double.infinity);
    brand.layout(BoxConstraints(maxWidth: math.max(constraints.maxWidth, minimum), maxHeight: height), parentUsesSize: true);
    size = constraints.constrain(Size(constraints.hasBoundedWidth ? constraints.maxWidth : brand.size.width, height.isFinite ? height : brand.size.height));
    final x = _direction == TextDirection.ltr ? 0.0 : size.width - brand.size.width;
    (brand.parentData! as BoxParentData).offset = Offset(x, (size.height - brand.size.height) / 2);
  }

  // The narrowest width the brand lays out in without overflowing. A
  // horizontal Row shrinks its flexible children (an ellipsized name) to
  // nothing but keeps every rigid one, such as an icon or an unwrapped name;
  // other brands keep their minimum intrinsic width.
  static double _floor(RenderBox box, double height) {
    if (box is RenderProxyBox && box.child != null) return _floor(box.child!, height);
    if (box is RenderFlex && box.direction == Axis.horizontal) {
      var width = 0.0, count = 0;
      for (var child = box.firstChild; child != null; child = box.childAfter(child)) {
        final flex = (child.parentData! as FlexParentData).flex ?? 0;
        if (flex == 0) width += child.getMaxIntrinsicWidth(height);
        count++;
      }
      return width + box.spacing * math.max(0, count - 1);
    }
    return box.getMinIntrinsicWidth(height);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final brand = child;
    if (brand == null) return;
    final alpha = (size.width / _fade).clamp(0.0, 1.0);
    if (alpha == 0) {
      _opacity.layer = null;
      _clip.layer = null;
      return;
    }
    void paintClipped(PaintingContext context, Offset offset) {
      final overflows = brand.size.width > size.width;
      _clip.layer = context.pushClipRect(
        needsCompositing,
        offset,
        Offset.zero & size,
        (context, offset) => context.paintChild(brand, offset + (brand.parentData! as BoxParentData).offset),
        clipBehavior: overflows ? Clip.hardEdge : Clip.none,
        oldLayer: _clip.layer,
      );
    }

    if (alpha == 1) {
      _opacity.layer = null;
      paintClipped(context, offset);
    } else {
      _opacity.layer = context.pushOpacity(offset, (alpha * 255).round(), paintClipped, oldLayer: _opacity.layer);
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) =>
      size.width > 0 && (Offset.zero & size).contains(position) && super.hitTestChildren(result, position: position);

  @override
  void dispose() {
    _clip.layer = null;
    _opacity.layer = null;
    super.dispose();
  }
}

// Kept outside the destinations' scroll view and the page subtree. A fixed
// expanded brand layout is clipped/revealed by the existing sidebar animation;
// neither the Back target nor text reflows during expansion.
class _SidebarHeader extends StatelessWidget {
  const _SidebarHeader({required this.expandedWidth, required this.progress, required this.onBack, this.brand});
  final double expandedWidth;
  final double progress;
  final VoidCallback? onBack;
  final Widget? brand;

  @override
  Widget build(BuildContext context) {
    final amount = progress.clamp(0.0, 1.0);
    final height = frostControlTextGeometry(
      baseHeight: math.max(_shellCaptionHeight, FrostDensity.of(context).controlHeight),
      style: FrostTypography.of(context).style(FrostTextRole.callout),
      textScaler: MediaQuery.textScalerOf(context),
    ).height;
    return SizedBox(
      height: height,
      child: ClipRect(
        child: OverflowBox(
          alignment: AlignmentDirectional.centerStart,
          minWidth: expandedWidth,
          maxWidth: expandedWidth,
          child: Row(
            children: [
              SizedBox(
                width: _railWidth,
                child: Center(
                  child: FrostButton.icon(
                    key: const ValueKey('frost-shell-back'),
                    label: FrostScope.labelsOf(context).back,
                    icon: frostBackIcon(context),
                    onPressed: onBack,
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: FrostGap.related),
                  child: ExcludeSemantics(
                    excluding: amount < .5,
                    child: ExcludeFocus(
                      excluding: amount < 1,
                      child: IgnorePointer(
                        ignoring: amount < 1,
                        child: Opacity(
                          opacity: amount,
                          child: _CaptionBrand(child: brand),
                        ),
                      ),
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

// Kept outside the destinations' scroll view and the page subtree.
class _SidebarToggle extends StatelessWidget {
  const _SidebarToggle({required this.expanded, required this.onToggle});
  final bool expanded;
  final VoidCallback? onToggle;
  @override
  Widget build(BuildContext context) {
    final labels = FrostScope.labelsOf(context);
    final icons = FrostIconSet.of(context);
    final extent = math.max(_shellCaptionHeight, FrostDensity.of(context).targetHeight);
    return SizedBox(
      width: extent,
      height: extent,
      child: FrostButton.icon(
        label: expanded ? labels.collapseNavigation : labels.expandNavigation,
        icon: expanded ? icons.sidebarCollapse : icons.sidebarExpand,
        onPressed: onToggle,
      ),
    );
  }
}

// Geometry-only override: feedback, colours and 140 ms transitions stay shared.
class _ShellCaptionBack extends StatelessWidget {
  const _ShellCaptionBack({required this.width, required this.onBack});
  final double width;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => FrostTouchTarget(
    // A pointer density gets the same target from the click surface.
    enabled: onBack != null && !FrostDensity.of(context).usesPointer,
    child: SizedBox(
      width: width,
      height: _shellCaptionHeight,
      child: FrostButtonControl(
        key: const ValueKey('frost-shell-back'),
        label: FrostScope.labelsOf(context).back,
        icon: frostBackIcon(context),
        iconStyle: FrostIconButtonStyle.plain,
        onPressed: onBack,
        geometry: const FrostButtonGeometry(
          // Navigation keeps ordinary rounded feedback; only native caption actions are square.
          horizontalInset: 0,
          verticalInset: 0,
          minimumWidth: _shellCaptionHeight,
          alignment: MainAxisAlignment.center,
          visualHeight: _shellCaptionHeight,
          maximumHitHeight: _shellCaptionHeight,
          iconSize: 20,
          edgeBleed: 0,
        ),
      ),
    ),
  );
}

// Collapse navigation chrome before taking room from the content or native
// actions. The search subtree is retained; a FrostSearchEntry collapses itself
// at the supplied icon width. App-owned tab/controller state never moves here.
class _TabbedCaptionContent extends StatefulWidget {
  const _TabbedCaptionContent({
    required this.tabs,
    required this.brand,
    required this.brandIcon,
    required this.titleContent,
    required this.nativeCaption,
    required this.searchAtEnd,
    required this.endInset,
    required this.searchCenter,
    this.brandLabel,
  });
  final FrostShellTabs<Object>? tabs;
  final Widget? brand, brandIcon, titleContent;
  final String? brandLabel;
  final bool nativeCaption, searchAtEnd;
  final double endInset, searchCenter;
  @override
  State<_TabbedCaptionContent> createState() => _TabbedCaptionContentState();
}

class _TabbedCaptionContentState extends State<_TabbedCaptionContent> {
  bool _searchExpanded = false;
  void _expandSearch(bool expanded) {
    if (mounted && expanded != _searchExpanded) setState(() => _searchExpanded = expanded);
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs, brand = widget.brand, brandIcon = widget.brandIcon, titleContent = widget.titleContent;
    final nativeCaption = widget.nativeCaption, endInset = widget.endInset;
    return LayoutBuilder(
      builder: (context, constraints) {
        final scaler = MediaQuery.textScalerOf(context);
        final scale = scaler.scale(14) / 14;
        final tabCount = tabs?.controller.length ?? 0;
        final hasTabs = tabs?.hasVisibleTabs ?? false;
        final baseWidth = tabs?.controller.baseTab == null ? 0.0 : constraints.maxHeight;
        final contentCount = tabCount - (baseWidth > 0 ? 1 : 0);
        final count = tabs?.countLabel(contentCount) ?? '';
        final painter = TextPainter(
          text: TextSpan(text: count, style: FrostTypography.of(context).style(FrostTextRole.callout)),
          textScaler: scaler,
          textDirection: Directionality.of(context),
        )..layout();
        final countWidth = painter.width + 48;
        painter.dispose();
        var brandWidth = baseWidth > 0
            ? 0.0
            : hasTabs
            ? (brandIcon == null ? 0.0 : 24.0)
            : (brand == null ? 0.0 : 160.0 * scale);
        final tabActionWidth = tabs?.canCreateTab == true ? math.max(40.0, FrostDensity.of(context).targetHeight) : 0.0;
        var tabWidth = !hasTabs ? 0.0 : contentCount * frostShellTabMinWidth * scale + baseWidth + tabActionWidth;
        var searchWidth = titleContent == null ? 0.0 : (widget.searchAtEnd ? frostCaptionSearchEndWidth : frostCaptionSearchWidth);
        var fullTabs = hasTabs, fullBrand = !hasTabs;
        double anchorEnd() {
          if (widget.searchAtEnd) return endInset;
          // The row flows with the text, so its end is the left edge in RTL; the
          // centre is always measured from the left.
          final toEnd = Directionality.of(context) == TextDirection.ltr ? constraints.maxWidth - widget.searchCenter : widget.searchCenter;
          final candidate = math.max(endInset, toEnd - searchWidth / 2);
          return constraints.maxWidth - searchWidth - candidate >= baseWidth + 44 ? candidate : endInset;
        }

        double gaps() => (brandWidth > 0 ? FrostGap.related : 0.0) + anchorEnd();
        double needed() => brandWidth + tabWidth + searchWidth + gaps();
        if (needed() > constraints.maxWidth && hasTabs) {
          fullTabs = false;
          tabWidth = baseWidth + countWidth;
        }
        if (needed() > constraints.maxWidth && searchWidth > 0) searchWidth = math.max(44, FrostDensity.of(context).targetHeight);
        if (needed() > constraints.maxWidth && brandWidth > 0) {
          fullBrand = false;
          brandWidth = brandIcon == null ? 0 : 28;
        }
        // Below the usable caption minimum, native actions and Back still win.
        // The sidebar overview and keyboard shortcuts keep tabs reachable.
        if (needed() > constraints.maxWidth) brandWidth = 0;
        if (needed() > constraints.maxWidth && hasTabs) tabWidth = math.min(tabWidth, math.max(0, constraints.maxWidth - searchWidth - gaps()));
        if (baseWidth > 0 && tabWidth < baseWidth + 44) {
          fullTabs = false;
          tabWidth = baseWidth;
        } else if (tabWidth < 44) {
          tabWidth = 0;
        }
        if (needed() > constraints.maxWidth) searchWidth = math.max(0, constraints.maxWidth - tabWidth - gaps());
        if (fullTabs) {
          // Folding tests the minimum, but visible tabs consume spare room before
          // leaving a drag spacer. The strip itself caps each tab at its maximum.
          tabWidth = math.min(
            contentCount * frostShellTabMaxWidth + baseWidth + tabActionWidth,
            math.max(0.0, constraints.maxWidth - brandWidth - searchWidth - gaps()),
          );
        }
        final searchEnd = anchorEnd();
        Widget client(Widget child) => FrostCaptionRegion(kind: FrostHitKind.client, child: child);
        Widget drag(Widget child) => nativeCaption ? FrostCaptionRegion(kind: FrostHitKind.caption, child: child) : child;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              children: [
                if (brandWidth > 0)
                  SizedBox(
                    // A full brand takes all the room beside the search; the drag
                    // region stays continuous.
                    width: fullBrand && !hasTabs
                        ? math.max(brandWidth, constraints.maxWidth - tabWidth - searchWidth - searchEnd - FrostGap.related)
                        : brandWidth,
                    child: drag(
                      fullBrand
                          ? _CaptionBrand(child: brand)
                          : ClipRect(
                              child: Align(
                                alignment: AlignmentDirectional.centerStart,
                                child: Semantics(
                                  label: widget.brandLabel,
                                  child: ExcludeSemantics(
                                    child: SizedBox.square(dimension: 24, child: Center(child: brandIcon)),
                                  ),
                                ),
                              ),
                            ),
                    ),
                  ),
                if (brandWidth > 0) const SizedBox(width: FrostGap.related),
                if (tabWidth > 0)
                  SizedBox(
                    width: tabWidth,
                    child: client(
                      fullTabs || contentCount == 0 || tabWidth <= baseWidth
                          ? tabs!.strip(context)
                          : Row(
                              children: [
                                if (baseWidth > 0)
                                  // A clipped viewport retains the very same base
                                  // tab paint/input path while content is folded.
                                  SizedBox(width: baseWidth, child: tabs!.strip(context)),
                                Expanded(
                                  child: FrostButton.plain(
                                    key: const ValueKey('frost-shell-tabs-collapsed'),
                                    label: count,
                                    labelWidget: Text(
                                      tabWidth - baseWidth < countWidth ? '$contentCount' : count,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    chevron: FrostButtonChevron.down,
                                    onPressed: () => showFrostContentTabs(context, tabs!),
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                Expanded(child: drag(const SizedBox.expand())),
                if (titleContent != null) SizedBox(width: searchWidth),
                drag(SizedBox(width: searchEnd, height: constraints.maxHeight)),
              ],
            ),
            if (titleContent != null)
              PositionedDirectional(
                end: searchEnd,
                top: 0,
                bottom: 0,
                child: AnimatedContainer(
                  duration: FrostMotion.duration(context, FrostMotion.standardDuration),
                  curve: FrostMotion.hoverCurve,
                  width: _searchExpanded ? math.min(frostCaptionSearchExpandedWidth, constraints.maxWidth - searchEnd) : searchWidth,
                  child: client(
                    FrostCaptionSearchScope(
                      expanded: _searchExpanded,
                      onExpanded: _expandSearch,
                      child: Center(child: titleContent),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
