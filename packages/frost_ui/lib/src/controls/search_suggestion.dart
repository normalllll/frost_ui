import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../display/data_dot.dart';
import '../feedback/activity_indicator.dart';
import '../foundation/_touch_targets.dart';
import '../foundation/density.dart';
import '../foundation/icon_data.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/typography.dart';
import '../lists/_row_scope.dart';
import '../lists/list_row.dart';
import '../overlays/_popover_surface.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/click_surface.dart';
import '../primitives/glyph.dart';
import '../primitives/keyline.dart';
import '../primitives/text.dart';
import '_search_options.dart';
import 'buttons.dart';

enum _OptionKind { custom, row, action }

/// A selectable region in the content of [FrostSearchInput.suggesting] or
/// [FrostCaptionSearch]. It never takes focus: editing focus stays in the
/// field, and the field's arrow keys move a highlight across the options by
/// their place on screen, Enter selects the highlighted one and a tap or
/// click selects any. Frost draws the highlight as list rows draw theirs.
///
/// Selecting runs [onSelected] and then closes the dropdown, unless
/// [keepsOpen]. Give options in content that changes keys of their own, so a
/// highlight stays on the option the user chose.
class FrostSearchOption extends StatefulWidget {
  const FrostSearchOption({required this.onSelected, this.keepsOpen = false, this.semanticLabel, required this.child, super.key})
    : _kind = _OptionKind.custom,
      _leading = false;

  const FrostSearchOption._row(this._leading, {required this.onSelected, required this.keepsOpen, required this.semanticLabel, required this.child})
    : _kind = _OptionKind.row;

  const FrostSearchOption._action({required this.onSelected, required this.semanticLabel, required this.child})
    : _kind = _OptionKind.action,
      keepsOpen = true,
      _leading = false;

  final VoidCallback onSelected;

  /// Selecting this option leaves the dropdown open, with focus in the field,
  /// its text and caret as they are and nothing highlighted, so several
  /// options can be chosen in a row (adding tags, say) and Enter then submits
  /// the query. Arrow keys start a highlight. Esc, a tap outside and
  /// submitting still close the dropdown.
  final bool keepsOpen;

  /// What a screen reader hears for this option, both on the option itself and
  /// in the field's announcement while it is highlighted. Without it the
  /// option reads its own content and the field announces only its position.
  final String? semanticLabel;
  final Widget child;
  final _OptionKind _kind;
  final bool _leading;

  @override
  State<FrostSearchOption> createState() => _FrostSearchOptionState();
}

class _FrostSearchOptionState extends State<FrostSearchOption> implements FrostSearchOptionTarget {
  final _handle = FrostListItemHandle();
  final _text = GlobalKey();
  FrostSearchOptions? _options;
  @override
  FrostRenderSearchOption? box;

  @override
  String? get semanticLabel => widget.semanticLabel;
  @override
  bool get hasLeading => widget._leading;
  @override
  VoidCallback get onSelected => widget.onSelected;
  @override
  FrostSearchOptionExit get exit => switch (widget._kind) {
    _OptionKind.action => FrostSearchOptionExit.stay,
    _ when widget.keepsOpen => FrostSearchOptionExit.reopen,
    _ => FrostSearchOptionExit.dismiss,
  };

  @override
  void highlightChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final options = FrostSearchOptionScope.of(context).options;
    if (identical(options, _options)) return;
    _options?.leave(this);
    _options = options..join(this);
  }

  // Rows join and leave as the tree builds, so a dropdown counts them before
  // it lays out; a moved option leaves and joins again.
  @override
  void activate() {
    super.activate();
    _options?.join(this);
  }

  @override
  void deactivate() {
    _options?.leave(this);
    super.deactivate();
  }

  @override
  void didUpdateWidget(FrostSearchOption oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A label or leading change reaches the announcement and the icon column.
    _options?.updated(this);
  }

  void _select() => _options!.select(this);

  @override
  Widget build(BuildContext context) {
    final scope = FrostSearchOptionScope.of(context);
    final highlighted = scope.options.isHighlighted(this);
    final child = switch (widget._kind) {
      // The row draws its own highlight and surface from the list item scope,
      // exactly as rows of a list do.
      _OptionKind.row => FrostListItemScope(
        selected: null,
        reserveIconColumn: scope.reserveIconColumn,
        highlighted: highlighted,
        onSelected: _select,
        handle: _handle,
        viewportInset: frostBleedOutsetsOf(context),
        child: FrostRowPlacement(textAnchor: _text, corners: null, child: widget.child),
      ),
      // A text action: a finger reaches it within the touch-sized area around
      // it, while its text keeps its place in the title row.
      _OptionKind.action => FrostTouchTarget(
        enabled: true,
        child: FrostClickHighlight(
          highlighted: highlighted,
          child: FrostClickSurface(onTap: _select, shape: FrostClickShape.rounded(FrostRadius.borderRadius(FrostRadius.xs)), child: widget.child),
        ),
      ),
      // One node carries the tap and the label: the semantic label, or the
      // content's own text merged in.
      _OptionKind.custom => MergeSemantics(
        child: Semantics(
          button: true,
          label: widget.semanticLabel,
          child: FrostClickHighlight(
            highlighted: highlighted,
            child: FrostClickSurface(
              onTap: _select,
              shape: FrostClickShape.rounded(FrostRadius.borderRadius(FrostRadius.sm)),
              child: widget.semanticLabel == null ? widget.child : ExcludeSemantics(child: widget.child),
            ),
          ),
        ),
      ),
    };
    return MouseRegion(
      onEnter: (event) => scope.options.pointerEntered(this, event),
      onHover: (event) => scope.options.pointerMoved(this, event),
      onExit: (_) => scope.options.pointerExited(this),
      child: FrostSearchOptionBox(target: this, child: child),
    );
  }
}

/// A suggestion line in the dropdown: a list row with an optional leading icon
/// or data dot, detail, trailing value and remove button. Selecting it is a
/// [FrostSearchOption] selection.
class FrostSearchSuggestionRow extends StatelessWidget {
  const FrostSearchSuggestionRow({
    required this.label,
    this.icon,
    this.dataColor,
    this.detail,
    this.inlineDetail = false,
    this.value,
    required this.onSelected,
    this.onRemove,
    this.keepsOpen = false,
    super.key,
  });
  final String label;
  final FrostIconData? icon;

  /// Category index into the current theme, using the same dot as FrostTag.
  /// When supplied, this marker takes the leading place of [icon].
  final int? dataColor;
  final String? detail;

  /// Uses FrostListRow.inlineSubtitle: the full label takes precedence over an
  /// ellipsized, single-line detail. Complete detail remains in semantics.
  final bool inlineDetail;

  /// Trailing metadata, with the shared row's wrapping and accessibility rules.
  final String? value;
  final VoidCallback onSelected;
  final VoidCallback? onRemove;

  /// As [FrostSearchOption.keepsOpen].
  final bool keepsOpen;

  @override
  Widget build(BuildContext context) => FrostSearchOption._row(
    icon != null || dataColor != null,
    onSelected: onSelected,
    keepsOpen: keepsOpen,
    semanticLabel: '$label${inlineDetail && detail != null ? ', $detail' : ''}',
    child: FrostListRow(
      title: label,
      subtitle: switch (detail) {
        null => null,
        final detail => inlineDetail ? FrostRowSubtitle.inline(detail) : FrostRowSubtitle(detail),
      },
      leading: dataColor == null ? (icon == null ? null : FrostGlyph.icon(icon!)) : FrostLeading.custom(FrostDataDot(dataColor!)),
      value: value,
      trailing: onRemove == null
          ? null
          : FrostButton.icon(
              icon: FrostIconSet.of(context).close,
              label: FrostScope.labelsOf(context).remove,
              size: FrostControlSize.compact,
              onPressed: onRemove,
            ),
    ),
  );
}

/// A titled group of dropdown content. Sections are spaced apart; the first
/// one in the content starts on the dropdown's inset. A section without
/// children shows neither its title nor its action.
class FrostSearchSection extends StatelessWidget {
  const FrostSearchSection({this.title, this.actionLabel, this.onAction, required this.children, super.key});
  final String? title;

  /// A text action at the end of the title row, such as clearing history or
  /// managing saved tags. It is an option the arrow keys reach before the
  /// section's children; running it leaves the dropdown open and its highlight
  /// where it is. Both fields are required for the action to show.
  final String? actionLabel;
  final VoidCallback? onAction;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final action = actionLabel != null && onAction != null;
    return _SectionColumn(
      touchDevice: !FrostDensity.of(context).usesPointer,
      children: [
        if (title != null || action) ...[
          const FrostSearchGap(height: frostPopoverContentInset, leading: 0),
          Padding(
            padding: const EdgeInsets.only(bottom: FrostGap.inline),
            child: _RowAligned(
              child: action
                  ? _SectionTitle(title: title, actionLabel: actionLabel!, onAction: onAction!)
                  : FrostText(title!, role: FrostTextRole.caption, tone: FrostTextTone.secondary),
            ),
          ),
        ],
        ...children,
      ],
    );
  }
}

/// A section's title with its trailing text action.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.actionLabel, required this.onAction});
  final String? title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: title == null ? const SizedBox.shrink() : FrostText(title!, role: FrostTextRole.caption, tone: FrostTextTone.secondary, maxLines: 1),
      ),
      const SizedBox(width: FrostGap.related),
      // The action text ends on the content edge that the title starts on;
      // its highlight padding is spent outside that line.
      Transform.translate(
        offset: Offset(Directionality.of(context) == TextDirection.rtl ? -_actionInset : _actionInset, 0),
        child: _ActionAnchor(
          child: FrostSearchOption._action(
            onSelected: onAction,
            semanticLabel: [actionLabel, ?title].join(', '),
            child: Semantics(
              button: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _actionInset, vertical: 2),
                child: FrostText(actionLabel, role: FrostTextRole.caption, tone: FrostTextTone.accent, maxLines: 1),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

const _actionInset = 6.0;

/// A status line in the dropdown: progress while the App loads, and a message
/// for no results or a failed load. It is not selectable.
class FrostSearchStatus extends StatelessWidget {
  const FrostSearchStatus({this.loading = false, this.message, super.key});
  final bool loading;
  final String? message;

  @override
  Widget build(BuildContext context) {
    if (!loading && message == null) return const SizedBox.shrink();
    // A page list has no panel inset; a status line alone starts where a
    // first row's text would rather than on the field.
    final inline = FrostSearchOptionScope.of(context).inline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FrostSearchGap(height: FrostGap.related, leading: inline ? FrostGap.group : 0),
        _RowAligned(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading) FrostActivityIndicator(size: FrostControlSize.compact, semanticLabel: FrostScope.labelsOf(context).loading),
              if (loading && message != null) const SizedBox(width: FrostGap.related),
              if (message case final message?)
                Expanded(
                  child: FrostText(message, role: FrostTextRole.footnote, tone: FrostTextTone.secondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A non-row line in the dropdown (a section title, the status line), inset
/// by the same list bleed rows inset their content by, so titles, rows and
/// their trailing values share one pair of edges.
class _RowAligned extends StatelessWidget {
  const _RowAligned({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(padding: frostBleedOutsetsOf(context), child: child);
}

/// A section's column. While the pointer is a finger, a touch within the
/// touch-sized area around the title's action counts as a touch on the
/// action, ahead of the rows below that the area overlaps; the layout and
/// the action's text stay as they are.
class _SectionColumn extends Column {
  const _SectionColumn({required this.touchDevice, required super.children})
    : super(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min);
  final bool touchDevice;

  @override
  RenderFlex createRenderObject(BuildContext context) => _RenderSectionColumn(
    touchDevice: touchDevice,
    direction: direction,
    mainAxisAlignment: mainAxisAlignment,
    mainAxisSize: mainAxisSize,
    crossAxisAlignment: crossAxisAlignment,
    textDirection: getEffectiveTextDirection(context),
    verticalDirection: verticalDirection,
  );

  @override
  void updateRenderObject(BuildContext context, RenderFlex renderObject) {
    super.updateRenderObject(context, renderObject);
    (renderObject as _RenderSectionColumn).touchDevice = touchDevice;
  }
}

class _RenderSectionColumn extends RenderFlex {
  _RenderSectionColumn({
    required this.touchDevice,
    super.direction,
    super.mainAxisAlignment,
    super.mainAxisSize,
    super.crossAxisAlignment,
    super.textDirection,
    super.verticalDirection,
  });
  bool touchDevice;
  _RenderActionAnchor? _action;

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) {
    final action = _action;
    if (action != null && action.attached && action.hasSize && frostExpectsFinger(touchDevice: touchDevice)) {
      final bounds = MatrixUtils.transformRect(action.getTransformTo(this), Offset.zero & action.size);
      final minimum = FrostControlSize.minimumHitHeight(touch: true);
      final area = Rect.fromCenter(
        center: bounds.center,
        width: bounds.width < minimum ? minimum : bounds.width,
        height: bounds.height < minimum ? minimum : bounds.height,
      );
      if (!bounds.contains(position) && area.contains(position)) {
        final edge = Offset(position.dx.clamp(bounds.left, bounds.right - .01), position.dy.clamp(bounds.top, bounds.bottom - .01));
        if (super.hitTestChildren(result, position: edge)) return true;
      }
    }
    return super.hitTestChildren(result, position: position);
  }
}

/// Marks the title's action for its section column.
class _ActionAnchor extends SingleChildRenderObjectWidget {
  const _ActionAnchor({required super.child});
  @override
  RenderObject createRenderObject(BuildContext context) => _RenderActionAnchor();
}

class _RenderActionAnchor extends RenderProxyBox {
  _RenderSectionColumn? _column;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    for (var node = parent; node != null; node = node.parent) {
      if (node is _RenderSectionColumn) {
        _column = node.._action = this;
        break;
      }
    }
  }

  @override
  void detach() {
    if (identical(_column?._action, this)) _column!._action = null;
    _column = null;
    super.detach();
  }
}
