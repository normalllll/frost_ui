import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Wayland deliberately leaves top-level positioning to the compositor.
enum FrostWindowPositionSupport { supported, compositorControlled }

@immutable
class FrostDisplay {
  const FrostDisplay({required this.id, required this.bounds, required this.workArea, required this.scale, this.coordinateScale = 1, this.primary = false});

  factory FrostDisplay.fromMap(Map<Object?, Object?> map) => FrostDisplay(
    id: map['id'] as String,
    bounds: _rect(map['bounds']),
    workArea: _rect(map['workArea']),
    scale: (map['scale'] as num).toDouble(),
    coordinateScale: (map['coordinateScale'] as num?)?.toDouble() ?? 1,
    primary: map['primary'] == true,
  );

  final String id;

  /// Desktop coordinates: Win32 physical pixels, AppKit/GDK desktop points.
  /// Never divide a mixed-DPI desktop origin by a window's current DPI.
  final Rect bounds, workArea;
  final double scale;

  /// Desktop coordinate units per logical pixel (Windows DPI; otherwise 1).
  final double coordinateScale;
  final bool primary;
  Size get logicalWorkArea => workArea.size / coordinateScale;
}

@immutable
class FrostWindowEnvironment {
  FrostWindowEnvironment({required List<FrostDisplay> displays, this.cursorDisplayId, this.positionSupport = FrostWindowPositionSupport.supported})
    : displays = List.unmodifiable(displays) {
    if (displays.isEmpty ||
        displays.any(
          (d) => d.id.isEmpty || !_validRect(d.workArea) || !d.scale.isFinite || d.scale <= 0 || !d.coordinateScale.isFinite || d.coordinateScale <= 0,
        )) {
      throw ArgumentError('A usable display is required');
    }
  }

  factory FrostWindowEnvironment.fromMap(Map<Object?, Object?> map) => FrostWindowEnvironment(
    displays: (map['displays'] as List).map((d) => FrostDisplay.fromMap(d as Map<Object?, Object?>)).toList(),
    cursorDisplayId: map['cursorDisplayId'] as String?,
    positionSupport: map['positionSupported'] == false ? FrostWindowPositionSupport.compositorControlled : FrostWindowPositionSupport.supported,
  );
  final List<FrostDisplay> displays;
  final String? cursorDisplayId;
  final FrostWindowPositionSupport positionSupport;

  FrostDisplay target({String? displayId, bool useCursor = false}) {
    final id = displayId ?? (useCursor ? cursorDisplayId : null);
    return displays.where((d) => d.id == id).firstOrNull ?? displays.where((d) => d.primary).firstOrNull ?? displays.first;
  }
}

/// Serializable data only. Apps own reading, writing and storage policy.
@immutable
class FrostWindowPlacement {
  const FrostWindowPlacement({required this.displayId, required this.rect, this.maximized = false, this.workAreaSize, this.displayScale});
  factory FrostWindowPlacement.fromMap(Map<Object?, Object?> map) => FrostWindowPlacement(
    displayId: map['displayId'] as String,
    rect: _rect(map['rect']),
    maximized: map['maximized'] == true,
    workAreaSize: map['workAreaSize'] == null ? null : _rect(map['workAreaSize']).size,
    displayScale: (map['displayScale'] as num?)?.toDouble(),
  );
  final String displayId;

  /// Normal outer window rectangle, in logical pixels relative to work-area
  /// top-left. This keeps negative/mixed-DPI desktop coordinates unambiguous.
  /// On compositorControlled backends, the origin is ignored, never observed.
  final Rect rect;
  final bool maximized;
  final Size? workAreaSize;
  final double? displayScale;
  Map<String, Object?> toMap() => {
    'displayId': displayId,
    'rect': _coordinates(rect),
    'maximized': maximized,
    if (workAreaSize case final size?) 'workAreaSize': [0.0, 0.0, size.width, size.height],
    if (displayScale != null) 'displayScale': displayScale,
  };

  @override
  bool operator ==(Object other) =>
      other is FrostWindowPlacement &&
      displayId == other.displayId &&
      rect == other.rect &&
      maximized == other.maximized &&
      workAreaSize == other.workAreaSize &&
      displayScale == other.displayScale;
  @override
  int get hashCode => Object.hash(displayId, rect, maximized, workAreaSize, displayScale);
}

@immutable
class FrostWindowGeometry {
  const FrostWindowGeometry({required this.placement, required this.frame, required this.positionSupport, this.minimized = false, this.fullscreen = false});
  factory FrostWindowGeometry.fromMap(Map<Object?, Object?> map) => FrostWindowGeometry(
    placement: FrostWindowPlacement.fromMap(map),
    frame: _rect(map['frame']),
    positionSupport: map['positionSupported'] == false ? FrostWindowPositionSupport.compositorControlled : FrostWindowPositionSupport.supported,
    minimized: map['minimized'] == true,
    fullscreen: map['fullscreen'] == true,
  );
  final FrostWindowPlacement placement;

  /// Current outer frame in the same work-area-relative logical coordinates.
  final Rect frame;
  final FrostWindowPositionSupport positionSupport;
  Offset? get position => positionSupport == FrostWindowPositionSupport.supported ? frame.topLeft : null;
  final bool minimized, fullscreen;
  @override
  bool operator ==(Object other) =>
      other is FrostWindowGeometry &&
      placement == other.placement &&
      frame == other.frame &&
      positionSupport == other.positionSupport &&
      minimized == other.minimized &&
      fullscreen == other.fullscreen;
  @override
  int get hashCode => Object.hash(placement, frame, positionSupport, minimized, fullscreen);
}

@immutable
class FrostWindowSizing {
  const FrostWindowSizing({this.preferredSize, this.aspectRatio = 1.6, this.minimumSize = const Size(640, 480), this.maxWorkAreaFraction = .9});
  final Size? preferredSize;
  final double aspectRatio;

  /// Minimum recommended/restored size. prepare also honors the controller's
  /// native interactive minimum; the work area wins on a smaller display.
  final Size minimumSize;
  final double maxWorkAreaFraction;
  void _validate() {
    if (!_validSize(minimumSize) ||
        preferredSize != null && !_validSize(preferredSize!) ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0 ||
        !maxWorkAreaFraction.isFinite ||
        maxWorkAreaFraction <= 0 ||
        maxWorkAreaFraction > 1) {
      throw ArgumentError('Invalid window sizing policy');
    }
  }
}

enum FrostWindowPlacementAdjustment { recommended, displayMissing, invalidPlacement, displayChanged, clamped, positionIgnoredUnsupported }

@immutable
class FrostWindowPlacementResult {
  FrostWindowPlacementResult(this.placement, Set<FrostWindowPlacementAdjustment> adjustments) : adjustments = Set.unmodifiable(adjustments);
  final FrostWindowPlacement placement;
  final Set<FrostWindowPlacementAdjustment> adjustments;
}

FrostWindowPlacement recommendFrostWindow(
  FrostWindowEnvironment environment, {
  FrostWindowSizing sizing = const FrostWindowSizing(),
  String? displayId,
  bool useCursor = false,
}) {
  sizing._validate();
  final display = environment.target(displayId: displayId, useCursor: useCursor);
  final work = display.logicalWorkArea;
  final cap = Size(work.width * sizing.maxWorkAreaFraction, work.height * sizing.maxWorkAreaFraction);
  final preferredWidth = math.min(1280.0, cap.width);
  final preferred = sizing.preferredSize ?? Size(preferredWidth, preferredWidth / sizing.aspectRatio);
  final factor = math.min(1.0, math.min(cap.width / preferred.width, cap.height / preferred.height));
  // Accessibility/minimum content wins over the preferred margin; the actual
  // work area wins if the display is smaller than the requested minimum.
  final width = (preferred.width * factor).clamp(math.min(work.width, sizing.minimumSize.width), work.width).toDouble();
  final height = (preferred.height * factor).clamp(math.min(work.height, sizing.minimumSize.height), work.height).toDouble();
  return FrostWindowPlacement(
    displayId: display.id,
    rect: Rect.fromLTWH((work.width - width) / 2, (work.height - height) / 2, width, height),
    workAreaSize: work,
    displayScale: display.scale,
  );
}

FrostWindowPlacementResult validateFrostWindow(
  FrostWindowPlacement? saved,
  FrostWindowEnvironment environment, {
  FrostWindowSizing sizing = const FrostWindowSizing(),
  String? displayId,
  bool useCursor = false,
}) {
  sizing._validate();
  final changes = <FrostWindowPlacementAdjustment>{};
  if (environment.positionSupport == FrostWindowPositionSupport.compositorControlled) changes.add(FrostWindowPlacementAdjustment.positionIgnoredUnsupported);
  FrostWindowPlacementResult fallback(FrostWindowPlacementAdjustment reason) {
    changes.add(reason);
    return FrostWindowPlacementResult(recommendFrostWindow(environment, sizing: sizing, displayId: displayId, useCursor: useCursor), changes);
  }

  if (saved == null) return fallback(FrostWindowPlacementAdjustment.recommended);
  if (!_validRect(saved.rect) ||
      saved.workAreaSize != null && !_validSize(saved.workAreaSize!) ||
      saved.displayScale != null && (!saved.displayScale!.isFinite || saved.displayScale! <= 0)) {
    return fallback(FrostWindowPlacementAdjustment.invalidPlacement);
  }
  var display = environment.displays.where((d) => d.id == saved.displayId).firstOrNull;
  if (display == null) {
    if (environment.positionSupport == FrostWindowPositionSupport.supported) return fallback(FrostWindowPlacementAdjustment.displayMissing);
    // On Wayland a missing/topology-local ID must not discard the size and
    // maximize state, since positioning/target selection belongs to the WM.
    changes.add(FrostWindowPlacementAdjustment.displayMissing);
    display = environment.target(displayId: displayId, useCursor: useCursor);
  }
  final work = display.logicalWorkArea;
  var origin = saved.rect.topLeft;
  final width = saved.rect.width.clamp(math.min(sizing.minimumSize.width, work.width), work.width).toDouble();
  final height = saved.rect.height.clamp(math.min(sizing.minimumSize.height, work.height), work.height).toDouble();
  if (saved.workAreaSize != null && saved.workAreaSize != work || saved.displayScale != null && saved.displayScale != display.scale) {
    changes.add(FrostWindowPlacementAdjustment.displayChanged);
    // Preserve logical content size and proportional free-space position.
    if (saved.workAreaSize case final old?) {
      double relative(double offset, double previous, double next) => previous <= 0 ? next / 2 : offset / previous * next;
      origin = Offset(
        relative(origin.dx, old.width - saved.rect.width, work.width - width),
        relative(origin.dy, old.height - saved.rect.height, work.height - height),
      );
    }
  }
  if (environment.positionSupport == FrostWindowPositionSupport.compositorControlled) origin = Offset.zero;
  final rect = Rect.fromLTWH(origin.dx.clamp(0, work.width - width).toDouble(), origin.dy.clamp(0, work.height - height).toDouble(), width, height);
  if (rect != Rect.fromLTWH(origin.dx, origin.dy, saved.rect.width, saved.rect.height)) changes.add(FrostWindowPlacementAdjustment.clamped);
  return FrostWindowPlacementResult(
    FrostWindowPlacement(displayId: display.id, rect: rect, maximized: saved.maximized, workAreaSize: work, displayScale: display.scale),
    changes,
  );
}

bool _validSize(Size size) => size.width.isFinite && size.height.isFinite && size.width > 0 && size.height > 0;
bool _validRect(Rect rect) => rect.left.isFinite && rect.top.isFinite && _validSize(rect.size);
List<double> _coordinates(Rect rect) => [rect.left, rect.top, rect.right, rect.bottom];
Rect _rect(Object? value) {
  final row = (value as List).cast<num>();
  if (row.length != 4) throw const FormatException('Expected four rectangle coordinates');
  return Rect.fromLTRB(row[0].toDouble(), row[1].toDouble(), row[2].toDouble(), row[3].toDouble());
}
