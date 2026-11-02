import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../feedback/refresh_indicator.dart';
import '../foundation/metrics.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../primitives/_page_outline.dart';
import 'column_placement.dart';
import 'content_viewport.dart';
import 'pinned_chrome.dart';

// A secondary reading measure, not a second equally weighted main pane.
// Main content keeps at least the family's full reading measure.
const _auxiliaryMeasure = 320.0;
const _minimumReadingLines = 20;
const _minimumLandscapeRatio = 4 / 3;

/// One primary reading flow with optional auxiliary slivers. In sufficient
/// readable landscape space the auxiliary flow sits at physical right. Otherwise
/// it follows every primary sliver in this same viewport, never another route.
///
/// Supply media, information and discussion together in [slivers]. Both slots
/// accept lazy/paged slivers, including FrostSliverDataList. No nested scroll
/// view, eager whole-list measurement, or app-side breakpoint is needed.
/// Compose FrostPinnedChrome outside for page-wide pinned navigation; this layout
/// already inserts its FrostChromeSpacer and respects content-column placement.
class FrostContentLayout extends StatefulWidget {
  const FrostContentLayout({required this.slivers, this.auxiliarySlivers = const [], this.controller, super.key});

  final List<Widget> slivers;
  final List<Widget> auxiliarySlivers;
  final ScrollController? controller;

  @override
  State<FrostContentLayout> createState() => _ContentLayoutState();
}

enum _ContentFlow { primary, auxiliary }

class _ContentLayoutState extends State<FrostContentLayout> {
  final _primaryKey = GlobalKey();
  final _auxiliaryKey = GlobalKey();
  bool? _beside;
  _ContentFlow _readingFlow = _ContentFlow.primary;

  RenderSliver? _sliver(_ContentFlow flow) {
    final key = flow == _ContentFlow.primary ? _primaryKey : _auxiliaryKey;
    final render = key.currentContext?.findRenderObject();
    return render is RenderSliver && render.geometry != null ? render : null;
  }

  ScrollPosition? get _position {
    final target = _primaryKey.currentContext;
    return target == null ? null : Scrollable.maybeOf(target)?.position;
  }

  void _rememberPointerFlow(Offset point) {
    final auxiliary = _sliver(_ContentFlow.auxiliary);
    final bounds = auxiliary?.geometry?.visible == true ? MatrixUtils.transformRect(auxiliary!.getTransformTo(null), auxiliary.paintBounds) : Rect.zero;
    _readingFlow = bounds.contains(point) ? _ContentFlow.auxiliary : _ContentFlow.primary;
  }

  void _rememberArrangement(bool beside) {
    if (_beside == beside) return;
    final previous = _beside;
    final position = _position;
    final auxiliary = _sliver(_ContentFlow.auxiliary);
    if (previous == false && position != null && auxiliary != null) {
      if (position.pixels >= auxiliary.constraints.precedingScrollExtent) {
        _readingFlow = _ContentFlow.auxiliary;
      } else if (_readingFlow != _ContentFlow.auxiliary || auxiliary.geometry?.visible != true) {
        _readingFlow = _ContentFlow.primary;
      }
    }
    final flow = _readingFlow;
    final sliver = _sliver(flow);
    final offset = position != null && sliver != null ? position.pixels - sliver.constraints.precedingScrollExtent : null;
    final focus = FocusManager.instance.primaryFocus;
    final focused = focus?.context?.findAncestorStateOfType<_ContentLayoutState>() == this ? focus : null;
    _beside = beside;
    if (previous == null) return;

    // One ScrollPosition owns both arrangements. Keep the reading offset within
    // its actual flow: a trailing auxiliary offset cannot be reused as a raw
    // document offset beside the primary flow, where it may be out of range.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _beside != beside || _position != position) return;
      final target = focused?.context;
      if (focused?.hasFocus == true && target?.mounted == true) {
        // Editor focus often lives inside control padding; leave breathing room.
        unawaited(Scrollable.ensureVisible(target!, alignment: .5));
      } else if (position != null && offset != null && position.hasContentDimensions) {
        final current = _sliver(flow);
        if (current == null) return;
        final restored = (current.constraints.precedingScrollExtent + offset).clamp(position.minScrollExtent, position.maxScrollExtent);
        if (position.pixels != restored) position.jumpTo(restored);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final style = FrostTypography.of(context).style(FrostTextRole.body);
    final scaler = MediaQuery.textScalerOf(context);
    final scale = math.max(1.0, scaler.scale(style.fontSize!) / style.fontSize!);
    final painter = TextPainter(
      text: TextSpan(style: style),
      textDirection: Directionality.of(context),
      textScaler: scaler,
    )..layout();
    final minimumHeight = painter.preferredLineHeight * _minimumReadingLines;
    painter.dispose();
    final auxiliaryWidth = _auxiliaryMeasure * scale;
    final gap = FrostGap.of(context).section;
    final primaryMinimum = FrostMetrics.readingMaxWidth * scale;
    final insets = MediaQuery.paddingOf(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;

    return Listener(
      onPointerDown: (event) => _rememberPointerFlow(event.position),
      onPointerSignal: (event) => _rememberPointerFlow(event.position),
      child: FrostLoadingScrollView(
        controller: widget.controller,
        slivers: [
          const FrostChromeSpacer(),
          SliverSafeArea(
            top: false,
            bottom: false,
            sliver: SliverLayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.crossAxisExtent;
                final usableWidth = FrostPageOutline.contentWidth(context, width);
                final height = math.max(0.0, constraints.viewportMainAxisExtent - insets.vertical - keyboard);
                final maximumWidth = primaryMinimum + gap + auxiliaryWidth + FrostMetrics.browseInset(usableWidth) * 2;
                final padding = FrostColumnPlacement.columnPadding(context, width, maxWidth: maximumWidth);
                final beside =
                    widget.slivers.isNotEmpty &&
                    widget.auxiliarySlivers.isNotEmpty &&
                    width - padding.horizontal >= primaryMinimum + gap + auxiliaryWidth &&
                    usableWidth >= height * _minimumLandscapeRatio &&
                    height >= minimumHeight;
                _rememberArrangement(beside);
                final primary = SliverMainAxisGroup(key: _primaryKey, slivers: widget.slivers);
                final auxiliary = SliverMainAxisGroup(key: _auxiliaryKey, slivers: widget.auxiliarySlivers);
                return FrostSliverContentColumn(
                  maxWidth: beside ? maximumWidth : primaryMinimum,
                  sliver: beside
                      ? SliverCrossAxisGroup(
                          slivers: [
                            SliverCrossAxisExpanded(
                              flex: 1,
                              sliver: SliverPadding(
                                padding: EdgeInsets.only(right: gap),
                                sliver: primary,
                              ),
                            ),
                            SliverConstrainedCrossAxis(maxExtent: auxiliaryWidth, sliver: auxiliary),
                          ],
                        )
                      : SliverMainAxisGroup(
                          slivers: [
                            primary,
                            if (widget.auxiliarySlivers.isNotEmpty)
                              SliverPadding(
                                padding: EdgeInsets.only(top: gap),
                                sliver: auxiliary,
                              ),
                          ],
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
