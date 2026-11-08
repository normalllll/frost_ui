import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/spring.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/click_surface.dart';
import '_rich_text_parser.dart';

// A fixed fade keeps long translations from consuming more body text.
const frostExpandableTextFadeWidth = 24.0;

/// Measures overflow during layout. Uncontrolled by default; a supplied expanded
/// value needs onExpandedChanged to enable the inline action.
class FrostExpandableText extends StatefulWidget {
  const FrostExpandableText({required this.text, this.maxLines = 3, this.role = FrostTextRole.body, this.expanded, this.onExpandedChanged, super.key})
    : assert(maxLines > 0),
      _rich = false,
      _runs = null,
      onLinkInNewTab = null,
      onLinkInBackground = null,
      fontSize = null,
      lineHeight = null,
      onLink = null,
      onMention = null,
      onHashtag = null;

  /// [text] in [FrostRichText]'s Markdown subset. Links, mentions and hashtags
  /// go to the callbacks, take keyboard focus and announce as links; one without
  /// its callback reads as the text around it. The text collapses and expands
  /// as plain text does.
  const FrostExpandableText.rich({
    required this.text,
    this.onLink,
    this.onMention,
    this.onHashtag,
    this.maxLines = 3,
    this.role = FrostTextRole.body,
    this.expanded,
    this.onExpandedChanged,
    super.key,
  }) : assert(maxLines > 0),
       _rich = true,
       _runs = null,
       onLinkInNewTab = null,
       onLinkInBackground = null,
       fontSize = null,
       lineHeight = null;

  /// Text shown exactly as written, with links the App marked. Every
  /// character of [runs] is drawn as it is: no Markdown, mentions or hashtags.
  /// Only a run with a [FrostTextRun.link] goes to [onLink], takes keyboard
  /// focus and announces as a link. [text] is the runs joined. Collapsing and
  /// expanding work as for plain text.
  FrostExpandableText.linked({
    required List<FrostTextRun> runs,
    required ValueChanged<Uri> this.onLink,
    this.onLinkInNewTab,
    this.onLinkInBackground,
    this.fontSize,
    this.lineHeight,
    this.maxLines = 3,
    this.role = FrostTextRole.body,
    this.expanded,
    this.onExpandedChanged,
    super.key,
  }) : assert(maxLines > 0),
       text = runs.map((run) => run.text).join(),
       _runs = List.unmodifiable(runs),
       _rich = true,
       onMention = null,
       onHashtag = null;
  final String text;
  final bool _rich;
  final List<FrostTextRun>? _runs;
  final ValueChanged<Uri>? onLink;
  final ValueChanged<String>? onMention, onHashtag;

  /// Ctrl/Cmd-click and middle-click on a link of a [FrostExpandableText.linked]
  /// text, as on a [FrostClickSurface]: open it in a new tab, or in the background.
  final ValueChanged<Uri>? onLinkInNewTab, onLinkInBackground;

  /// Overrides the size of [role] for a [FrostExpandableText.linked] text, for a
  /// size the reader chose. Text scaling still applies.
  final double? fontSize;

  /// Overrides the line height of [role], as a multiple of the font size.
  final double? lineHeight;
  final int maxLines;
  final FrostTextRole role;
  final bool? expanded;
  final ValueChanged<bool>? onExpandedChanged;
  @override
  State<FrostExpandableText> createState() => _ExpandableTextState();
}

/// A run of [FrostExpandableText.linked] text, shown exactly as written. A run
/// with a [link] is a link the App marked.
@immutable
class FrostTextRun {
  const FrostTextRun(this.text, {this.link});
  final String text;
  final Uri? link;

  @override
  bool operator ==(Object other) => other is FrostTextRun && other.text == text && other.link == link;

  @override
  int get hashCode => Object.hash(text, link);
}

/// A target's place in the joined node text, in UTF-16 offsets.
typedef _Target = ({int start, int end, String text, VoidCallback? onTap, VoidCallback? onNewTab, VoidCallback? onBackground});

class _ExpandableTextState extends State<FrostExpandableText> {
  bool _expanded = false;
  late List<FrostRichNode> _nodes;
  late String _plain;
  bool get expanded => widget.expanded ?? _expanded;

  void _parse() {
    _nodes = switch (widget._runs) {
      final runs? => [for (final run in runs) FrostRichNode(run.text, target: run.link == null ? null : FrostRichTarget.link, value: run.link?.toString())],
      null => widget._rich ? FrostRichDocument(widget.text).nodes : [FrostRichNode(widget.text)],
    };
    _plain = widget._rich ? _nodes.map((node) => node.text).join() : widget.text;
  }

  @override
  void initState() {
    super.initState();
    _parse();
  }

  @override
  void didUpdateWidget(FrostExpandableText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expanded != null && widget.expanded == null) _expanded = oldWidget.expanded!;
    if (oldWidget.text != widget.text || oldWidget._rich != widget._rich || !listEquals(oldWidget._runs, widget._runs)) _parse();
  }

  void _toggle() {
    final next = !expanded;
    if (widget.expanded == null) setState(() => _expanded = next);
    widget.onExpandedChanged?.call(next);
  }

  VoidCallback? _callback(FrostRichNode node) => switch (node.target) {
    FrostRichTarget.link => widget.onLink == null ? null : () => widget.onLink!(Uri.parse(node.value!)),
    FrostRichTarget.mention => widget.onMention == null ? null : () => widget.onMention!(node.value!),
    FrostRichTarget.hashtag => widget.onHashtag == null ? null : () => widget.onHashtag!(node.value!),
    null => null,
  };

  List<_Target> get _targets {
    final targets = <_Target>[];
    var offset = 0;
    for (final node in _nodes) {
      if (node.target != null) {
        final link = node.target == FrostRichTarget.link ? Uri.parse(node.value!) : null;
        final newTab = widget.onLinkInNewTab, background = widget.onLinkInBackground;
        targets.add((
          start: offset,
          end: offset + node.text.length,
          text: node.text,
          onTap: _callback(node),
          onNewTab: link == null || newTab == null ? null : () => newTab(link),
          onBackground: link == null || background == null ? null : () => background(link),
        ));
      }
      offset += node.text.length;
    }
    return targets;
  }

  /// The first [length] UTF-16 units of the node text, styled as
  /// [FrostRichText] styles them; plain text is one unstyled run.
  List<InlineSpan> _spans(BuildContext context, TextStyle base, int length) {
    if (!widget._rich) return [TextSpan(text: _plain.substring(0, length))];
    final typography = FrostTypography.of(context), tokens = FrostThemeTokens.of(context);
    final spans = <InlineSpan>[];
    var offset = 0;
    for (final node in _nodes) {
      if (offset >= length) break;
      final text = node.text.substring(0, math.min(node.text.length, length - offset));
      offset += node.text.length;
      var style = node.code ? typography.style(widget.role, monospace: true).copyWith(color: base.color, backgroundColor: tokens.fillSubtle) : base;
      if (node.bold) style = style.copyWith(fontWeight: typography.style(FrostTextRole.headline).fontWeight);
      if (node.italic) style = style.copyWith(fontStyle: FontStyle.italic);
      // A target nothing handles reads as the text around it.
      if (_callback(node) != null) style = style.copyWith(color: tokens.accentInk);
      spans.add(TextSpan(text: text, style: style));
    }
    return spans;
  }

  /// Focusable, announced link areas over the painted target text. A target
  /// that wraps gets one area per line; only the first takes focus.
  List<Widget> _targetAreas(TextPainter painter, int length) {
    Widget surface(_Target target, VoidCallback onTap) => FrostClickSurface(
      onTap: onTap,
      onOpenInNewTab: target.onNewTab,
      onOpenInBackground: target.onBackground,
      shape: FrostClickShape.rounded(FrostRadius.borderRadius(FrostRadius.xs)),
      child: const SizedBox.expand(),
    );
    return [
      for (final target in _targets)
        if (target.onTap case final onTap? when target.start < length)
          for (final (index, box) in painter.getBoxesForSelection(TextSelection(baseOffset: target.start, extentOffset: math.min(target.end, length))).indexed)
            Positioned.fromRect(
              rect: box.toRect(),
              child: index == 0
                  ? Semantics(link: true, label: target.text, onTap: onTap, excludeSemantics: true, child: surface(target, onTap))
                  : ExcludeSemantics(child: ExcludeFocus(child: surface(target, onTap))),
            ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final style = FrostTypography.of(context).style(widget.role).copyWith(color: tokens.textPrimary, fontSize: widget.fontSize, height: widget.lineHeight);
    final scaler = MediaQuery.textScalerOf(context), direction = Directionality.of(context);
    final label = expanded ? FrostScope.labelsOf(context).collapseText : FrostScope.labelsOf(context).expandText;
    final full = _spans(context, style, _plain.length);
    double heightAt(double width) {
      final plain = TextPainter(
        text: TextSpan(style: style, children: full),
        textDirection: direction,
        textScaler: scaler,
        maxLines: widget.maxLines,
      )..layout(maxWidth: width);
      var height = plain.height;
      final overflows = plain.didExceedMaxLines;
      plain.dispose();
      if (expanded && overflows) {
        // Expanded, the whole text runs on with the collapse action after its last word.
        final action = TextPainter(
          text: TextSpan(
            text: label,
            style: style.copyWith(color: tokens.accentInk),
          ),
          textDirection: direction,
          textScaler: scaler,
        )..layout(maxWidth: width);
        final whole =
            TextPainter(
                text: TextSpan(
                  style: style,
                  children: [
                    ...full,
                    const WidgetSpan(alignment: PlaceholderAlignment.bottom, child: SizedBox()),
                  ],
                ),
                textDirection: direction,
                textScaler: scaler,
              )
              ..setPlaceholderDimensions([
                PlaceholderDimensions(
                  size: Size(math.min(width, math.min(width, action.width) + FrostGap.inline), action.height),
                  alignment: PlaceholderAlignment.bottom,
                ),
              ])
              ..layout(maxWidth: width);
        height = whole.height;
        action.dispose();
        whole.dispose();
      }
      return height;
    }

    return FrostMeasuredLayoutBuilder(
      naturalSize: Size(frostTextLineSize(context, _plain, style).width, heightAt(double.infinity)),
      heightForWidth: heightAt,
      builder: (context, constraints) {
        final plain = TextPainter(
          text: TextSpan(style: style, children: full),
          textDirection: direction,
          textScaler: scaler,
          maxLines: widget.maxLines,
        );
        plain.layout(maxWidth: constraints.maxWidth);
        final overflows = plain.didExceedMaxLines;
        final width = constraints.hasBoundedWidth ? constraints.maxWidth : plain.maxIntrinsicWidth;
        final plainHeight = plain.height;
        plain.dispose();
        final rtl = direction == TextDirection.rtl;
        if (!overflows) {
          if (!widget._rich) return _frame(width, plainHeight, FrostSkeletonText(child: Text(widget.text, style: style)));
          final painter = TextPainter(
            text: TextSpan(style: style, children: full),
            textDirection: direction,
            textScaler: scaler,
          )..layout(maxWidth: width);
          return _frame(
            width,
            plainHeight,
            Stack(
              children: [
                Positioned.fill(
                  child: Semantics(
                    label: _plain,
                    child: FrostSkeletonText(
                      painter: painter,
                      textLength: _plain.length,
                      child: _PaintedText(painter: painter, fade: null, rtl: rtl, mask: tokens.canvas),
                    ),
                  ),
                ),
                ..._targetAreas(painter, _plain.length),
              ],
            ),
          );
        }
        final actionStyle = style.copyWith(color: tokens.accentInk);
        final actionPainter = TextPainter(
          text: TextSpan(text: label, style: actionStyle),
          textDirection: direction,
          textScaler: scaler,
        )..layout(maxWidth: width);
        final actionSize = Size(math.min(width, actionPainter.width), actionPainter.height);
        actionPainter.dispose();
        final placeholder = PlaceholderDimensions(
          size: Size(math.min(width, actionSize.width + FrostGap.inline), actionSize.height),
          alignment: PlaceholderAlignment.bottom,
        );
        TextPainter measure(int length, {int? maxLines}) =>
            TextPainter(
                text: TextSpan(
                  style: style,
                  children: [
                    ..._spans(context, style, length),
                    const WidgetSpan(alignment: PlaceholderAlignment.bottom, child: SizedBox()),
                  ],
                ),
                textDirection: direction,
                textScaler: scaler,
                maxLines: maxLines,
              )
              ..setPlaceholderDimensions([placeholder])
              ..layout(maxWidth: width);
        var body = _plain;
        if (!expanded) {
          final graphemes = _plain.characters.toList();
          var lower = 0, upper = graphemes.length;
          while (lower < upper) {
            final middle = (lower + upper + 1) ~/ 2;
            final probe = measure(graphemes.take(middle).join().trimRight().length, maxLines: widget.maxLines);
            final fits = !probe.didExceedMaxLines;
            probe.dispose();
            if (fits) {
              lower = middle;
            } else {
              upper = middle - 1;
            }
          }
          body = graphemes.take(lower).join().trimRight();
        }
        var painter = measure(body.length);
        // A shorter interface body font can leave the reserved action alone on
        // the last line. Pull the final grapheme back until it joins body ink,
        // retaining the inline fade and avoiding an otherwise empty text line.
        while (!expanded && body.isNotEmpty) {
          final slot = painter.inlinePlaceholderBoxes!.single.toRect();
          if (direction == TextDirection.ltr ? slot.left > 0 : slot.right < width) break;
          painter.dispose();
          body = body.characters.skipLast(1).toString().trimRight();
          painter = measure(body.length);
        }
        final box = painter.inlinePlaceholderBoxes!.single.toRect();
        final actionRect = Rect.fromLTWH(rtl ? box.left : box.right - actionSize.width, box.top, actionSize.width, actionSize.height);
        final fade = expanded
            ? null
            : Rect.fromLTRB(
                rtl ? box.right : math.max(0, box.left - frostExpandableTextFadeWidth),
                box.top,
                rtl ? math.min(width, box.right + frostExpandableTextFadeWidth) : box.left,
                box.bottom,
              );
        final height = painter.height;
        final enabled = widget.expanded == null || widget.onExpandedChanged != null;
        final content = SizedBox(
          width: width,
          height: height,
          child: Stack(
            children: [
              Positioned.fill(
                child: Semantics(
                  label: body,
                  child: FrostSkeletonText(
                    painter: painter,
                    textLength: body.length,
                    child: _PaintedText(painter: painter, fade: fade, rtl: rtl, mask: tokens.canvas),
                  ),
                ),
              ),
              ..._targetAreas(painter, body.length),
              Positioned.fromRect(
                rect: actionRect,
                child: Semantics(
                  label: label,
                  button: true,
                  expanded: expanded,
                  enabled: enabled,
                  excludeSemantics: true,
                  onTap: enabled ? _toggle : null,
                  child: FrostClickSurface(
                    onTap: enabled ? _toggle : null,
                    shape: FrostClickShape.rounded(FrostRadius.borderRadius(FrostRadius.xs)),
                    child: FrostSkeletonText(child: Text(label, style: actionStyle)),
                  ),
                ),
              ),
            ],
          ),
        );
        return _frame(width, height, content);
      },
    );
  }

  Widget _frame(double width, double height, Widget child) => FrostSpringBuilder(
    value: height,
    spring: FrostMotion.standard,
    child: SizedBox(width: width, height: height, child: child),
    builder: (context, value, child) => ClipRect(
      child: SizedBox(
        width: width,
        height: math.max(0, value),
        child: OverflowBox(alignment: AlignmentDirectional.topStart, minHeight: height, maxHeight: height, child: child),
      ),
    ),
  );
}

class _PaintedText extends StatefulWidget {
  const _PaintedText({required this.painter, required this.fade, required this.rtl, required this.mask});
  final TextPainter painter;
  final Rect? fade;
  final bool rtl;
  final Color mask;
  @override
  State<_PaintedText> createState() => _PaintedTextState();
}

class _PaintedTextState extends State<_PaintedText> {
  @override
  void didUpdateWidget(_PaintedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.painter, widget.painter)) oldWidget.painter.dispose();
  }

  @override
  void dispose() {
    widget.painter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: FrostExpandableTextPainter(widget.painter, widget.fade, widget.rtl, widget.mask));
}

class FrostExpandableTextPainter extends CustomPainter {
  const FrostExpandableTextPainter(this.text, this.fade, this.rtl, this.mask);
  final TextPainter text;
  final Rect? fade;
  final bool rtl;
  final Color mask;
  @override
  void paint(Canvas canvas, Size size) {
    if (fade != null && !fade!.isEmpty) canvas.saveLayer(Offset.zero & size, Paint());
    text.paint(canvas, Offset.zero);
    if (fade case final rect? when !rect.isEmpty) {
      final solid = mask.withValues(alpha: 1), clear = mask.withValues(alpha: 0);
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.dstIn
          ..shader = LinearGradient(colors: rtl ? [clear, solid] : [solid, clear]).createShader(rect),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(FrostExpandableTextPainter oldDelegate) =>
      text != oldDelegate.text || fade != oldDelegate.fade || rtl != oldDelegate.rtl || mask != oldDelegate.mask;
}
