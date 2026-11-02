import 'dart:math' as math;

import 'package:flutter/material.dart' show SelectableText;
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/_copy_feedback.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../primitives/_text_selection_chrome.dart';

/// Library-only: selectable, wrapping text in [style] whose copy button and
/// context menu always copy [text]. The button follows the text while it fits
/// on one line and moves to the end of the row only when the text wraps; it is
/// centred on the first line of text. The row is as wide as its content, and
/// its baseline is the text's first baseline.
class FrostCopyableText extends StatelessWidget {
  const FrostCopyableText({required this.text, required this.style, this.display, this.textSemantics = true, super.key});
  final String text;
  final String? display;
  final TextStyle style;

  /// False when an ancestor already reads the value, such as a key-value row;
  /// the copy button keeps its own node either way.
  final bool textSemantics;

  @override
  Widget build(BuildContext context) {
    final painter = TextPainter(
      text: TextSpan(text: display ?? text, style: DefaultTextStyle.of(context).style.merge(style)),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
    );
    final lineHeight = painter.preferredLineHeight;
    painter.dispose();
    return FrostCopyFeedback(
      text: text,
      builder: (context, copied, copy) => FrostContextMenuRegion(
        enabled: FrostControlScope.enabledOf(context),
        entries: [FrostMenuAction(FrostScope.labelsOf(context).copy, onSelected: copy)],
        child: _CopyableLayout(
          lineHeight: lineHeight,
          direction: Directionality.of(context),
          children: [
            ExcludeSemantics(
              excluding: !textSemantics,
              child: IgnorePointer(
                ignoring: !FrostControlScope.enabledOf(context),
                child: FrostSkeletonText(
                  child: SelectableText(display ?? text, contextMenuBuilder: null, selectionControls: frostTextSelectionControls, style: style),
                ),
              ),
            ),
            FrostCopyFeedbackButton(copied: copied, onCopy: copy),
          ],
        ),
      ),
    );
  }
}

class _CopyableData extends ContainerBoxParentData<RenderBox> {}

class _CopyableLayout extends MultiChildRenderObjectWidget {
  const _CopyableLayout({required this.lineHeight, required this.direction, required super.children});
  final double lineHeight;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCopyable(lineHeight, direction);
  @override
  void updateRenderObject(BuildContext context, _RenderCopyable renderObject) => renderObject.update(lineHeight, direction);
}

class _RenderCopyable extends RenderBox with ContainerRenderObjectMixin<RenderBox, _CopyableData>, RenderBoxContainerDefaultsMixin<RenderBox, _CopyableData> {
  _RenderCopyable(this._lineHeight, this._direction);
  double _lineHeight;
  TextDirection _direction;
  static const _gap = FrostGap.related;

  void update(double lineHeight, TextDirection direction) {
    if (lineHeight == _lineHeight && direction == _direction) return;
    _lineHeight = lineHeight;
    _direction = direction;
    markNeedsLayout();
  }

  RenderBox get _text => firstChild!;
  RenderBox get _button => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _CopyableData) child.parentData = _CopyableData();
  }

  // The text keeps its natural one-line width while the button fits after it.
  double _textWidth(double maxWidth, double buttonWidth) => math.min(_text.getMaxIntrinsicWidth(double.infinity), math.max(0.0, maxWidth - _gap - buttonWidth));

  ({Size size, double textWidth, double textTop, double buttonTop, Size button}) _measure(BoxConstraints constraints, {required bool dry}) {
    final buttonConstraints = BoxConstraints(maxWidth: constraints.maxWidth, maxHeight: constraints.maxHeight);
    final Size button;
    if (dry) {
      button = _button.getDryLayout(buttonConstraints);
    } else {
      _button.layout(buttonConstraints, parentUsesSize: true);
      button = _button.size;
    }
    final textWidth = _textWidth(constraints.maxWidth, button.width);
    final Size text;
    if (dry) {
      text = _text.getDryLayout(BoxConstraints(maxWidth: textWidth));
    } else {
      _text.layout(BoxConstraints(maxWidth: textWidth), parentUsesSize: true);
      text = _text.size;
    }
    // Centre the button on the first line; whichever is shorter moves down.
    final textTop = math.max(0.0, (button.height - _lineHeight) / 2);
    final buttonTop = math.max(0.0, (_lineHeight - button.height) / 2);
    final size = constraints.constrain(Size(text.width + _gap + button.width, math.max(textTop + text.height, buttonTop + button.height)));
    return (size: size, textWidth: text.width, textTop: textTop, buttonTop: buttonTop, button: button);
  }

  @override
  Size computeDryLayout(BoxConstraints constraints) => _measure(constraints, dry: true).size;

  @override
  void performLayout() {
    final measured = _measure(constraints, dry: false);
    size = measured.size;
    final ltr = _direction == TextDirection.ltr;
    final buttonStart = measured.textWidth + _gap;
    (_text.parentData! as _CopyableData).offset = Offset(ltr ? 0 : size.width - measured.textWidth, measured.textTop);
    (_button.parentData! as _CopyableData).offset = Offset(ltr ? buttonStart : size.width - buttonStart - measured.button.width, measured.buttonTop);
  }

  double get _buttonExtent => _button.getMaxIntrinsicWidth(double.infinity);

  @override
  double computeMaxIntrinsicWidth(double height) => _text.getMaxIntrinsicWidth(double.infinity) + _gap + _buttonExtent;
  @override
  double computeMinIntrinsicWidth(double height) => _text.getMinIntrinsicWidth(double.infinity) + _gap + _buttonExtent;
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  double computeMaxIntrinsicHeight(double width) {
    final buttonHeight = _button.getMaxIntrinsicHeight(double.infinity);
    final textHeight = _text.getMaxIntrinsicHeight(_textWidth(width, _buttonExtent));
    return math.max(math.max(0.0, (buttonHeight - _lineHeight) / 2) + textHeight, math.max(0.0, (_lineHeight - buttonHeight) / 2) + buttonHeight);
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    final distance = _text.getDistanceToActualBaseline(baseline);
    return distance == null ? null : distance + (_text.parentData! as _CopyableData).offset.dy;
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
