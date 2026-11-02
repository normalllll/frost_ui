import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/_control_geometry.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../lists/_row_layout.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/click_surface.dart';
import '../primitives/divider.dart';
import '../primitives/icon.dart';
import '../primitives/path_text.dart';
import '../primitives/text.dart';
import '_copyable_text.dart';

/// A label and exactly one value or structural control. The shared list-row
/// layout moves the value below the label on the very first constrained frame.
class FrostLabeledContent extends StatefulWidget {
  const FrostLabeledContent({required this.label, this.value, this.content, super.key}) : assert((value == null) != (content == null));
  final String label;
  final String? value;
  final Widget? content;
  @override
  State<FrostLabeledContent> createState() => _LabeledContentState();
}

class _LabeledContentState extends State<FrostLabeledContent> {
  final _identity = FrostLayoutIdentity();
  @override
  void dispose() {
    _identity.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final geometry = frostControlGeometry(context, FrostControlSize.compact, role: FrostTextRole.callout);
    return MergeSemantics(
      child: Semantics(
        label: widget.label,
        value: widget.value,
        excludeSemantics: widget.value != null,
        child: FrostMotionSize(
          duration: FrostMotion.duration(context, FrostMotion.layoutFade),
          alignment: AlignmentDirectional.topStart,
          child: FrostTimedLayoutCrossfade(
            layoutIdentity: _identity,
            settleDuration: Duration.zero,
            child: FrostRowLayout(
              identity: _identity,
              contentIdentity: (widget.label, widget.value, widget.content?.key),
              minimumHeight: geometry.height,
              verticalInset: geometry.verticalInset,
              inset: EdgeInsets.zero,
              direction: Directionality.of(context),
              children: [
                FrostRowSlot(
                  id: FrostRowPart.text,
                  child: ExcludeSemantics(
                    child: FrostText(widget.label, role: FrostTextRole.callout, tone: FrostTextTone.secondary, tabular: true),
                  ),
                ),
                FrostRowSlot(
                  id: FrostRowPart.value,
                  child: widget.content ?? FrostText(widget.value!, role: FrostTextRole.callout, tone: FrostTextTone.primary, tabular: true),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FrostKeyValue {
  const FrostKeyValue({required this.label, required this.value}) : _kind = _KeyValueKind.text, onPressed = null, semanticLabel = null, monospace = false;

  /// A full original filesystem or gallery-relative path, with path wrapping.
  const FrostKeyValue.path({required this.label, required this.value}) : _kind = _KeyValueKind.path, onPressed = null, semanticLabel = null, monospace = false;

  /// A value that opens something outside the page, such as a source URL: an
  /// accent link that wraps like other values and ends with the external-link
  /// glyph. It is a keyboard stop and reads as a link named [semanticLabel],
  /// or by its label and value when that is null. A null [onPressed] shows
  /// the value as plain text.
  const FrostKeyValue.link({required this.label, required this.value, required this.onPressed, this.semanticLabel})
    : _kind = _KeyValueKind.link,
      monospace = false;

  /// A value the reader copies, such as a commit id, an address or a ref: it
  /// is selectable and wraps in the value column, and its copy button follows
  /// it (see [FrostCopyable]). [monospace] sets it in the monospace face.
  const FrostKeyValue.copyable({required this.label, required this.value, this.monospace = false})
    : _kind = _KeyValueKind.copyable,
      onPressed = null,
      semanticLabel = null;
  final String label, value;
  final VoidCallback? onPressed;
  final String? semanticLabel;

  /// Whether a copyable value uses the monospace face.
  final bool monospace;
  final _KeyValueKind _kind;
}

enum _KeyValueKind { text, path, link, copyable }

/// Labels in a column as wide as the longest of them, up to half the list, and
/// values wrapping in the rest. Each label shares its value's first baseline.
class FrostKeyValueList extends StatelessWidget {
  const FrostKeyValueList({required this.entries, this.dividers = false, super.key});
  final List<FrostKeyValue> entries;
  final bool dividers;

  static const _gap = 12.0;

  @override
  Widget build(BuildContext context) {
    final labelStyle = DefaultTextStyle.of(context).style.merge(frostTextStyle(context, FrostTextRole.callout, FrostTextTone.secondary, tabular: true));
    var longest = 0.0;
    for (final entry in entries) {
      longest = math.max(longest, frostTextLineSize(context, entry.label, labelStyle).width);
    }
    final geometry = frostControlGeometry(context, FrostControlSize.compact, role: FrostTextRole.callout);
    return LimitedBox(
      maxWidth: FrostMetrics.contentMaxWidth,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (index, entry) in entries.indexed) ...[
            if (dividers && index > 0) const FrostDivider(),
            _semantics(
              entry,
              Padding(
                padding: EdgeInsets.symmetric(vertical: geometry.verticalInset),
                child: _KeyValueRow(
                  // Whole pixels so the measured label never wraps on a rounding error.
                  labelWidth: longest.ceilToDouble(),
                  gap: _gap,
                  direction: Directionality.of(context),
                  children: [
                    ExcludeSemantics(
                      excluding: entry._kind == _KeyValueKind.copyable,
                      child: FrostText(entry.label, role: FrostTextRole.callout, tone: FrostTextTone.secondary, tabular: true),
                    ),
                    _value(context, entry),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // A row reads as one node: its label with its value. A copyable value's
  // button stays a node of its own inside it, as in a standalone FrostCopyable.
  Widget _semantics(FrostKeyValue entry, Widget row) => entry._kind == _KeyValueKind.copyable
      ? Semantics(container: true, explicitChildNodes: true, label: entry.label, value: entry.value, child: row)
      : MergeSemantics(child: row);

  Widget _value(BuildContext context, FrostKeyValue entry) => switch (entry._kind) {
    _KeyValueKind.path => FrostPathText(entry.value, role: FrostTextRole.callout, tone: FrostTextTone.primary, selectable: true),
    _KeyValueKind.link when entry.onPressed != null => _KeyValueLink(entry: entry),
    _KeyValueKind.copyable => FrostCopyableText(
      text: entry.value,
      textSemantics: false,
      style: FrostTypography.of(
        context,
      ).style(FrostTextRole.callout, tabular: true, monospace: entry.monospace).copyWith(color: FrostThemeTokens.of(context).textPrimary),
    ),
    _ => FrostText(entry.value, role: FrostTextRole.callout, tone: FrostTextTone.primary, tabular: true),
  };
}

class _KeyValueLink extends StatelessWidget {
  const _KeyValueLink({required this.entry});
  final FrostKeyValue entry;

  @override
  Widget build(BuildContext context) {
    final style = frostTextStyle(context, FrostTextRole.callout, FrostTextTone.accent, tabular: true);
    final glyph = (style.fontSize ?? 15) * .8;
    // A semantic label replaces the visible text but keeps the surface's
    // tap and focus actions.
    Widget named(Widget text) => entry.semanticLabel == null ? text : ExcludeSemantics(child: text);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: Semantics(
        link: true,
        label: entry.semanticLabel,
        child: FrostClickSurface(
          onTap: entry.onPressed,
          feedback: FrostClickFeedback.quiet,
          shape: const FrostClickShape.rounded(BorderRadius.all(Radius.circular(FrostRadius.sm))),
          mouseCursor: SystemMouseCursors.click,
          child: named(
            Text.rich(
              TextSpan(
                text: entry.value,
                children: [
                  // The glyph follows the last word, so it wraps with the value.
                  const TextSpan(text: ' '),
                  WidgetSpan(
                    alignment: PlaceholderAlignment.middle,
                    child: FrostIcon(FrostIconSet.of(context).externalLink, size: glyph, color: style.color),
                  ),
                ],
              ),
              style: style,
            ),
          ),
        ),
      ),
    );
  }
}

class _RowData extends ContainerBoxParentData<RenderBox> {}

/// A label as wide as [labelWidth], up to half the row, and its value in the
/// rest, sharing their first baseline.
class _KeyValueRow extends MultiChildRenderObjectWidget {
  const _KeyValueRow({required this.labelWidth, required this.gap, required this.direction, required super.children});
  final double labelWidth, gap;
  final TextDirection direction;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderKeyValueRow(this);
  @override
  void updateRenderObject(BuildContext context, _RenderKeyValueRow renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderKeyValueRow extends RenderBox with ContainerRenderObjectMixin<RenderBox, _RowData>, RenderBoxContainerDefaultsMixin<RenderBox, _RowData> {
  _RenderKeyValueRow(this.config);
  _KeyValueRow config;
  RenderBox get _label => firstChild!;
  RenderBox get _value => lastChild!;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _RowData) child.parentData = _RowData();
  }

  double _labelAt(double width) => math.min(config.labelWidth, math.max(0.0, (width - config.gap) / 2));
  double _valueAt(double width) => math.max(0.0, width - _labelAt(width) - config.gap);

  @override
  double computeMinIntrinsicWidth(double height) =>
      config.gap + 2 * math.max(_label.getMinIntrinsicWidth(double.infinity), _value.getMinIntrinsicWidth(double.infinity));
  @override
  double computeMaxIntrinsicWidth(double height) => config.labelWidth + config.gap + _value.getMaxIntrinsicWidth(double.infinity);

  // The lines share a baseline, so the taller first line pushes the other down
  // by at most the difference of their first lines. Both are callout text except
  // beside a copy button, whose target is the one thing taller than a line.
  @override
  double computeMaxIntrinsicHeight(double width) {
    final label = _label.getMaxIntrinsicHeight(_labelAt(width)), value = _value.getMaxIntrinsicHeight(_valueAt(width));
    final line = _label.getMaxIntrinsicHeight(double.infinity), first = _value.getMaxIntrinsicHeight(double.infinity);
    return math.max(value, label + math.max(0.0, first - line) / 2);
  }

  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);

  @override
  Size computeDryLayout(BoxConstraints constraints) {
    final width = constraints.hasBoundedWidth ? constraints.maxWidth : computeMaxIntrinsicWidth(double.infinity);
    return constraints.constrain(Size(width, computeMaxIntrinsicHeight(width)));
  }

  @override
  void performLayout() {
    final width = constraints.maxWidth, labelWidth = _labelAt(width), valueWidth = _valueAt(width);
    _label.layout(BoxConstraints.tightFor(width: labelWidth), parentUsesSize: true);
    _value.layout(BoxConstraints.tightFor(width: valueWidth), parentUsesSize: true);
    final labelLine = _label.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true);
    final valueLine = _value.getDistanceToBaseline(TextBaseline.alphabetic, onlyReal: true);
    final baseline = math.max(labelLine ?? 0, valueLine ?? 0);
    final labelTop = labelLine == null ? 0.0 : baseline - labelLine, valueTop = valueLine == null ? 0.0 : baseline - valueLine;
    size = constraints.constrain(Size(width, math.max(labelTop + _label.size.height, valueTop + _value.size.height)));
    final ltr = config.direction == TextDirection.ltr;
    (_label.parentData! as _RowData).offset = Offset(ltr ? 0 : width - labelWidth, labelTop);
    (_value.parentData! as _RowData).offset = Offset(ltr ? labelWidth + config.gap : 0, valueTop);
  }

  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
