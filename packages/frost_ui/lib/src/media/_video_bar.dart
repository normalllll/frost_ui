import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/_media_contrast.dart';
import '../foundation/_touch_targets.dart';
import '../foundation/density.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_material_reveal.dart';
import '../motion/rolling_text.dart';
import '../primitives/_on_media_chrome_scope.dart';

// The mask belongs to the two-row control region. Extending it far into the
// image darkens half a phone frame, even when no controls occupy that area.
const frostVideoGradientExtent = 0.0;
const _topGradientExtent = 64.0;
// Commands hang this far past the seek track's ends, so their glyphs line up
// with it. The scroll view holds them whole: it takes no hits outside itself.
const _commandOutset = 7.0;
const _commandInset = 5.0;

/// How long on-media controls stay without input, for video and viewer chrome.
const frostMediaChromeIdleDelay = Duration(milliseconds: 2500);

/// The opacity at which on-media ink stays readable over a white frame.
double frostVideoControlScrimOpacity(FrostThemeTokens tokens) => frostOnMediaScrimOpacity(tokens, minimum: .60);

/// Paint derives the mask from the child's actual first-frame height.
class FrostVideoBar extends StatelessWidget {
  const FrostVideoBar({
    required this.play,
    required this.current,
    required this.total,
    required this.slider,
    required this.trailing,
    this.custom = const [],
    super.key,
  });
  final Widget play, slider;
  final String current, total;
  final List<Widget> trailing, custom;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final style = FrostTypography.of(context).style(FrostTextRole.caption, numeric: true).copyWith(color: tokens.onMediaInk, shadows: frostMediaInkShadows);
    double textWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    // One numeric phrase prevents current/total from reading as unrelated labels.
    final clock = '$current / $total';
    final inkInset = FrostDensity.of(context).usesPointer ? 4.0 : 12.0;
    final time = SizedBox(
      width: textWidth('$total / $total'),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Padding(
          padding: EdgeInsets.only(top: inkInset),
          child: FrostRollingText(clock, style: style),
        ),
      ),
    );
    final controls = [play, time, ...custom, ...trailing];
    final safe = MediaQuery.paddingOf(context);
    final content = FrostOnMediaChromeScope(
      child: FrostVideoCommandScope(
        child: Padding(
          padding: EdgeInsets.only(left: _commandInset + safe.left, right: _commandInset + safe.right, bottom: safe.bottom),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: _VideoControlLayout(
                inkInset: inkInset,
                touchDevice: !FrostDensity.of(context).usesPointer,
                width: constraints.maxWidth,
                direction: Directionality.of(context),
                children: [slider, ...controls],
              ),
            ),
          ),
        ),
      ),
    );
    return FrostVideoChrome(child: content);
  }
}

/// Shared player-strip gradient: the complete control region remains readable
/// over white/red, fading to clear at the control region's own boundary.
class FrostVideoChrome extends StatelessWidget {
  const FrostVideoChrome({required this.child, this.top = false, super.key});
  final Widget child;
  final bool top;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final reveal = FrostMaterialRevealScope.maybeOf(context);
    final progress = reveal != null && !reveal.claimed ? reveal.progress : 1.0;
    final readable = frostVideoControlScrimOpacity(tokens);
    return CustomPaint(
      painter: FrostVideoScrimPainter(
        tokens.onMediaScrim.withValues(alpha: math.max(.70, readable) * progress),
        controlOpacity: readable * progress,
        top: top,
      ),
      child: reveal?.consume(context, child) ?? child,
    );
  }
}

// Measure each live slot once instead of estimating arbitrary App controls or
// mounting two candidate bars. This preserves controllers, focus and gestures
// as the available width changes between an inline strip and wrapped controls.
class _VideoControlLayout extends MultiChildRenderObjectWidget {
  const _VideoControlLayout({required this.inkInset, required this.touchDevice, required this.width, required this.direction, required super.children});
  final double width, inkInset;
  final bool touchDevice;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderVideoControls(direction, width, inkInset)..touchDevice = touchDevice;
  @override
  void updateRenderObject(BuildContext context, _RenderVideoControls renderObject) {
    renderObject.touchDevice = touchDevice;
    renderObject.inkInset = inkInset;
    renderObject.direction = direction;
    renderObject.width = width;
  }
}

class _VideoControlData extends ContainerBoxParentData<RenderBox> {}

class _RenderVideoControls extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, _VideoControlData>, RenderBoxContainerDefaultsMixin<RenderBox, _VideoControlData> {
  _RenderVideoControls(this._direction, this._width, this._inkInset);
  bool touchDevice = false;
  double _inkInset;
  set inkInset(double value) {
    if (value == _inkInset) return;
    _inkInset = value;
    markNeedsLayout();
  }

  double _width;
  set width(double value) {
    if (_width == value) return;
    _width = value;
    markNeedsLayout();
  }

  TextDirection _direction;
  set direction(TextDirection value) {
    if (value == _direction) return;
    _direction = value;
    markNeedsLayout();
  }

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _VideoControlData) child.parentData = _VideoControlData();
  }

  @override
  void performLayout() {
    final children = getChildrenAsList();
    final slider = children.first, controls = children.skip(1).toList();
    for (final (index, child) in controls.indexed) {
      // App controls may expand to their available width. Keep them bounded;
      // only the numeric clock needs unconstrained natural text measurement.
      child.layout(index == 1 ? const BoxConstraints() : BoxConstraints(maxWidth: _width), parentUsesSize: true);
    }
    final rowHeight = controls.fold<double>(0, (h, c) => math.max(h, c.size.height));
    final natural = controls.fold<double>(0, (w, c) => w + c.size.width);
    final width = math.max(_width - _commandOutset * 2, natural);
    slider.layout(BoxConstraints.tightFor(width: width), parentUsesSize: true);
    final height = math.max(58.0, rowHeight + 20);
    // The seek target and command row share vertical breathing room, while
    // their visible ink occupies separate lines. Controls keep native hit sizes.
    (slider.parentData! as _VideoControlData).offset = Offset(_commandOutset, height - rowHeight + _inkInset - slider.size.height / 2);
    var x = 0.0;
    for (final (index, child) in controls.indexed) {
      if (index == 2) x += math.max(0, width - natural);
      (child.parentData! as _VideoControlData).offset = Offset(
        _commandOutset +
            (_direction == TextDirection.ltr ? x : width - x - child.size.width) +
            (_direction == TextDirection.ltr ? 1 : -1) *
                (index == 0
                    ? -_commandOutset
                    : index > 1
                    ? _commandOutset
                    : 0),
        height - rowHeight + (rowHeight - child.size.height) / 2,
      );
      x += child.size.width;
    }
    size = constraints.constrain(Size(width + _commandOutset * 2, height));
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    bool hit(RenderBox child) => result.addWithPaintOffset(
      offset: (child.parentData! as _VideoControlData).offset,
      position: position,
      hitTest: (result, local) => child.hitTest(result, position: local),
    );
    final slider = firstChild!;
    for (var child = lastChild; child != null && child != slider; child = childBefore(child)) {
      if (hit(child)) return true;
    }
    // The track lies under the command row. A touch beside a command's narrow
    // slot is for the command, and the touch-target root yields to any listener.
    if (frostExpectsFinger(touchDevice: touchDevice) && _besideCommand(position)) return false;
    return hit(slider);
  }

  bool _besideCommand(Offset position) {
    final minimum = FrostControlSize.minimumHitHeight(touch: true);
    final commands = getChildrenAsList().skip(1).toList()..removeAt(1);
    return commands.any((command) {
      final rect = (command.parentData! as _VideoControlData).offset & command.size;
      return Rect.fromCenter(center: rect.center, width: math.max(rect.width, minimum), height: rect.height).contains(position);
    });
  }
}

/// One continuous black gradient, including the readable control region. No
/// uniform material or blur sits beneath it, so there is no panel boundary.
class FrostVideoScrimPainter extends CustomPainter {
  const FrostVideoScrimPainter(this.color, {required this.controlOpacity, this.top = false});
  final Color color;
  final double controlOpacity;
  final bool top;
  LinearGradient gradientFor(Size size) => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: top
        ? [color, color.withValues(alpha: controlOpacity), color.withValues(alpha: 0)]
        : [color.withValues(alpha: 0), color.withValues(alpha: controlOpacity), color],
    stops: [0, top ? size.height / (size.height + _topGradientExtent) : .45, 1],
  );
  @override
  void paint(Canvas canvas, Size size) {
    final extent = top ? _topGradientExtent : frostVideoGradientExtent;
    final rect = Rect.fromLTWH(0, top ? 0 : -extent, size.width, size.height + extent);
    final shader = gradientFor(size).createShader(rect);
    canvas.drawRect(rect, Paint()..shader = shader);
  }

  @override
  bool shouldRepaint(FrostVideoScrimPainter oldDelegate) =>
      color != oldDelegate.color || controlOpacity != oldDelegate.controlOpacity || top != oldDelegate.top;
}
