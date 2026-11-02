import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../overlays/tooltip.dart';
import '../primitives/_eager_layout_builder.dart';
import '../primitives/_spaced_wrap.dart';
import '../primitives/text.dart';
import '_avatar_size.dart';
import 'stat.dart';

// The wide arrangement needs room for avatar, a readable name and the actions.
const _wideWidth = 560.0;
const _avatarDimension = 72.0;
// The detail line's mark matches a compact icon on one body line.
const _detailIcon = 16.0;

/// The head of a person or collection page: avatar, name, a line of detail,
/// a stat strip and the page's actions. One structure for every profile.
///
/// Wide: avatar, then name, detail and stats stacked together, with the actions
/// at the end. Narrow: the same content stacked and centred, with [actions] and
/// [moreAction] in centred rows as space permits, or [moreAction] at the top corner when
/// there are no actions.
class FrostProfileHeader extends StatelessWidget {
  const FrostProfileHeader({
    required this.avatar,
    required this.title,
    this.subtitle,
    this.contentTitle = false,
    this.titleTooltip,
    this.contentSubtitle = false,
    this.titleTrailing,
    this.subtitleLeading,
    this.stats = const [],
    this.actions = const [],
    this.moreAction,
    super.key,
  });

  /// A [FrostAvatar]; the header sizes it.
  final Widget avatar;
  final String title;
  final String? subtitle;

  /// The name is content text (see [FrostText.content]), such as a person's
  /// name from the App's data: it draws with the regional forms of its own
  /// script or [FrostFonts.defaultScript], not the interface language. The
  /// detail line stays interface text unless [contentSubtitle] is set.
  final bool contentTitle;

  /// Shown on hover over the name, such as a full title the name abbreviates.
  final String? titleTooltip;

  /// The detail line is content text (see [FrostText.content]), such as an
  /// organisation name from the App's data.
  final bool contentSubtitle;

  /// A small mark after the name, such as a [FrostTag] for a variant. It sits
  /// beside the name when both fit on one line and wraps below it otherwise.
  final Widget? titleTrailing;

  /// An icon or small image before [subtitle], such as an organisation's
  /// emblem. The header sizes it to the detail line and scales it with text.
  final Widget? subtitleLeading;
  final List<FrostStat> stats;
  final List<Widget> actions;
  final Widget? moreAction;

  @override
  Widget build(BuildContext context) {
    final gap = FrostGap.of(context);
    final picture = SizedBox.square(
      dimension: _avatarDimension,
      child: FittedBox(
        child: FrostAvatarSizeScope(size: FrostAvatarSize.xlarge, child: avatar),
      ),
    );
    return _ProfileLayout(
      direction: Directionality.of(context),
      section: gap.section,
      group: gap.group,
      hasActions: actions.isNotEmpty || moreAction != null,
      actionsInCorner: actions.isEmpty,
      children: [
        picture,
        FrostEagerLayoutBuilder(
          builder: (context, constraints) {
            final wide = _isWide(constraints);
            final nameText = FrostText(title, role: FrostTextRole.title1, content: contentTitle, textAlign: wide ? TextAlign.start : TextAlign.center);
            final name = titleTooltip == null ? nameText : FrostTooltip(message: titleTooltip!, child: nameText);
            return Column(
              crossAxisAlignment: wide ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (titleTrailing case final trailing?)
                  Wrap(
                    alignment: wide ? WrapAlignment.start : WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: FrostGap.related,
                    runSpacing: FrostGap.inline,
                    children: [name, trailing],
                  )
                else
                  name,
                if (subtitle case final subtitle?) ...[
                  const SizedBox(height: FrostGap.inline),
                  _Detail(subtitle, leading: subtitleLeading, content: contentSubtitle, wide: wide),
                ],
                if (stats.isNotEmpty) ...[
                  SizedBox(height: gap.group),
                  Align(
                    alignment: wide ? AlignmentDirectional.centerStart : Alignment.center,
                    child: FrostStatStrip(stats: stats),
                  ),
                ],
              ],
            );
          },
        ),
        if (actions.isNotEmpty || moreAction != null)
          FrostEagerLayoutBuilder(
            builder: (context, constraints) => FrostSpacedWrap(
              spacing: FrostGap.related,
              runSpacing: FrostGap.related,
              alignment: _isWide(constraints) ? WrapAlignment.end : WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [...actions, ?moreAction],
            ),
          ),
      ],
    );
  }
}

bool _isWide(BoxConstraints constraints) => constraints is _ProfileConstraints ? constraints.wide : constraints.maxWidth >= _wideWidth;

/// Carries the arrangement to the parts, whose own width does not tell it.
class _ProfileConstraints extends BoxConstraints {
  _ProfileConstraints(BoxConstraints original, {required this.wide})
    : super(minWidth: original.minWidth, maxWidth: original.maxWidth, minHeight: original.minHeight, maxHeight: original.maxHeight);
  final bool wide;
  @override
  bool operator ==(Object other) => other is _ProfileConstraints && super == other && wide == other.wide;
  @override
  int get hashCode => Object.hash(super.hashCode, wide);
}

class _ProfileData extends ContainerBoxParentData<RenderBox> {}

class _ProfileLayout extends MultiChildRenderObjectWidget {
  const _ProfileLayout({
    required this.direction,
    required this.section,
    required this.group,
    required this.hasActions,
    required this.actionsInCorner,
    required super.children,
  });
  final TextDirection direction;
  final double section, group;
  final bool hasActions, actionsInCorner;
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderProfile(this);
  @override
  void updateRenderObject(BuildContext context, _RenderProfile renderObject) {
    renderObject.config = this;
    renderObject.markNeedsLayout();
  }
}

class _RenderProfile extends RenderBox with ContainerRenderObjectMixin<RenderBox, _ProfileData>, RenderBoxContainerDefaultsMixin<RenderBox, _ProfileData> {
  _RenderProfile(this.config);
  _ProfileLayout config;
  RenderBox get _picture => firstChild!;
  RenderBox get _info => childAfter(firstChild!)!;
  RenderBox? get _actions => config.hasActions ? lastChild : null;
  static const _gap = FrostGap.related;

  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ProfileData) child.parentData = _ProfileData();
  }

  double get _naturalWidth {
    final actions = _actions?.getMaxIntrinsicWidth(double.infinity);
    return _avatarDimension + config.section + _info.getMaxIntrinsicWidth(double.infinity) + (actions == null ? 0 : _gap + actions);
  }

  Size _layout(BoxConstraints limits, {required bool dry}) {
    final width = limits.hasBoundedWidth ? limits.maxWidth : _naturalWidth;
    final wide = width >= _wideWidth;
    Size measure(RenderBox child, BoxConstraints bounds) {
      final carried = _ProfileConstraints(bounds, wide: wide);
      if (dry) return child.getDryLayout(carried);
      child.layout(carried, parentUsesSize: true);
      return child.size;
    }

    void place(RenderBox child, double x, double y, double childWidth) {
      if (!dry) (child.parentData! as _ProfileData).offset = Offset(config.direction == TextDirection.ltr ? x : width - x - childWidth, y);
    }

    final picture = measure(_picture, const BoxConstraints());
    final info = _info, actions = _actions;
    var height = 0.0;
    if (wide) {
      final room = math.max(0.0, width - picture.width - config.section), start = picture.width + config.section;
      place(_picture, 0, 0, picture.width);
      if (actions == null) {
        final body = measure(info, BoxConstraints.tightFor(width: room));
        place(info, start, 0, room);
        height = math.max(picture.height, body.height);
      } else {
        final buttons = measure(actions, BoxConstraints(maxWidth: room));
        // Long names may elide, but actions must not squeeze them below half the column.
        final inline = buttons.width + _gap + math.min(info.getMaxIntrinsicWidth(double.infinity), room / 2) <= room;
        final infoWidth = inline ? math.max(0.0, room - buttons.width - _gap) : room;
        final body = measure(info, BoxConstraints.tightFor(width: infoWidth));
        final block = inline ? math.max(body.height, buttons.height) : body.height + _gap + buttons.height;
        place(info, start, inline ? (block - body.height) / 2 : 0, infoWidth);
        place(actions, width - buttons.width, inline ? (block - buttons.height) / 2 : body.height + _gap, buttons.width);
        height = math.max(picture.height, block);
      }
    } else {
      place(_picture, (width - picture.width) / 2, 0, picture.width);
      final top = picture.height + config.group;
      final body = measure(info, BoxConstraints.tightFor(width: width));
      place(info, 0, top, width);
      height = top + body.height;
      if (actions != null) {
        final buttons = measure(actions, BoxConstraints(maxWidth: width));
        if (config.actionsInCorner) {
          // Without actions the more control has no row of its own.
          place(actions, width - buttons.width, 0, buttons.width);
        } else {
          place(actions, (width - buttons.width) / 2, height + config.group, buttons.width);
          height += config.group + buttons.height;
        }
      }
    }
    return limits.constrain(Size(width, height));
  }

  @override
  void performLayout() => size = _layout(constraints, dry: false);
  @override
  Size computeDryLayout(BoxConstraints constraints) => _layout(constraints, dry: true);
  @override
  double computeMaxIntrinsicWidth(double height) => _naturalWidth;
  @override
  double computeMinIntrinsicWidth(double height) =>
      math.max(_avatarDimension, math.max(_info.getMinIntrinsicWidth(double.infinity), _actions?.getMinIntrinsicWidth(double.infinity) ?? 0));
  @override
  double computeMaxIntrinsicHeight(double width) => _layout(BoxConstraints(maxWidth: width), dry: true).height;
  @override
  double computeMinIntrinsicHeight(double width) => computeMaxIntrinsicHeight(width);
  @override
  void paint(PaintingContext context, Offset offset) => defaultPaint(context, offset);
  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}

class _Detail extends StatelessWidget {
  const _Detail(this.text, {required this.leading, required this.content, required this.wide});
  final String text;
  final Widget? leading;
  final bool content;
  final bool wide;
  @override
  Widget build(BuildContext context) {
    final label = FrostText(text, tone: FrostTextTone.secondary, content: content, textAlign: wide ? TextAlign.start : TextAlign.center);
    if (leading == null) return label;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox.square(
          dimension: MediaQuery.textScalerOf(context).scale(_detailIcon),
          child: FittedBox(child: leading),
        ),
        const SizedBox(width: FrostGap.related),
        Flexible(child: label),
      ],
    );
  }
}
