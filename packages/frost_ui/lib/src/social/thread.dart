import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../controls/_button_control.dart';
import '../controls/_button_types.dart';
import '../display/_avatar_size.dart';
import '../display/badge.dart';
import '../foundation/density.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../overlays/context_menu.dart';
import '../overlays/menu_entry.dart';
import '../primitives/_flow_position.dart';
import '../primitives/_presence_entry.dart';
import '../primitives/click_surface.dart';
import '../primitives/icon.dart';
import '../primitives/presence.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';

// Thread geometry is independent of the nesting content's natural height.
const _avatarExtent = 32.0;
const _compactAvatarExtent = 24.0;
const _connectionGap = 4.0;
const _bendRadius = 8.0;
const _lineWidth = 1.5;
const _maximumIndent = 3;
const _footerIcon = 16.0;

/// How replies hang under their parent.
enum FrostThreadStyle {
  /// Replies sit in a light module block under the parent's text column. The
  /// default: no connector lines, so nothing has to be traced to read it.
  block,

  /// Replies are indented and joined to the parent avatar by connector lines,
  /// for Apps whose conversations nest deeper than one level.
  lines,
}

/// One footer action of a [FrostThreadItem]: a 16px icon with an optional
/// count. The visual stays small; touch gets a larger transparent hit area.
class FrostThreadAction {
  const FrostThreadAction({required this.icon, required this.label, this.count, this.selected = false, this.onPressed});
  final FrostIconData icon;

  /// Accessibility label, for example "Like".
  final String label;

  /// Display text next to the icon; omit for an icon-only action.
  final String? count;
  final bool selected;
  final VoidCallback? onPressed;
}

/// A comment or reply. The author line carries only who wrote it ([author] and
/// a small [badge]); [time], [like] and [reply] share one compact footer in
/// tertiary footnote type, and further actions belong in [contextMenu].
class FrostThreadItem extends StatelessWidget {
  const FrostThreadItem({
    required this.avatar,
    required this.author,
    required this.body,
    this.badge,
    this.badgeTone = FrostBadgeTone.neutral,
    this.meta,
    this.time,
    this.like,
    this.reply,
    this.actions,
    this.onPressed,
    this.contextMenu = const [],
    super.key,
  });
  final Widget avatar, body;
  final String author;

  /// A small tag after the author, such as a level or "UP".
  final String? badge;
  final FrostBadgeTone badgeTone;

  /// Extra tertiary text after the author line's tag, for example an IP region.
  final String? meta;

  /// Footer: time first, then [like] and [reply] at a fixed gap.
  final String? time;
  final FrostThreadAction? like, reply;

  /// Optional extra footer content after the standard actions. Do not put
  /// full-size buttons here; use [contextMenu] for secondary actions.
  final Widget? actions;
  final VoidCallback? onPressed;
  final List<FrostMenuEntry> contextMenu;

  @override
  Widget build(BuildContext context) {
    final compact = context.dependOnInheritedWidgetOfExactType<_ThreadDepth>()?.compact ?? false;
    final tokens = FrostThemeTokens.of(context);
    final type = FrostTypography.of(context);
    final extent = compact ? _compactAvatarExtent : _avatarExtent;
    final hasFooter = time != null || like != null || reply != null || actions != null;
    return FrostContextMenuRegion(
      entries: contextMenu,
      child: FrostClickSurface(
        onTap: onPressed,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AvatarAnchor(
              child: SizedBox(
                width: extent,
                height: extent,
                child: DecoratedBox(
                  decoration: BoxDecoration(shape: BoxShape.circle, color: FrostSurfaceScope.maybeOf(context)?.background ?? tokens.canvas),
                  child: FrostAvatarSizeScope(size: compact ? FrostAvatarSize.small : FrostAvatarSize.regular, child: avatar),
                ),
              ),
            ),
            const SizedBox(width: FrostGap.related),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        author,
                        style: type.style(FrostTextRole.body).copyWith(fontWeight: FontWeight.w500, color: tokens.textPrimary),
                      ),
                      if (badge case final badge?) FrostBadge(label: badge, tone: badgeTone),
                      if (meta case final meta?) FrostText(meta, role: FrostTextRole.footnote, tone: FrostTextTone.tertiary),
                    ],
                  ),
                  const SizedBox(height: 2),
                  body,
                  if (hasFooter) _Footer(time: time, like: like, reply: reply, actions: actions),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Time, like and reply on one line in footnote type with 16px icons. Touch
/// pads each action's hit area with transparent space; pointer keeps it tight.
class _Footer extends StatelessWidget {
  const _Footer({this.time, this.like, this.reply, this.actions});
  final String? time;
  final FrostThreadAction? like, reply;
  final Widget? actions;

  @override
  Widget build(BuildContext context) {
    final hit = FrostDensity.of(context).usesPointer ? 2.0 : 10.0;
    return Row(
      children: [
        if (time != null) FrostText(time!, role: FrostTextRole.footnote, tone: FrostTextTone.tertiary),
        if (like != null) ...[if (time != null) const SizedBox(width: FrostGap.group), _ActionButton(action: like!, hit: hit)],
        if (reply != null) ...[if (time != null || like != null) const SizedBox(width: FrostGap.inline), _ActionButton(action: reply!, hit: hit)],
        if (actions != null) ...[const SizedBox(width: FrostGap.related), actions!],
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.action, required this.hit});
  final FrostThreadAction action;
  final double hit;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final ink = action.selected ? tokens.accentInk : tokens.textTertiary;
    return Semantics(
      label: action.count == null ? action.label : '${action.label} ${action.count}',
      button: true,
      selected: action.selected,
      excludeSemantics: true,
      child: FrostClickSurface(
        onTap: action.onPressed,
        shape: FrostClickShape.rounded(BorderRadius.circular(FrostRadius.sm)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4, vertical: hit),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              FrostIcon(action.icon, size: _footerIcon, color: ink),
              if (action.count case final count?) ...[
                const SizedBox(width: FrostGap.inline),
                Text(count, style: FrostTypography.of(context).style(FrostTextRole.footnote).copyWith(color: ink)),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A recursive thread block. Keep keys stable when inserting replies so only
/// new replies animate. For long conversations, put top-level replies in a
/// lazy ListView/SliverList (one top-level FrostThread per builder item), rather
/// than placing every top-level reply in one eager replies list.
///
/// By default ([FrostThreadStyle.block]) a top-level thread has the same
/// padding above and below and a hairline that starts at the text column,
/// unless it is the last child of its column; replies sit in a light block
/// under the parent's text.
class FrostThread extends StatefulWidget {
  const FrostThread({
    required this.item,
    this.replies = const [],
    this.collapsedReplyCount = 0,
    this.collapsedRepliesLabel,
    this.onShowReplies,
    this.style = FrostThreadStyle.block,
    super.key,
  }) : assert(collapsedReplyCount >= 0);
  final FrostThreadItem item;
  final List<FrostThread> replies;
  final int collapsedReplyCount;

  /// The whole text of the row that shows collapsed replies, in place of the
  /// counted label. Use it when the number of replies is unknown; the row then
  /// shows even with a [collapsedReplyCount] of 0.
  final String? collapsedRepliesLabel;
  final VoidCallback? onShowReplies;
  final FrostThreadStyle style;
  @override
  State<FrostThread> createState() => _ThreadState();
}

class _ThreadState extends State<FrostThread> {
  Set<Object> _entering = {};
  bool _last = false;
  Object _identity(int index, FrostThread reply) => reply.key ?? index;
  @override
  void didUpdateWidget(FrostThread oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = {for (final (index, reply) in oldWidget.replies.indexed) _identity(index, reply)};
    _entering = {
      for (final (index, reply) in widget.replies.indexed)
        if (!old.contains(_identity(index, reply))) _identity(index, reply),
    };
  }

  void _measure() {
    if (!mounted) return;
    final last = frostEndsVerticalFlow(context);
    if (last != _last) setState(() => _last = last);
  }

  Widget _replyEntry(int index, FrostThread reply, int depth, {required double gap}) => FrostPresenceEntry(
    key: ValueKey(_identity(index, reply)),
    animate: _entering.contains(_identity(index, reply)),
    child: FrostPresence(
      visible: true,
      effect: FrostPresenceEffect.expand,
      alignment: AlignmentDirectional.topStart,
      child: Padding(
        padding: EdgeInsets.only(top: gap),
        child: _ThreadDepth(depth: depth + 1, compact: widget.style == FrostThreadStyle.block, child: reply),
      ),
    ),
  );

  bool get _showsReplyRow => widget.collapsedReplyCount > 0 || widget.collapsedRepliesLabel != null;

  Widget _showReplies(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: FrostButtonControl(
      presentation: FrostButtonPresentation.link,
      label: widget.collapsedRepliesLabel ?? FrostScope.labelsOf(context).showReplies(widget.collapsedReplyCount),
      variant: FrostButtonVariant.plain,
      size: FrostControlSize.compact,
      // In a reply block the link is small and sits on the block's text edge.
      textRole: widget.style == FrostThreadStyle.block ? FrostTextRole.footnote : FrostTextRole.callout,
      edgeAlignment: widget.style == FrostThreadStyle.block ? FrostButtonEdgeAlignment.start : null,
      onPressed: widget.onShowReplies,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final depth = context.dependOnInheritedWidgetOfExactType<_ThreadDepth>()?.depth ?? 0;
    if (widget.style == FrostThreadStyle.lines) return _lines(context, depth);
    final column = _block(context, depth);
    if (depth > 0) return column;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    final tokens = FrostThemeTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: FrostGap.group),
          child: column,
        ),
        if (!_last)
          Padding(
            padding: const EdgeInsetsDirectional.only(start: _avatarExtent + FrostGap.related),
            child: SizedBox(
              height: 1 / MediaQuery.devicePixelRatioOf(context),
              child: ColoredBox(color: tokens.separator),
            ),
          ),
      ],
    );
  }

  Widget _block(BuildContext context, int depth) {
    final hasReplies = widget.replies.isNotEmpty || _showsReplyRow;
    final indent = depth < _maximumIndent ? (depth == 0 ? _avatarExtent : _compactAvatarExtent) + FrostGap.related : 0.0;
    final replies = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, reply) in widget.replies.indexed) _replyEntry(index, reply, depth, gap: index == 0 ? 0 : FrostGap.related),
        if (_showsReplyRow)
          Padding(
            padding: EdgeInsets.only(top: widget.replies.isEmpty ? 0 : FrostGap.inline),
            child: _showReplies(context),
          ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        widget.item,
        if (hasReplies)
          Padding(
            padding: EdgeInsetsDirectional.only(start: indent, top: FrostGap.related),
            // Only the first level of replies gets the block; deeper ones
            // continue inside it without another fill.
            child: depth == 0
                ? FrostSurface(
                    role: FrostSurfaceRole.module,
                    elevated: false,
                    borderRadius: BorderRadius.circular(FrostRadius.sm),
                    child: Padding(padding: const EdgeInsets.all(FrostGap.group), child: replies),
                  )
                : replies,
          ),
      ],
    );
  }

  Widget _lines(BuildContext context, int depth) => _ThreadLayout(
    indent: depth < _maximumIndent ? _avatarExtent + FrostGap.related : 0,
    direction: Directionality.of(context),
    ink: FrostThemeTokens.of(context).threadLine,
    replyCount: widget.replies.length,
    children: [
      widget.item,
      for (final (index, reply) in widget.replies.indexed) _replyEntry(index, reply, depth, gap: FrostGap.related),
      if (_showsReplyRow)
        Padding(
          padding: const EdgeInsets.only(top: FrostGap.related),
          child: _showReplies(context),
        ),
    ],
  );
}

class _ThreadDepth extends InheritedWidget {
  const _ThreadDepth({required this.depth, required this.compact, required super.child});
  final int depth;

  /// Replies in a block use the smaller avatar and tighter rows.
  final bool compact;
  @override
  bool updateShouldNotify(_ThreadDepth oldWidget) => depth != oldWidget.depth || compact != oldWidget.compact;
}

class _AvatarAnchor extends SingleChildRenderObjectWidget {
  const _AvatarAnchor({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderAvatarAnchor();
}

class _RenderAvatarAnchor extends RenderProxyBox {}

class _ThreadData extends ContainerBoxParentData<RenderBox> {}

class _ThreadLayout extends MultiChildRenderObjectWidget {
  const _ThreadLayout({required this.indent, required this.direction, required this.ink, required this.replyCount, required super.children});
  final double indent;
  final TextDirection direction;
  final Color ink;
  final int replyCount;
  @override
  RenderObject createRenderObject(BuildContext context) => FrostThreadRender(indent, direction, ink, replyCount);
  @override
  void updateRenderObject(BuildContext context, covariant FrostThreadRender renderObject) {
    renderObject
      ..indent = indent
      ..direction = direction
      ..ink = ink
      ..replyCount = replyCount
      ..markNeedsLayout();
  }
}

class FrostThreadRender extends RenderBox with ContainerRenderObjectMixin<RenderBox, _ThreadData>, RenderBoxContainerDefaultsMixin<RenderBox, _ThreadData> {
  FrostThreadRender(this.indent, this.direction, this.ink, this.replyCount);
  double indent;
  TextDirection direction;
  Color ink;
  int replyCount;
  @override
  void setupParentData(RenderBox child) {
    if (child.parentData is! _ThreadData) child.parentData = _ThreadData();
  }

  @override
  void performLayout() {
    var y = 0.0;
    var index = 0;
    RenderBox? child = firstChild;
    while (child != null) {
      final inset = index++ == 0 ? 0.0 : math.min(indent, constraints.maxWidth);
      child.layout(
        BoxConstraints(maxWidth: math.max(0, constraints.maxWidth - inset), minWidth: math.max(0, constraints.maxWidth - inset)),
        parentUsesSize: true,
      );
      final data = child.parentData! as _ThreadData;
      data.offset = Offset(direction == TextDirection.rtl ? 0 : inset, y);
      y += child.size.height;
      child = data.nextSibling;
    }
    size = constraints.constrain(Size(constraints.maxWidth, y));
  }

  _RenderAvatarAnchor? _avatar(RenderObject root) {
    if (root is _RenderAvatarAnchor) return root;
    _RenderAvatarAnchor? result;
    root.visitChildren((child) => result ??= _avatar(child));
    return result;
  }

  /// Actual connection geometry, also available to internal render tests.
  List<Path> get connections {
    final paths = <Path>[];
    final parent = firstChild == null ? null : _avatar(firstChild!);
    if (parent == null || replyCount == 0) return paths;
    final rect = MatrixUtils.transformRect(parent.getTransformTo(this), Offset.zero & parent.size);
    final x = rect.center.dx;
    final start = rect.bottom + _connectionGap;
    final targets = <(double, double)>[];
    RenderBox? child = childAfter(firstChild!);
    for (var index = 0; index < replyCount && child != null; index++) {
      final avatar = _avatar(child);
      if (avatar != null && child.size.height > 0) {
        final childRect = MatrixUtils.transformRect(avatar.getTransformTo(this), Offset.zero & avatar.size);
        final data = child.parentData! as _ThreadData;
        final y = math.min(childRect.center.dy, data.offset.dy + child.size.height);
        final end = direction == TextDirection.rtl ? childRect.right + _connectionGap : childRect.left - _connectionGap;
        targets.add((end, y));
      }
      child = childAfter(child);
    }
    if (targets.isEmpty || targets.last.$2 <= start) return paths;
    paths.add(
      Path()
        ..moveTo(x, start)
        ..lineTo(x, targets.last.$2 - (indent == 0 ? 0 : _bendRadius)),
    );
    if (indent > 0) {
      final sign = direction == TextDirection.rtl ? -1.0 : 1.0;
      for (final (end, y) in targets) {
        if (y <= start) continue;
        final radius = math.min(_bendRadius, (end - x).abs());
        paths.add(
          Path()
            ..moveTo(x, math.max(start, y - radius))
            ..quadraticBezierTo(x, y, x + sign * radius, y)
            ..lineTo(end, y),
        );
      }
    }
    return paths;
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final canvas = context.canvas;
    canvas.save();
    canvas.translate(offset.dx, offset.dy);
    final paint = Paint()
      ..color = ink
      ..strokeWidth = _lineWidth
      ..style = PaintingStyle.stroke;
    for (final path in connections) {
      canvas.drawPath(path, paint);
    }
    canvas.restore();
    defaultPaint(context, offset);
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => defaultHitTestChildren(result, position: position);
}
