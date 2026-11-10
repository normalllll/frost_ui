import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart' show DefaultTabController, TabController;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_control_geometry.dart';
import '../foundation/_key_bindings.dart';
import '../foundation/_tab_metrics.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_click_feedback.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '../primitives/keyline.dart';

class FrostTab {
  const FrostTab({required this.label, this.icon, this.secondaryLabel});
  final String label;
  final FrostIconData? icon;
  final String? secondaryLabel;
}

/// Frost-painted tabs. The content controller still owns selection and dragging.
class FrostTabBar extends StatefulWidget {
  const FrostTabBar({required this.tabs, this.controller, this.scrollable = false, this.onTap, this.size, this.showDivider = false, super.key});
  final List<FrostTab> tabs;
  final TabController? controller;

  /// False shares the bar's own width equally between the tabs. When a tab does
  /// not fit its share, the tabs keep their natural widths and scroll sideways.
  /// True always keeps natural widths.
  final bool scrollable;
  final ValueChanged<int>? onTap;

  /// Null preserves the 44px navigation band; explicit sizes use the control size scale.
  final FrostControlSize? size;
  final bool showDivider;
  @override
  State<FrostTabBar> createState() => _AppTabBarState();
}

class _AppTabBarState extends State<FrostTabBar> with TickerProviderStateMixin {
  _IndicatorTabController? _visual;
  final _scroll = ScrollController();
  final _nodes = <FocusNode>[];
  int _lastIndex = 0;

  void _bindController() {
    final source = widget.controller ?? DefaultTabController.of(context);
    assert(source.length == widget.tabs.length, 'TabController length must match FrostTabBar.tabs.');
    if (_visual?.source != source) {
      _visual?.source.removeListener(_selectionChanged);
      _visual?.dispose();
      _visual = _IndicatorTabController(source: source, vsync: this, context: () => context);
      _lastIndex = source.index;
      source.addListener(_selectionChanged);
    }
    while (_nodes.length < widget.tabs.length) {
      _nodes.add(FocusNode());
    }
    while (_nodes.length > widget.tabs.length) {
      _nodes.removeLast().dispose();
    }
    _visual!.reduceMotion = MediaQuery.disableAnimationsOf(context);
  }

  void _selectionChanged() {
    final index = _visual!.source.index;
    if (index == _lastIndex) return;
    _lastIndex = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || index >= _nodes.length || index != _visual!.source.index) return;
      final target = _nodes[index].context?.findRenderObject();
      // Only the bar's own scroll moves; Scrollable.ensureVisible would also
      // scroll every ancestor, such as a page whose collapsed header holds the bar.
      if (target != null && target.attached && _scroll.hasClients) {
        _scroll.position.ensureVisible(target, alignment: .5, duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : FrostMotion.hover);
      }
    });
  }

  void _activate(int index) {
    _nodes[index].requestFocus();
    _visual!.animateTo(index);
    widget.onTap?.call(index);
  }

  /// Left and Right (mirrored in RTL) move to the neighbouring tab, wrapping;
  /// Home and End to the first and last. Held keys do not repeat.
  Map<ShortcutActivator, bool Function()> get _keys {
    bool to(int Function(int from, int count, bool rtl) target) {
      if (widget.tabs.isEmpty) return false;
      final current = _nodes.indexWhere((n) => n.hasFocus);
      final index = target(current < 0 ? _visual!.source.index : current, widget.tabs.length, Directionality.of(context) == TextDirection.rtl);
      _nodes[index].requestFocus();
      _activate(index);
      return true;
    }

    return {
      const FrostKeyPress(LogicalKeyboardKey.arrowRight, repeat: false): () => to((from, count, rtl) => (from + (rtl ? -1 : 1)) % count),
      const FrostKeyPress(LogicalKeyboardKey.arrowLeft, repeat: false): () => to((from, count, rtl) => (from + (rtl ? 1 : -1)) % count),
      const FrostKeyPress(LogicalKeyboardKey.home, repeat: false): () => to((_, _, _) => 0),
      const FrostKeyPress(LogicalKeyboardKey.end, repeat: false): () => to((_, count, _) => count - 1),
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _bindController();
  }

  @override
  void didUpdateWidget(FrostTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _bindController();
  }

  @override
  void dispose() {
    _visual?.source.removeListener(_selectionChanged);
    _visual?.dispose();
    _scroll.dispose();
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context), style = FrostTypography.of(context).style(FrostTextRole.callout);
    final geometry = frostControlTextGeometry(baseHeight: widget.size?.height(context) ?? 44, style: style, textScaler: MediaQuery.textScalerOf(context));
    // Small visuals retain the density target height through transparent layout space.
    final hitHeight = math.max(geometry.height, FrostDensity.of(context).targetHeight);
    final visualInset = (hitHeight - geometry.height) / 2;
    final natural = [for (final tab in widget.tabs) _labelWidth(context, tab) + frostTabInset * 2];
    return FrostBleed(
      amount: frostTabInset,
      child: FrostKeyBindings(
        bindings: _keys,
        child: FrostMeasuredLayoutBuilder(
          naturalSize: Size(natural.fold(0.0, (a, b) => a + b), hitHeight),
          builder: (context, constraints) {
            final total = natural.fold(0.0, (a, b) => a + b);
            final available = constraints.hasBoundedWidth ? constraints.maxWidth : total;
            final scroll = widget.scrollable || total > available || natural.any((width) => width > available / natural.length);
            final widths = [for (var i = 0; i < natural.length; i++) scroll ? natural[i] : available / natural.length];
            final contentWidth = widths.fold(0.0, (a, b) => a + b);
            final centers = <double>[];
            var offset = 0.0;
            final rtl = Directionality.of(context) == TextDirection.rtl;
            for (var i = 0; i < widths.length; i++) {
              final iconShift = widget.tabs[i].icon == null ? 0.0 : ((widget.size ?? FrostControlSize.regular).iconSize + frostTabIconGap) / 2;
              final center = offset + widths[i] / 2 + iconShift;
              centers.add(rtl ? contentWidth - center : center);
              offset += widths[i];
            }
            return SizedBox(
              height: hitHeight,
              child: Stack(
                children: [
                  if (widget.showDivider)
                    PositionedDirectional(
                      start: 0,
                      end: 0,
                      bottom: visualInset,
                      child: ColoredBox(
                        color: tokens.separator,
                        child: SizedBox(height: 1 / MediaQuery.devicePixelRatioOf(context)),
                      ),
                    ),
                  SingleChildScrollView(
                    controller: _scroll,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: contentWidth,
                      height: hitHeight,
                      child: CustomPaint(
                        foregroundPainter: _IndicatorPainter(tokens.keyGraphicOn(tokens.surface), _visual!.animation, centers, visualInset),
                        child: Row(
                          children: [
                            for (var i = 0; i < widget.tabs.length; i++)
                              SizedBox(
                                width: widths[i],
                                height: hitHeight,
                                child: _TabLabel(
                                  tab: widget.tabs[i],
                                  index: i,
                                  controller: _visual!.source,
                                  height: geometry.height,
                                  size: widget.size ?? FrostControlSize.regular,
                                  focusNode: _nodes[i],
                                  onTap: () => _activate(i),
                                ),
                              ),
                          ],
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

  double _labelWidth(BuildContext context, FrostTab tab) {
    final type = FrostTypography.of(context);
    double measure(String text, FrostTextRole role) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: type.style(role).copyWith(fontWeight: role == FrostTextRole.callout ? FontWeight.w600 : null),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final result = painter.width;
      painter.dispose();
      return result;
    }

    final width = measure(tab.label, FrostTextRole.callout) + (tab.secondaryLabel == null ? 0 : 4 + measure(tab.secondaryLabel!, FrostTextRole.footnote));
    return width + (tab.icon == null ? 0 : (widget.size ?? FrostControlSize.regular).iconSize + frostTabIconGap);
  }
}

class _TabLabel extends StatefulWidget {
  const _TabLabel({
    required this.tab,
    required this.index,
    required this.controller,
    required this.height,
    required this.size,
    required this.focusNode,
    required this.onTap,
  });
  final FrostTab tab;
  final int index;
  final TabController controller;
  final double height;
  final FrostControlSize size;
  final FocusNode focusNode;
  final VoidCallback onTap;
  @override
  State<_TabLabel> createState() => _TabLabelState();
}

class _TabLabelState extends State<_TabLabel> {
  bool _hovered = false, _pressed = false, _focused = false;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.controller,
    builder: (context, _) {
      final t = FrostThemeTokens.of(context), type = FrostTypography.of(context);
      final selected = widget.controller.index == widget.index;
      final labelMeasure = TextPainter(
        text: TextSpan(
          text: widget.tab.label,
          style: type.style(FrostTextRole.callout).copyWith(fontWeight: FontWeight.w600),
        ),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final labelWidth = labelMeasure.width;
      labelMeasure.dispose();
      return MergeSemantics(
        child: Semantics(
          selected: selected,
          button: true,
          child: FrostClickSurfaceVisuals(
            child: FrostClickSurface(
              focusNode: widget.focusNode,
              onTap: widget.onTap,
              onHover: (v) => setState(() => _hovered = v),
              onPressedChange: (v) => setState(() => _pressed = v),
              onFocusChange: (v) => setState(() => _focused = v),
              child: Center(
                child: SizedBox(
                  height: widget.height,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: FrostClickFeedbackVisual(
                      states: {if (_hovered) WidgetState.hovered, if (_pressed) WidgetState.pressed, if (_focused) WidgetState.focused},
                      feedback: FrostClickFeedback.quiet,
                      shape: FrostRadius.shape(context, FrostRadius.sm),
                      clipsContent: false,
                      child: SizedBox(
                        height: widget.height - 8,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: frostTabInset - 4),
                          child: Center(
                            child: TweenAnimationBuilder<Color?>(
                              tween: ColorTween(end: selected ? t.textPrimary : t.textSecondary),
                              duration: FrostMotion.duration(context, FrostMotion.hover),
                              curve: FrostMotion.hoverCurve,
                              builder: (context, color, _) => Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (widget.tab.icon case final icon?) ...[
                                    FrostIcon(icon, size: widget.size.iconSize, color: color),
                                    const SizedBox(width: frostTabIconGap),
                                  ],
                                  FrostSkeletonText(
                                    child: SizedBox(
                                      width: labelWidth,
                                      child: Text(
                                        widget.tab.label,
                                        style: type
                                            .style(FrostTextRole.callout)
                                            .copyWith(color: color, fontWeight: selected ? FontWeight.w600 : FontWeight.w500),
                                      ),
                                    ),
                                  ),
                                  if (widget.tab.secondaryLabel case final secondary?) ...[
                                    const SizedBox(width: 4),
                                    FrostSkeletonText(
                                      child: Text(secondary, style: type.style(FrostTextRole.footnote).copyWith(color: t.textSecondary)),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
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

class _IndicatorPainter extends CustomPainter {
  _IndicatorPainter(this.color, this.progress, this.centers, this.visualInset) : super(repaint: progress);
  final Color color;
  final Animation<double> progress;
  final List<double> centers;
  final double visualInset;
  @override
  void paint(Canvas canvas, Size size) {
    if (centers.isEmpty) return;
    final value = progress.value.clamp(0.0, centers.length - 1.0);
    final center = centers[value.floor()] + (centers[value.ceil()] - centers[value.floor()]) * (value - value.floor());
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          center - frostTabIndicatorWidth / 2,
          size.height - visualInset - 6 - frostTabIndicatorHeight,
          frostTabIndicatorWidth,
          frostTabIndicatorHeight,
        ),
        const Radius.circular(1.5),
      ),
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_IndicatorPainter old) =>
      color != old.color || progress != old.progress || visualInset != old.visualInset || !listEquals(centers, old.centers);
}

class _IndicatorTabController extends TabController {
  _IndicatorTabController({required this.source, required super.vsync, required this.context})
    : _motion = AnimationController.unbounded(vsync: vsync, value: source.animation!.value),
      _lastIndex = source.index,
      super(length: source.length, initialIndex: source.index) {
    source.addListener(_selectionChanged);
    source.animation!.addListener(_sourceProgressChanged);
    // A bar can appear while its content controller is already moving (for
    // example after a responsive header rebuild). No new index notification
    // will arrive, so explicitly adopt the in-flight selection's target.
    if (source.indexIsChanging) FrostMotion.springTo(context(), _motion, source.index.toDouble(), FrostMotion.snappy);
  }

  final TabController source;
  final BuildContext Function() context;
  final AnimationController _motion;
  int _lastIndex;
  bool _dragging = false;
  bool _reduceMotion = false;

  set reduceMotion(bool value) {
    _reduceMotion = value;
    if (value) _motion.value = source.index.toDouble();
  }

  void _selectionChanged() {
    if (_lastIndex != source.index) {
      _lastIndex = source.index;
      if (_dragging && !source.indexIsChanging) {
        _motion.value = source.animation!.value;
      } else {
        _dragging = false;
        FrostMotion.springTo(context(), _motion, source.index.toDouble(), FrostMotion.snappy);
      }
    }
    notifyListeners();
  }

  void _sourceProgressChanged() {
    if (source.indexIsChanging) return;
    final progress = source.animation!.value;
    // PageView gestures drive this continuously. An index assignment or a
    // zero-duration animateTo is handled by the selection listener instead.
    if (progress != source.index || _dragging) {
      _dragging = progress != source.index;
      _motion.value = _reduceMotion ? source.index.toDouble() : progress;
    }
  }

  @override
  Animation<double> get animation => _motion.view;
  @override
  Duration get animationDuration => source.animationDuration;
  @override
  int get index => source.index;
  @override
  set index(int value) => source.index = value;
  @override
  int get previousIndex => source.previousIndex;
  @override
  bool get indexIsChanging => source.indexIsChanging;
  @override
  double get offset => source.offset;
  @override
  set offset(double value) => source.offset = value;
  @override
  void animateTo(int value, {Duration? duration, Curve curve = Curves.ease}) {
    _dragging = false;
    source.animateTo(value, duration: _reduceMotion ? Duration.zero : duration, curve: curve);
  }

  @override
  void dispose() {
    source.removeListener(_selectionChanged);
    source.animation?.removeListener(_sourceProgressChanged);
    _motion.dispose();
    super.dispose();
  }
}
