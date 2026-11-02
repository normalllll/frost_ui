import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../motion/_spring_simulation.dart';
import '_focus_modality.dart';
import 'spacing.dart';

/// Shared geometry for controls and content; not platform or layout detection.
///
/// These are the design language itself and are identical in every app.
abstract final class FrostMetrics {
  static const filterMaxWidth = 360.0;

  /// Preferred tile width shared by every media grid and its skeleton; the
  /// column count lands the tiles as close to it as fits.
  static const gridExtent = 220.0;

  /// The width limit for forms and other single-column settings content, page
  /// inset included. Browse and media pages fill their viewport instead; reading
  /// pages use [readingMaxWidth]. A capped column sits centred in the free space.
  static const contentMaxWidth = 1080.0;

  /// The width limit for a settings page's two panes (section list and groups),
  /// which read as too small in a [contentMaxWidth] column. They sit centred.
  static const settingsMaxWidth = 1440.0;

  /// Column for long-form reading.
  static const readingMaxWidth = 760.0;

  /// Horizontal padding around each tab label. Desktop tabs are a little
  /// wider apart, which also lets the first tab's hover highlight start at
  /// the floating bar's edge (see [pageTabInset]) while its label stays on
  /// [browseInset].
  static double tabLabelPadding(double width) => width < 600 ? 12.0 : 16.0;

  /// Horizontal inset shared by a browse page's tabs, section titles, strips
  /// and grids, so every block starts on the same left edge.
  static double browseInset(double width) => width < 600 ? 16.0 : 24.0;

  static EdgeInsets sectionTitlePadding(double width) => EdgeInsets.fromLTRB(browseInset(width), FrostGap.related, browseInset(width), FrostGap.related);
  static const focusBorderWidth = 1.5;

  /// Physical pixels for the single field edge in every state. Divide by DPR.
  static const fieldFocusWidth = 1.0;
  static const selectionIndicatorWidth = 3.0;

  /// How far a pressed surface sinks. Touch gets a clearly felt press; with a
  /// pointer the colour layer leads and the press is lighter. Media cards sink
  /// a little less than controls.
  static double pressedScale(BuildContext context, {bool media = false}) => FrostInputModality.instance.touch ? (media ? .97 : .96) : .98;

  /// Pointer hover zooms a media card's picture inside its frame.
  static const mediaHoverZoom = 1.03;

  /// Horizontal padding that centres a capped content column in a viewport of
  /// [width]: the column is at most [maxWidth] wide including its inset.
  /// Browse columns keep their text at least [browseInset] from the edge; a
  /// reading column uses the same [browseInset] scale.
  static EdgeInsets columnPadding(double width, {double maxWidth = contentMaxWidth}) {
    final inset = browseInset(width), free = math.max(0.0, width - maxWidth);
    return EdgeInsets.only(left: free / 2 + inset, right: free / 2 + inset);
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

  /// Disappearance is shorter than reveal and uses easeInCubic.
  static const dismiss = Duration(milliseconds: 160);
  static const imageFade = Duration(milliseconds: 160);

  /// Cross-fade that replaces movement when reduced motion is on.
  static const reducedFade = Duration(milliseconds: 120);

  static const snappyDuration = Duration(milliseconds: 200);
  static const standardDuration = Duration(milliseconds: 240);
  static const gentleDuration = Duration(milliseconds: 280);

  static Duration duration(BuildContext context, Duration value) => MediaQuery.disableAnimationsOf(context) ? Duration.zero : value;

  // Springs for position, size and scale: the restrained tier, no bounce.
  // They settle in about their duration, stop wherever they are interrupted
  // and carry their velocity into the next target. Colour and opacity keep
  // the short durations above.

  /// Press release, switches, sliders and indicators.
  static final snappy = SpringDescription.withDurationAndBounce(duration: snappyDuration);

  /// Small confirmation feedback only (for example toggling a social action).
  /// Never use this bouncing spring for layout or floating surfaces.
  static final bouncy = SpringDescription.withDurationAndBounce(duration: snappyDuration, bounce: .2);

  /// Menus, panels, the sidebar, toasts and heroes.
  static final standard = SpringDescription.withDurationAndBounce(duration: standardDuration);

  /// Large areas: pages, closing a viewer, reflowing a layout.
  static final gentle = SpringDescription.withDurationAndBounce(duration: gentleDuration);

  /// Drives [controller] to [target] on [spring], from its current value and
  /// velocity, bounded to avoid crossing the new target for geometry springs;
  /// with reduced motion it jumps there.
  static TickerFuture springTo(BuildContext context, AnimationController controller, double target, SpringDescription spring) {
    if (MediaQuery.disableAnimationsOf(context)) {
      controller.value = target;
      return TickerFuture.complete();
    }
    // Snapping lands exactly on the target, so a settled opacity or scale
    // never lingers a hair away from 1 (and keeps its layer).
    return controller.animateWith(frostSpringSimulation(spring, controller.value, target, controller.velocity));
  }
}
