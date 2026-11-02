import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../controls/_toolbar_geometry.dart';
import '../controls/picker.dart';
import '../controls/picker_option.dart';
import '../foundation/control_scope.dart';
import '../foundation/density.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../layout/_header_row_span.dart';
import '../layout/auto_scaffold.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../overlays/tooltip.dart';
import '../primitives/_eager_layout_builder.dart';
import '../primitives/_on_media_chrome_scope.dart';
import '../primitives/glyph.dart';
import '../primitives/keyline.dart';
import '_toolbar_middle_scope.dart';
import 'sort_menu.dart';
import 'toolbar_menu_button.dart';

part 'toolbar_item.dart';
part 'toolbar_layout.dart';

// Library-only conversion for a containing component with its own compact
// policy. Each item remains the source of both control and menu callback.
List<FrostMenuEntry> frostToolbarOverflowEntries(BuildContext context, Iterable<FrostToolbarItem> items) => [for (final item in items) item._overflow(context)];

/// Library-only: the width a toolbar's middle slot could take beside the row's
/// other content, written during each toolbar layout. A page header reads it
/// when its search field takes focus; nothing is rebuilt from it.
class FrostToolbarMiddleRoom {
  double width = double.infinity;
}

class FrostToolbarMiddleRoomScope extends InheritedWidget {
  const FrostToolbarMiddleRoomScope({required this.room, required super.child, super.key});
  final FrostToolbarMiddleRoom room;
  static FrostToolbarMiddleRoom? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostToolbarMiddleRoomScope>()?.room;
  @override
  bool updateShouldNotify(FrostToolbarMiddleRoomScope oldWidget) => room != oldWidget.room;
}

/// One row whose variants are measured and selected during the same layout.
class FrostToolbar extends StatefulWidget {
  const FrostToolbar({
    this.leadingIcons = const [],
    this.leading = const [],
    this.title,
    this.controls = const [],
    this.middle,
    this.collapsedMiddle,
    this.trailing = const [],
    super.key,
  });

  /// Each widget occupies one compact icon target at the row's start, like an
  /// AppBar leading slot: back buttons and other bare icons.
  final List<Widget> leadingIcons;

  /// Natural-width controls with their own plate, such as title menus and menu
  /// buttons, after [leadingIcons]. They give up width before [title] does.
  final List<Widget> leading;

  /// The row's text after [leading], on the keyline when it comes first: text,
  /// a label, or an App widget around them. One line; it keeps its natural
  /// width until the row runs out of room, then ellipsizes.
  final Widget? title;

  /// Natural-width controls immediately after leading content. They share one
  /// priority/overflow pass with trailing actions and the same More menu.
  /// Use middle only for flexible, non-menu content such as a search field.
  final List<FrostToolbarItem> controls;

  /// The middle slot grows continuously up to 360, immediately after leading
  /// controls. It never reduces trailing item widths or changes the existing
  /// compact/overflow order. A page header in search mode gives it up to 640.
  final Widget? middle, collapsedMiddle;

  final List<FrostToolbarItem> trailing;

  @override
  State<FrostToolbar> createState() => _FrostToolbarState();
}

class _FrostToolbarState extends State<FrostToolbar> with TickerProviderStateMixin {
  final FrostLayoutIdentity _identity = FrostLayoutIdentity();

  /// The title on screen: the widget's, or the last one while it fades out.
  Widget? _title;
  late final AnimationController _titleFade;

  /// The end cluster on screen: the widget's, or the last one while it fades
  /// out after the widget's became empty.
  late List<FrostToolbarItem> _items;
  late int _controlsCount;
  late final AnimationController _itemFade;
  List<FrostToolbarItem> get _widgetItems => [...widget.controls, ...widget.trailing];
  bool get _itemsLeaving => _items.isNotEmpty && _widgetItems.isEmpty;

  @override
  void initState() {
    super.initState();
    _items = _widgetItems;
    _controlsCount = widget.controls.length;
    _itemFade = AnimationController(vsync: this, value: _items.isEmpty ? 0 : 1)
      ..addStatusListener((status) {
        if (status.isDismissed && _itemsLeaving) setState(() => _items = const []);
      });
    _title = widget.title;
    _titleFade = AnimationController(vsync: this, value: widget.title == null ? 0 : 1)
      ..addStatusListener((status) {
        if (status.isDismissed && _title != null && widget.title == null) setState(() => _title = null);
      });
  }

  @override
  void didUpdateWidget(FrostToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final duration = FrostMotion.duration(context, FrostMotion.layoutFade);
    if (widget.title != null) {
      _title = widget.title;
      if (oldWidget.title == null) _titleFade.animateTo(1, duration: duration, curve: FrostMotion.hoverCurve);
    } else if (oldWidget.title != null) {
      if (duration == Duration.zero) _title = null;
      _titleFade.animateBack(0, duration: duration, curve: FrostMotion.hoverCurve);
    }
    final hadItems = oldWidget.controls.isNotEmpty || oldWidget.trailing.isNotEmpty;
    // A middle slot moves with the cluster, so that row takes its own crossfade.
    final fades = widget.middle == null && duration != Duration.zero;
    if (_widgetItems.isNotEmpty) {
      _items = _widgetItems;
      _controlsCount = widget.controls.length;
      if (!hadItems) fades ? _itemFade.animateTo(1, duration: duration, curve: FrostMotion.hoverCurve) : _itemFade.value = 1;
    } else if (hadItems) {
      if (fades) {
        _itemFade.animateBack(0, duration: duration, curve: FrostMotion.hoverCurve);
      } else {
        _items = const [];
        _itemFade.value = 0;
      }
    }
  }

  List<FrostToolbarItem> get trailing => _items;
  Widget? get middle => widget.middle;
  Widget? get collapsedMiddle => widget.collapsedMiddle;
  Widget _iconTarget(Widget widget, double inset) {
    final hit = FrostDensity.of(context).targetHeight, width = frostToolbarIconWidth(context);
    final keyline = FrostKeyline.maybeOf(context);
    final shift = keyline == null || keyline.insideContainer || FrostOnMediaChromeScope.inkOf(context) != null
        ? 0.0
        : inset - (width - FrostControlSize.compact.iconSize) / 2;
    // Fixed target geometry aligns the icon by construction. The slot includes
    // its edge offset, so the following leading/middle gap remains unchanged.
    return SizedBox(
      width: width + shift,
      height: hit,
      child: OverflowBox(alignment: AlignmentDirectional.centerEnd, minWidth: width, maxWidth: width, minHeight: hit, maxHeight: hit, child: widget),
    );
  }

  @override
  void dispose() {
    _itemFade.dispose();
    _titleFade.dispose();
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hit = FrostDensity.of(context).targetHeight;
    final inset = FrostGap.of(context).hitInset;
    final iconWidth = math.max(hit, FrostControlSize.compact.iconSize + inset * 2);
    final middleMaxWidth = FrostToolbarMiddleWidthScope.of(context);
    final middleExpands = FrostToolbarMiddleWidthScope.expandsOf(context);
    // A menu keeps enough of its value to name it, not just its chevron.
    final menuMinimum = inset * 2 + FrostGap.inline + FrostControlSize.compact.iconSize + MediaQuery.textScalerOf(context).scale(40);
    return FrostControlScope(
      size: FrostControlSize.compact,
      toolbar: true,
      child: Material(
        type: MaterialType.transparency,
        child: FrostBleed(
          amount: math.max(inset, (frostToolbarIconWidth(context) - FrostControlSize.compact.iconSize) / 2),
          child: Builder(
            builder: (context) {
              final keyline = FrostKeyline.maybeOf(context);
              final outsets = frostBleedOutsetsOf(context).resolve(Directionality.of(context));
              final direction = Directionality.of(context);
              final extraStart = math.max(0.0, (direction == TextDirection.ltr ? outsets.left : outsets.right) - inset);
              final extraEnd = math.max(0.0, (direction == TextDirection.ltr ? outsets.right : outsets.left) - inset);
              return FrostEagerLayoutBuilder(
                builder: (context, viewport) => SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: EdgeInsetsDirectional.only(start: extraStart, end: extraEnd),
                    child: FrostLayoutCrossfade(
                      layoutIdentity: _identity,
                      child: _ToolbarLayout(
                        identity: _identity,
                        width: math.max(0, viewport.maxWidth - extraStart - extraEnd),
                        minimumMiddle: math.min(
                          middleMaxWidth,
                          viewport.maxWidth >= FrostSizeClass.medium.minimumWidth
                              ? 200
                              : middleExpands
                              ? frostToolbarExpandingMiddleMinWidth
                              : 160,
                        ),
                        menusYieldBeforeActions: middle != null && middleExpands && viewport.maxWidth < FrostSizeClass.medium.minimumWidth,
                        maximumMiddle: middleMaxWidth,
                        collapsedWidth: collapsedMiddle == null ? 0 : iconWidth,
                        hasMiddle: middle != null,
                        middleRoom: FrostToolbarMiddleRoomScope.maybeOf(context),
                        rowSpan: FrostHeaderRowSpanScope.maybeOf(context),
                        gap: FrostGap.related,
                        edgeInset: keyline == null || keyline.insideContainer || FrostOnMediaChromeScope.inkOf(context) != null ? null : inset,
                        startRoom: extraStart,
                        endRoom: extraEnd,
                        minimumHeight: hit,
                        direction: Directionality.of(context),
                        items: trailing,
                        controlsCount: _controlsCount,
                        iconInset: (frostToolbarIconWidth(context) - FrostControlSize.compact.iconSize) / 2,
                        children: [
                          for (final (index, icon) in widget.leadingIcons.indexed)
                            _ToolbarSlot(kind: _Kind.leading, index: index, icon: true, child: _iconTarget(icon, inset)),
                          for (final (index, control) in widget.leading.indexed)
                            _ToolbarSlot(
                              kind: _Kind.leading,
                              index: widget.leadingIcons.length + index,
                              title: true,
                              shrinkPriority: 0,
                              titleMinimum: menuMinimum,
                              child: FrostToolbarLeadingScope(child: control),
                            ),
                          if (_title case final title?)
                            _ToolbarSlot(
                              kind: _Kind.leading,
                              index: widget.leadingIcons.length + widget.leading.length,
                              title: true,
                              // Beside a field that expands, the field gives way before the title goes.
                              titleMinimum: middle != null && middleExpands ? menuMinimum : 0,
                              child: Padding(
                                // Text has no button hit inset of its own.
                                padding: EdgeInsetsDirectional.only(start: widget.leadingIcons.isEmpty && widget.leading.isEmpty ? inset : 0),
                                child: FadeTransition(
                                  opacity: _titleFade,
                                  child: IgnorePointer(
                                    ignoring: widget.title == null,
                                    child: ExcludeSemantics(
                                      excluding: widget.title == null,
                                      child: FrostToolbarTitle(child: title),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          for (final (index, item) in trailing.indexed) ...[
                            for (final compact in [false, if (item._canCompact) true])
                              _ToolbarSlot(
                                kind: compact ? _Kind.compactMeasure : _Kind.fullMeasure,
                                index: index,
                                child: ExcludeFocus(
                                  child: ExcludeSemantics(
                                    child: item is _Custom ? SizedBox(width: item.minWidth, height: hit) : item._build(context, compact),
                                  ),
                                ),
                              ),
                            _ToolbarSlot(
                              kind: _Kind.item,
                              index: index,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final data = constraints as _ToolbarConstraints;
                                  final form = data.form;
                                  return TickerMode(
                                    enabled: form != _Form.hidden,
                                    child: FrostToolbarEdge(
                                      trailing: data.trailingEdge,
                                      child: ExcludeFocus(
                                        excluding: form == _Form.hidden || _itemsLeaving,
                                        child: Offstage(
                                          offstage: form == _Form.hidden,
                                          child: FadeTransition(
                                            opacity: _itemFade,
                                            child: IgnorePointer(
                                              ignoring: _itemsLeaving,
                                              child: ExcludeSemantics(excluding: _itemsLeaving, child: item._build(context, form == _Form.compact)),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                          if (middle != null)
                            _ToolbarSlot(
                              kind: _Kind.middle,
                              child: LayoutBuilder(
                                builder: (context, constraints) => switch ((constraints as _ToolbarConstraints).middle) {
                                  _Middle.full => middle!,
                                  _Middle.collapsed => collapsedMiddle!,
                                  _Middle.hidden => const SizedBox.shrink(),
                                },
                              ),
                            ),
                          _ToolbarSlot(
                            kind: _Kind.moreMeasure,
                            child: ExcludeFocus(
                              child: ExcludeSemantics(
                                child: FrostToolbarControl(
                                  label: FrostScope.labelsOf(context).more,
                                  icon: FrostIconSet.of(context).more,
                                  showsLabel: false,
                                  onPressed: () {},
                                ),
                              ),
                            ),
                          ),
                          _ToolbarSlot(
                            kind: _Kind.more,
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final overflow = (constraints as _ToolbarConstraints).overflow;
                                if (overflow.isEmpty) return const SizedBox.shrink();
                                return FrostToolbarEdge(
                                  trailing: true,
                                  child: FrostAdaptiveMenuAnchor(
                                    entries: [for (final index in overflow) trailing[index]._overflow(context)],
                                    builder: (context, focus, toggle) => FrostToolbarControl(
                                      label: FrostScope.labelsOf(context).more,
                                      icon: FrostIconSet.of(context).more,
                                      showsLabel: false,
                                      focusNode: focus,
                                      onPressed: toggle,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A single line of title content that ellipsizes, for a row of the App's own.
/// [FrostToolbar.title] and [FrostPageHeader] already apply it.
class FrostToolbarTitle extends StatelessWidget {
  const FrostToolbarTitle({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => DefaultTextStyle.merge(maxLines: 1, overflow: TextOverflow.ellipsis, child: child);
}
