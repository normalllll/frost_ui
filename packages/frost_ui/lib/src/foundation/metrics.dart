import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:frost_ui/src/foundation/density.dart';

/// Shared geometry for controls and content; not platform or layout detection.
///
/// These are the design language itself and are identical in every app.
abstract final class FrostMetrics {
  /// Shared field/selector height, independent of the page aspect ratio:
  /// pointer platforms follow the density setting, touch keeps full size.
  static double fieldHeight(BuildContext context) {
    final base = switch (Theme.of(context).platform) {
      TargetPlatform.windows || TargetPlatform.macOS || TargetPlatform.linux => FrostDensity.of(context).pointerFieldHeight,
      _ => controlHeight,
    };
    final scaledText = MediaQuery.textScalerOf(context).scale(Theme.of(context).textTheme.bodyMedium?.fontSize ?? 14) * 1.5 + compactSectionGap;
    return scaledText > base ? scaledText : base;
  }

  static const controlRadius = 12.0;
  static const imageRadius = 12.0;
  static const groupRadius = 16.0;
  static const badgeRadius = 6.0;
  static const modalRadius = 24.0;
  static const controlHeight = 48.0;
  static const compactTargetHeight = 44.0;
  static const compactGap = 8.0;
  static const compactSectionGap = 12.0;
  static const sectionHeadingGap = 6.0;
  static const contentSectionPadding = EdgeInsets.all(12);
  static const filterMaxWidth = 360.0;
  static const iconSize = 20.0;
  static const pageInset = 16.0;
  static const sectionGap = 24.0;
  static const itemGap = 12.0;
  static const gridGap = 8.0;

  /// Preferred tile width shared by every media grid and its skeleton; the
  /// column count lands the tiles as close to it as fits.
  static const gridExtent = 220.0;

  /// The width limit for browse content, page inset included. Pages that cap
  /// their width share it, so switching pages never changes the column.
  static const contentMaxWidth = 1080.0;

  /// Settings has no grids to line up with, and its two panes (section list and
  /// groups) read as too small in a [contentMaxWidth] column on very large windows.
  static const settingsMaxWidth = 1440.0;

  /// Column for long-form reading.
  static const readingMaxWidth = 760.0;

  /// Inset that centres a [readingMaxWidth] column in a viewport of [width].
  static double readingColumnInset(double width) => math.max(pageInset, (width - readingMaxWidth) / 2 + pageInset);
  static const panelPadding = EdgeInsets.all(16);

  /// Horizontal padding around each tab label. Desktop tabs are a little
  /// wider apart, which also lets the first tab's hover highlight start at
  /// the floating bar's edge (see [pageTabInset]) while its label stays on
  /// [browseInset].
  static double tabLabelPadding(double width) => width < 600 ? 12.0 : 16.0;

  /// Horizontal inset shared by a browse page's tabs, section titles, strips
  /// and grids, so every block starts on the same left edge.
  static double browseInset(double width) => width < 600 ? 12.0 : 20.0;

  static EdgeInsets sectionTitlePadding(double width) => EdgeInsets.fromLTRB(browseInset(width), compactGap, browseInset(width), compactGap);
  static const focusBorderWidth = 2.0;

  /// Outline width of a text field while it has focus.
  static const fieldFocusWidth = 1.5;
  static const selectionIndicatorWidth = 3.0;

  /// How far a pressed surface sinks. Touch gets a clearly felt press; with a
  /// pointer the colour layer leads and the press is lighter. Media cards sink
  /// a little less than controls.
  static double pressedScale(BuildContext context, {bool media = false}) => switch (Theme.of(context).platform) {
    TargetPlatform.android || TargetPlatform.iOS || TargetPlatform.fuchsia => media ? .97 : .96,
    _ => .98,
  };

  /// Pointer hover zooms a media card's picture inside its frame.
  static const mediaHoverZoom = 1.02;

  /// Horizontal padding that centres a content column in a viewport of
  /// [width]: the column is at most [maxWidth] wide including its inset.
  /// Browse columns keep their text at least [browseInset] from the edge; a
  /// reading column uses [pageInset].
  static EdgeInsets columnPadding(double width, {double maxWidth = contentMaxWidth}) {
    final inset = maxWidth == readingMaxWidth ? pageInset : browseInset(width);
    return EdgeInsets.symmetric(horizontal: math.max(inset, (width - maxWidth) / 2 + inset));
  }

  /// Tab bar padding that puts the first label on [browseInset]. It is 0 on
  /// compact edge-to-edge bars and 4 on desktop, exactly the floating glass
  /// inset, so the first tab's hover highlight meets the bar's edge instead of
  /// leaving an unlit strip.
  static double pageTabInset(double width) => browseInset(width) - tabLabelPadding(width);
}

abstract final class FrostMotion {
  static const hover = Duration(milliseconds: 140);
  static const hoverCurve = Curves.easeOutQuad;
  static const feedback = Duration(milliseconds: 80);
  static const expand = Duration(milliseconds: 240);
  static const navigation = Duration(milliseconds: 200);
  static const layoutFade = Duration(milliseconds: 180);
  static const page = Duration(milliseconds: 280);
  static const exit = Duration(milliseconds: 220);
  // Skeleton to content, empty or error.
  static const reveal = Duration(milliseconds: 220);
  static const imageFade = Duration(milliseconds: 160);

  /// Cross-fade that replaces movement when reduced motion is on.
  static const reducedFade = Duration(milliseconds: 120);

  static const snappyDuration = Duration(milliseconds: 250);
  static const standardDuration = Duration(milliseconds: 350);
  static const gentleDuration = Duration(milliseconds: 450);

  static Duration duration(BuildContext context, Duration value) => MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;

  // Springs for position, size and scale: the restrained tier, no bounce.
  // They settle in about their duration, stop wherever they are interrupted
  // and carry their velocity into the next target. Colour and opacity keep
  // the short durations above.

  /// Press release, switches, sliders and indicators.
  static final snappy = SpringDescription.withDurationAndBounce(duration: snappyDuration);

  /// Menus, panels, the sidebar, toasts and heroes.
  static final standard = SpringDescription.withDurationAndBounce(duration: standardDuration);

  /// Large areas: pages, closing a viewer, reflowing a layout.
  static final gentle = SpringDescription.withDurationAndBounce(duration: gentleDuration);

  /// Drives [controller] to [target] on [spring], from its current value and
  /// velocity; with reduced motion it jumps there.
  static TickerFuture springTo(BuildContext context, AnimationController controller, double target, SpringDescription spring) {
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = target;
      return TickerFuture.complete();
    }
    // Snapping lands exactly on the target, so a settled opacity or scale
    // never lingers a hair away from 1 (and keeps its layer).
    return controller.animateWith(SpringSimulation(spring, controller.value, target, controller.velocity, snapToEnd: true));
  }
}
