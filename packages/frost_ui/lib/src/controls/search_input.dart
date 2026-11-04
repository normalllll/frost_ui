import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../display/data_dot.dart';
import '../feedback/activity_indicator.dart';
import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/_caption_search_scope.dart';
import '../layout/_header_search_body.dart';
import '../layout/_header_search_scope.dart';
import '../layout/column_placement.dart';
import '../layout/content_viewport.dart';
import '../layout/window_caption_scope.dart';
import '../lists/_list_input.dart';
import '../lists/_row_scope.dart';
import '../lists/list.dart';
import '../lists/list_row.dart';
import '../overlays/_anchored_panel_layout.dart';
import '../overlays/_popover_surface.dart';
import '../overlays/adaptive_panel.dart';
import '../primitives/_click_surface_visuals.dart';
import '../primitives/_directional_icon.dart';
import '../primitives/click_surface.dart';
import '../primitives/glyph.dart';
import '../primitives/keyline.dart';
import '../primitives/presence.dart';
import '../primitives/text.dart';
import '_field_clear_button.dart';
import '_field_options.dart';
import '_field_row.dart';
import 'buttons.dart';
import 'field_appearance.dart';
import 'search_suggestion.dart';
import 'text_field.dart';
import 'token_field.dart';

/// Where [FrostSearchInput.suggesting] lists its suggestions.
enum FrostSuggestionPlacement {
  /// A panel anchored under the field, over the page. It never takes editing
  /// focus and opens above the field when there is no room below it.
  overlay,

  /// The field followed by the suggestion list in the page flow, at every
  /// width. In a bounded height the list takes the rest of it below the field
  /// and scrolls inside; in an unbounded one it fits its rows, up to the view
  /// height above the keyboard. The field and the rows share the page's
  /// content column, and take one when they are not already inside one; the
  /// list's viewport keeps the full width. Give a page that reaches under a
  /// soft keyboard its keyboard inset, as for any page body.
  inline,

  /// [overlay] where an anchored panel fits, [inline] where Frost presents
  /// panels as sheets (narrow windows), the same rule other panels follow.
  /// The field keeps its editing state when the window crosses the width.
  ///
  /// A field in a [FrostPageHeader] is never followed by its list in the
  /// header row. On narrow windows, in the header of a Frost page template
  /// such as [FrostBrowseLayout], the list takes the page body below the
  /// header row instead: it scrolls there above the soft keyboard, section
  /// tabs below the header hide, and the page content stays laid out
  /// underneath, hidden, until the list closes. A header outside a template
  /// keeps the anchored panel.
  adaptive,
}

/// Search field using the caller's controller directly, including token rules.
///
/// The default constructor is the plain field. [FrostSearchInput.suggesting]
/// adds suggestions, progress and a status message, listed in an anchored
/// panel or in the page ([FrostSuggestionPlacement]); they never take editing
/// focus from the field.
class FrostSearchInput extends StatelessWidget {
  const FrostSearchInput({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onSubmitted,
    this.onClear,
    this.onDismiss,
    this.actions = const [],
    this.hint,
    this.leadingIcon = false,
    this.autofocus = false,
    this.size,
    this.appearance,
    super.key,
  }) : suggestions = const [],
       loading = false,
       message = null,
       placement = FrostSuggestionPlacement.overlay,
       _suggesting = false;

  /// A search field with suggestions. They show while the field has focus and
  /// there are suggestions, [loading] or a [message]; Escape, choosing an item
  /// or tapping outside hides them until the query changes or focus returns.
  const FrostSearchInput.suggesting({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onSubmitted,
    required this.suggestions,
    this.loading = false,
    this.message,
    this.placement = FrostSuggestionPlacement.adaptive,
    this.onClear,
    this.onDismiss,
    this.actions = const [],
    this.hint,
    this.leadingIcon = false,
    this.autofocus = false,
    this.size,
    this.appearance,
    super.key,
  }) : _suggesting = true;

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool autofocus;
  final String placeholder;
  final ValueChanged<String> onSubmitted;
  final VoidCallback? onClear;

  /// Called when Escape dismisses this field's suggestions / surrounding search.
  final VoidCallback? onDismiss;

  /// Structural actions should be compact FrostButton.icon controls.
  final List<Widget> actions;

  /// Short text before the clear button and [actions] while the field has no
  /// focus; the first thing to go when the width runs out. The App keeps it in
  /// step with its own bindings ([FrostShortcut.hintLabel]). None by default.
  final String? hint;

  /// Optional decorative search icon. The trailing submit action is always
  /// available, so queries can be submitted without opening a soft keyboard.
  final bool leadingIcon;
  final FrostControlSize? size;
  final FrostFieldAppearance? appearance;

  /// Suggestion groups of [FrostSearchInput.suggesting]; empty for the plain
  /// field.
  final List<FrostSearchSuggestionGroup> suggestions;

  /// Shows progress in the suggestion list, retaining existing items. Progress
  /// is not selectable and does not intercept editing keys.
  final bool loading;

  /// Application-provided loading, empty-result, or failure explanation,
  /// shown in the suggestion list even when suggestions are empty.
  final String? message;

  /// Where the suggestions show; [FrostSuggestionPlacement.adaptive] by default.
  final FrostSuggestionPlacement placement;

  final bool _suggesting;

  // The submit button's rule, for every way of submitting: blank text has nothing to send.
  void _submit(String text) {
    if (text.trim().isNotEmpty) onSubmitted(text);
  }

  @override
  Widget build(BuildContext context) => _suggesting ? _SuggestingSearchInput(input: this) : _PlainSearchInput(input: this);
}

// Keys both kinds leave to the editor: releases, keys while unfocused, and any
// key during IME composition.
bool _forEditor(FrostSearchInput input, KeyEvent event) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent || !input.focusNode.hasFocus) return true;
  final composing = input.controller.value.composing;
  return composing.isValid && !composing.isCollapsed;
}

// Modified submission belongs to the App (for example opening a tab), never to
// a highlighted suggestion's plain callback.
bool _isModifiedEnter(KeyEvent event) =>
    event.logicalKey == LogicalKeyboardKey.enter && (HardwareKeyboard.instance.isControlPressed || HardwareKeyboard.instance.isMetaPressed);

// A page header may expand this field over a row too narrow for it. The
// caption search keeps its own expansion even when moved into a header.
void _reportFocus(BuildContext context, FocusNode node) {
  if (node.hasFocus && context.getInheritedWidgetOfExactType<FrostCaptionFieldScope>() == null) {
    FrostHeaderSearchScope.read(context)?.onFocused(node);
  }
}

/// The plain field: no suggestion list, highlight or overlay.
class _PlainSearchInput extends StatefulWidget {
  const _PlainSearchInput({required this.input});
  final FrostSearchInput input;
  @override
  State<_PlainSearchInput> createState() => _PlainSearchInputState();
}

class _PlainSearchInputState extends State<_PlainSearchInput> {
  FrostSearchInput get _input => widget.input;

  @override
  void initState() {
    super.initState();
    _input.focusNode.addListener(_focusChanged);
  }

  @override
  void didUpdateWidget(_PlainSearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input.focusNode != _input.focusNode) {
      oldWidget.input.focusNode.removeListener(_focusChanged);
      _input.focusNode.addListener(_focusChanged);
    }
  }

  @override
  void dispose() {
    _input.focusNode.removeListener(_focusChanged);
    super.dispose();
  }

  void _focusChanged() {
    // The trailing submit action and the hint follow focus.
    setState(() {});
    _reportFocus(context, _input.focusNode);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (_forEditor(_input, event)) return KeyEventResult.ignored;
    final header = FrostHeaderSearchScope.read(context);
    if (event.logicalKey == LogicalKeyboardKey.escape && (_input.onDismiss != null || (header?.expanded ?? false))) {
      _input.onDismiss?.call();
      if (header?.expanded ?? false) header!.onDismissed();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _input._submit(_input.controller.text);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    onKeyEvent: _key,
    canRequestFocus: false,
    skipTraversal: true,
    child: FrostCaptionRegion(
      kind: FrostHitKind.client,
      child: TextFieldTapRegion(
        child: _SearchField(input: _input, listenable: _input.controller, onSubmitted: _input._submit),
      ),
    ),
  );
}

/// The editor, clear button, App actions and submit action that both kinds
/// show. [semanticHint] announces the highlighted suggestion.
class _SearchField extends StatelessWidget {
  const _SearchField({required this.input, required this.listenable, required this.onSubmitted, this.semanticHint});
  final FrostSearchInput input;

  /// Rebuilds the trailing actions and the announcement.
  final Listenable listenable;
  final ValueChanged<String> onSubmitted;
  final String? Function()? semanticHint;

  @override
  Widget build(BuildContext context) => FrostFieldScope(
    appearance: input.appearance ?? FrostFieldScope.maybeOf(context) ?? FrostFieldAppearance.subtle,
    child: ListenableBuilder(
      listenable: listenable,
      builder: (context, _) {
        final leading = input.leadingIcon ? FrostIconSet.of(context).search : null;
        final trailing = FrostControlScope(
          size: FrostControlSize.compact,
          child: FrostFieldTrailing(
            children: [
              FrostFieldIconSlot(
                child: FrostFieldClearButton(visible: input.controller.text.isNotEmpty, onClear: input.onClear ?? input.controller.clear),
              ),
              for (final action in input.actions) FrostFieldIconSlot(child: action),
              // Like the caption field's rest state, an empty unfocused field
              // has nothing to submit; its width goes to the placeholder.
              if (input.focusNode.hasFocus || (input.controller.text.isNotEmpty && !FrostCaptionFieldScope.of(context)))
                FrostFieldIconSlot(
                  child: FrostButton.icon(
                    icon: frostForwardIcon(context),
                    label: FrostScope.labelsOf(context).search,
                    size: FrostControlSize.compact,
                    onPressed: input.controller.text.trim().isEmpty ? null : () => input._submit(input.controller.text),
                  ),
                ),
              if (input.hint case final hint? when !input.focusNode.hasFocus)
                FrostFieldHintSlot(
                  child: Container(
                    margin: const EdgeInsetsDirectional.only(end: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: FrostThemeTokens.of(context).separator),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      hint,
                      style: FrostTypography.of(
                        context,
                      ).style(FrostTextRole.caption, tabular: true).copyWith(fontSize: 10.5, color: FrostThemeTokens.of(context).textTertiary),
                    ),
                  ),
                ),
            ],
          ),
        );
        final Widget field;
        if (input.controller case final FrostTokenEditingController tokens) {
          field = FrostTokenField(
            controller: tokens,
            focusNode: input.focusNode,
            autofocus: input.autofocus,
            placeholder: input.placeholder,
            onSubmitted: onSubmitted,
            onEditingComplete: () {},
            onTapOutside: (_) => input.focusNode.unfocus(),
            textInputAction: TextInputAction.search,
            leading: leading,
            trailing: trailing,
            size: input.size,
          );
        } else {
          field = FrostTextField(
            controller: input.controller,
            focusNode: input.focusNode,
            autofocus: input.autofocus,
            placeholder: input.placeholder,
            onSubmitted: onSubmitted,
            onEditingComplete: () {},
            onTapOutside: (_) => input.focusNode.unfocus(),
            textInputAction: TextInputAction.search,
            leading: leading,
            trailing: trailing,
            size: input.size,
          );
        }
        return FrostFieldOptions(semanticHint: semanticHint?.call(), invalid: FrostFieldOptions.of(context)?.invalid ?? false, child: field);
      },
    ),
  );
}

// A null item is the group's title row with its action; it is highlighted and
// activated like the items so the action stays reachable from the field.
typedef _Suggestion = ({FrostSearchSuggestionGroup group, FrostSearchSuggestion? item, bool titled});

bool _hasAction(FrostSearchSuggestionGroup group) => group.actionLabel != null && group.onAction != null;
Object _identity(_Suggestion entry) => entry.item ?? entry.group;

/// [FrostSearchInput.suggesting]: the field with its suggestion list, keyboard
/// highlight and overlay panel.
class _SuggestingSearchInput extends StatefulWidget {
  const _SuggestingSearchInput({required this.input});
  final FrostSearchInput input;
  @override
  State<_SuggestingSearchInput> createState() => _SuggestingSearchInputState();
}

class _SuggestingSearchInputState extends State<_SuggestingSearchInput> {
  final _overlay = OverlayPortalController();
  final _fieldKey = GlobalKey();
  final _listKey = GlobalKey();
  final _list = FrostListInputController<_Suggestion>();
  final _highlightRevision = ValueNotifier<int>(0);
  FrostHeaderSearchBody? _body;
  List<_Suggestion> _entries = const [], _lastEntries = const [];
  _Suggestion? _highlighted;
  String _text = '';
  bool _suppressed = false;
  int _generation = 0;
  // The list that is built, which is still the previous one while a new
  // generation waits for this widget's build.
  int _builtGeneration = 0;
  bool _keptOpen = false;
  // False while the field is in a subtree with its tickers off, such as title
  // content the shell keeps offstage: the field keeps its text and focus, and
  // its list is not shown.
  bool _active = true;

  FrostSearchInput get _input => widget.input;

  /// Where the list goes, read once per build.
  _Placement _placement = _Placement.overlay;
  _Placement _resolvePlacement() {
    switch (_input.placement) {
      case FrostSuggestionPlacement.overlay:
        return _Placement.overlay;
      case FrostSuggestionPlacement.inline:
        return _Placement.inline;
      case FrostSuggestionPlacement.adaptive:
        if (!frostPanelUsesSheet(context)) return _Placement.overlay;
        // A header row has no room below the field; the page body below the
        // header does, when a page template holds the header.
        if (FrostHeaderSearchScope.read(context) == null) return _Placement.inline;
        return FrostHeaderSearchBodyScope.maybeOf(context) == null ? _Placement.overlay : _Placement.body;
    }
  }

  /// The list sits in the page rather than in a floating panel.
  bool get _inline => _placement != _Placement.overlay;
  bool get _visible => _active && _input.focusNode.hasFocus && !_suppressed && (_entries.isNotEmpty || _input.loading || _input.message != null);

  @override
  void initState() {
    super.initState();
    _text = _input.controller.text;
    _readEntries();
    _input.controller.addListener(_queryChanged);
    _input.focusNode.addListener(_focusChanged);
    // Always attach a portal. Visibility is derived during layout so supplied
    // suggestions get correct geometry on the very first frame.
    _overlay.show();
  }

  void _readEntries() {
    _entries = [
      for (final group in _input.suggestions)
        if (group.items.isNotEmpty) ...[
          if (_hasAction(group)) (group: group, item: null, titled: true),
          for (var i = 0; i < group.items.length; i++) (group: group, item: group.items[i], titled: i == 0 && !_hasAction(group) && group.title != null),
        ],
    ];
    if (!listEquals(_entries, _lastEntries) && _list.attached && _builtGeneration == _generation) {
      // A remove button can temporarily hover another row; list mutations
      // restore the keyboard item, including the input's announcement.
      _highlighted = _list.keyboardItem;
    }
    if (_highlighted != null) {
      final next = _entries.where((entry) => identical(_identity(entry), _identity(_highlighted!))).firstOrNull;
      if (next != null) {
        _highlighted = next;
      } else {
        final index = _lastEntries.indexOf(_highlighted!);
        _highlighted = _entries.isEmpty ? null : _entries[index.clamp(0, _entries.length - 1)];
      }
    }
    if (_entries.isNotEmpty) _lastEntries = _entries;
  }

  @override
  void didUpdateWidget(_SuggestingSearchInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final old = oldWidget.input;
    if (old.controller != _input.controller) {
      old.controller.removeListener(_queryChanged);
      _input.controller.addListener(_queryChanged);
      _text = _input.controller.text;
      _suppressed = false;
    }
    if (old.focusNode != _input.focusNode) {
      old.focusNode.removeListener(_focusChanged);
      _input.focusNode.addListener(_focusChanged);
    }
    _readEntries();
  }

  void _queryChanged() {
    if (_text == _input.controller.text) return;
    _text = _input.controller.text;
    setState(() {
      _suppressed = false;
      _highlighted = null;
      _keptOpen = false;
      _generation++;
    });
  }

  void _focusChanged() {
    setState(() {
      _suppressed = false;
      _highlighted = null;
      _keptOpen = false;
      _generation++;
    });
    _reportFocus(context, _input.focusNode);
  }

  void _dismiss() {
    if (!mounted) return;
    setState(() {
      _suppressed = true;
      _highlighted = null;
    });
  }

  void _select(_Suggestion entry) {
    if (entry.item == null) {
      // A group action (clear, manage) changes the suggestions in place.
      entry.group.onAction?.call();
      return;
    }
    final keepsOpen = entry.item!.keepsOpen || entry.group.keepsOpen;
    try {
      entry.item!.onSelected();
    } finally {
      if (mounted) {
        if (keepsOpen) {
          _reopen();
        } else {
          // Updating the query as part of choosing an item is still this selection.
          // Reopen only for a later query edit or a new focus entry.
          _dismiss();
        }
      }
    }
  }

  /// A keep-open selection: the list stays up for the new query with nothing
  /// highlighted, so Enter submits. A mouse left over the chosen row highlights
  /// again once it moves; an arrow key starts at the first item.
  void _reopen() {
    _input.focusNode.requestFocus();
    setState(() {
      _suppressed = false;
      _highlighted = null;
      _keptOpen = true;
      _generation++;
    });
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (_forEditor(_input, event)) return KeyEventResult.ignored;
    final header = FrostHeaderSearchScope.read(context);
    if (event.logicalKey == LogicalKeyboardKey.escape && (_visible || _input.onDismiss != null || (header?.expanded ?? false))) {
      _dismiss();
      _input.onDismiss?.call();
      if (header?.expanded ?? false) header!.onDismissed();
      return KeyEventResult.handled;
    }
    if (_isModifiedEnter(event)) {
      if (_keptOpen) _dismiss();
      _input._submit(_input.controller.text);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && !_visible && _entries.isNotEmpty) {
      setState(() {
        _suppressed = false;
        _highlighted = null;
        _generation++;
      });
      return KeyEventResult.handled;
    }
    if (_visible &&
        (event.logicalKey == LogicalKeyboardKey.arrowDown || event.logicalKey == LogicalKeyboardKey.arrowUp || event.logicalKey == LogicalKeyboardKey.enter)) {
      final result = _list.handle?.call(event) ?? KeyEventResult.ignored;
      if (result == KeyEventResult.handled) return result;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _submit(_input.controller.text);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _submit(String value) {
    if (_visible && _highlighted != null) {
      _select(_highlighted!);
    } else {
      if (_keptOpen) _dismiss();
      _input._submit(value);
    }
  }

  @override
  void dispose() {
    if (_body?.showing ?? false) _body!.showing = false;
    _input.controller.removeListener(_queryChanged);
    _input.focusNode.removeListener(_focusChanged);
    _highlightRevision.dispose();
    super.dispose();
  }

  String? _announcement() {
    final index = _highlighted == null ? -1 : _entries.indexOf(_highlighted!);
    if (index < 0) return null;
    final description = switch (_highlighted!) {
      (item: final item?, group: _, titled: _) => '${item.label}${item.inlineDetail && item.detail != null ? ', ${item.detail}' : ''}',
      (item: null, :final group, titled: _) => [group.actionLabel!, ?group.title].join(', '),
    };
    return '$description ${FrostScope.labelsOf(context).itemPosition(index + 1, _entries.length)}';
  }

  Widget _suggestionList(BuildContext context) => KeyedSubtree(
    key: _listKey,
    child: FrostListInput<_Suggestion>(
      controller: _list,
      hoverNeedsMove: _keptOpen,
      footer: _input.loading || _input.message != null
          ? _suggestionColumn(
              Padding(
                // A page list has no panel inset; a status-only line starts
                // where a first row's text would rather than on the field.
                padding: EdgeInsets.only(
                  top: _entries.isNotEmpty
                      ? FrostGap.related
                      : _inline
                      ? FrostGap.group
                      : 0,
                ),
                child: _RowAligned(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_input.loading) FrostActivityIndicator(size: FrostControlSize.compact, semanticLabel: FrostScope.labelsOf(context).loading),
                      if (_input.loading && _input.message != null) const SizedBox(width: FrostGap.related),
                      if (_input.message case final message?)
                        Expanded(
                          child: FrostText(message, role: FrostTextRole.footnote, tone: FrostTextTone.secondary),
                        ),
                    ],
                  ),
                ),
              ),
            )
          : null,
      identity: _identity,
      onHighlight: (item, _) {
        _highlighted = item;
        _highlightRevision.value++;
      },
      child: FrostList<_Suggestion>(
        key: ValueKey(_generation),
        items: _visible ? _entries : _lastEntries,
        reserveIconColumn: (_visible ? _entries : _lastEntries).any((entry) => entry.item?.icon != null || entry.item?.dataColor != null),
        onSelected: _select,
        itemBuilder: (context, entry, _) {
          final titlePadding = EdgeInsets.only(
            top: identical(_identity(entry), _identity((_visible ? _entries : _lastEntries).first)) ? 0 : frostPopoverContentInset,
            bottom: FrostGap.inline,
          );
          final item = entry.item;
          if (item == null) {
            return _suggestionColumn(
              Padding(
                padding: titlePadding,
                child: _RowAligned(
                  child: _GroupTitle(title: entry.group.title, actionLabel: entry.group.actionLabel!),
                ),
              ),
            );
          }
          return _suggestionColumn(
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (entry.titled)
                  Padding(
                    padding: titlePadding,
                    child: _RowAligned(
                      child: FrostText(entry.group.title!, role: FrostTextRole.caption, tone: FrostTextTone.secondary),
                    ),
                  ),
                FrostListRow(
                  title: item.label,
                  subtitle: switch (item.detail) {
                    null => null,
                    final detail => item.inlineDetail ? FrostRowSubtitle.inline(detail) : FrostRowSubtitle(detail),
                  },
                  leading: item.dataColor == null
                      ? (item.icon == null ? null : FrostGlyph.icon(item.icon!))
                      : FrostLeading.custom(FrostDataDot(item.dataColor!)),
                  value: item.value,
                  trailing: item.onRemove == null
                      ? null
                      : FrostButton.icon(
                          icon: FrostIconSet.of(context).close,
                          label: FrostScope.labelsOf(context).remove,
                          size: FrostControlSize.compact,
                          onPressed: item.onRemove,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    ),
  );

  // A page list takes the page's content column, unless the App already placed
  // it inside one (a browse layout's slivers, say): a second column would inset
  // the titles and rows again and leave them short of the field and Cancel.
  Widget _suggestionColumn(Widget child) => !_inline
      ? child
      : Builder(
          builder: (context) => switch (FrostKeyline.maybeOf(context)) {
            FrostKeyline(insideContainer: false, contentStart: > 0) => child,
            _ => FrostContentColumn(maxWidth: FrostPageColumnWidth.of(context), child: child),
          },
        );

  Widget _panel(BuildContext context, OverlayChildLayoutInfo info) {
    final field = _fieldKey.currentContext?.findRenderObject();
    if (field is! RenderBox || !field.hasSize) return const SizedBox.shrink();
    // OverlayPortal uses its nearest Navigator overlay. A root-overlay origin
    // would count an offset content pane twice in a nested shell.
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final anchor = overlay.globalToLocal(field.localToGlobal(Offset.zero)) & field.size;
    final media = MediaQuery.of(this.context);
    final insets = EdgeInsets.fromLTRB(media.padding.left, media.padding.top, media.padding.right, math.max(media.padding.bottom, media.viewInsets.bottom));
    // Suggestions may use the content area below the field, down to the usual
    // panel margin, and scroll inside beyond that. Half the overlay remains the
    // floor, so a field low on the page can still open its panel above itself.
    final below = info.overlaySize.height - insets.bottom - frostAnchoredPanelMargin - anchor.bottom - frostAnchoredPanelGap.dy;
    final maximumHeight = math.max(0.0, math.max(below, (info.overlaySize.height - insets.vertical) / 2));
    return MediaQuery(
      data: media,
      child: CustomSingleChildLayout(
        delegate: FrostAnchoredPanelLayout(
          anchor: anchor,
          offset: frostAnchoredPanelGap,
          direction: Directionality.of(context),
          margin: frostAnchoredPanelMargin,
          insets: insets,
        ),
        child: TextFieldTapRegion(
          child: TapRegion(
            groupId: this,
            onTapOutside: (_) => _dismiss(),
            child: _suggestionPresence(
              context,
              ExcludeFocus(
                child: SizedBox(
                  width: anchor.width,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maximumHeight),
                    child: FrostControlScope(
                      toolbar: false,
                      size: FrostControlSize.regular,
                      enabled: true,
                      child: FrostCaptionRegion(
                        kind: FrostHitKind.client,
                        child: FrostPopoverSurface(child: _suggestionList(context)),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // With reduced motion the panel goes straight to its end, as menus do, and
  // so it does when hidden: a fade would not run with the tickers off.
  Widget _suggestionPresence(BuildContext context, Widget panel) => MediaQuery.disableAnimationsOf(context) || !_active
      ? (_visible ? panel : const SizedBox.shrink())
      : FrostPresence(visible: _visible, alignment: AlignmentDirectional.topStart, child: panel);

  /// [_Placement.body]: the list over the page body, from the header row
  /// down to the page bottom or the soft keyboard, the full page width so the
  /// scrollbar keeps the page edge. The rows take the page content column.
  Widget _bodyPanel(BuildContext context, OverlayChildLayoutInfo info) {
    final page = _body?.page, row = FrostHeaderSearchScope.read(this.context)?.row.currentContext?.findRenderObject();
    if (!_visible || page == null || !page.attached || !page.hasSize || row is! RenderBox || !row.hasSize) return const SizedBox.shrink();
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final area = MatrixUtils.transformRect(page.getTransformTo(overlay), Offset.zero & page.size);
    final top = MatrixUtils.transformPoint(row.getTransformTo(overlay), Offset(0, row.size.height)).dy;
    final media = MediaQuery.of(this.context);
    // Above the keyboard when it is open, else above the page's bottom inset
    // (a floating navigation bar, the home indicator).
    final bottom = media.viewInsets.bottom > 0 ? math.min(area.bottom, info.overlaySize.height - media.viewInsets.bottom) : area.bottom - media.padding.bottom;
    final rect = Rect.fromLTRB(area.left, top, area.right, math.max(top, bottom));
    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: MediaQuery(
            data: media.removePadding(removeTop: true, removeBottom: true).removeViewInsets(removeBottom: true),
            child: TextFieldTapRegion(
              child: TapRegion(
                groupId: this,
                onTapOutside: (_) => _dismiss(),
                child: ExcludeFocus(
                  child: FrostControlScope(
                    toolbar: false,
                    size: FrostControlSize.regular,
                    enabled: true,
                    child: FrostCaptionRegion(
                      kind: FrostHitKind.client,
                      // The header's column does not reach the overlay: the rows
                      // take a page column of their own at the same edges.
                      child: FrostKeyline(
                        leadingRoom: 0,
                        trailingRoom: 0,
                        edgeDistanceStart: 0,
                        edgeDistanceEnd: 0,
                        insideContainer: true,
                        contentStart: 0,
                        child: _suggestionList(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    _builtGeneration = _generation;
    _active = TickerMode.valuesOf(context).enabled;
    _placement = _resolvePlacement();
    final body = _placement == _Placement.body ? FrostHeaderSearchBodyScope.maybeOf(context) : null;
    if (!identical(body, _body) && (_body?.showing ?? false)) _body!.showing = false;
    _body = body;
    // The template hides its body in this same frame, at paint time.
    body?.showing = _visible;
    // The field keeps its element, and the editor its state, when the
    // placement changes.
    final field = KeyedSubtree(
      key: _fieldKey,
      child: TextFieldTapRegion(
        child: TapRegion(
          groupId: this,
          child: _SearchField(
            input: _input,
            listenable: Listenable.merge([_input.controller, _highlightRevision]),
            onSubmitted: _submit,
            semanticHint: _announcement,
          ),
        ),
      ),
    );
    final content = _placement != _Placement.inline
        ? field
        : _InlineSuggestions(
            field: field,
            list: !_visible
                ? null
                : ExcludeFocus(
                    child: TextFieldTapRegion(
                      child: TapRegion(
                        groupId: this,
                        onTapOutside: (_) => _dismiss(),
                        child: FrostControlScope(toolbar: false, size: FrostControlSize.regular, enabled: true, child: _suggestionList(context)),
                      ),
                    ),
                  ),
          );
    return Focus(
      onKeyEvent: _key,
      canRequestFocus: false,
      skipTraversal: true,
      // Keep the portal attached across placement changes. Its controller's
      // showing state otherwise resets when a page switches back to anchoring.
      child: OverlayPortal.overlayChildLayoutBuilder(
        controller: _overlay,
        overlayChildBuilder: (context, info) => switch (_placement) {
          _Placement.overlay => _panel(context, info),
          _Placement.body => _bodyPanel(context, info),
          _Placement.inline => const SizedBox.shrink(),
        },
        child: FrostCaptionRegion(kind: FrostHitKind.client, child: content),
      ),
    );
  }
}

enum _Placement { overlay, inline, body }

/// [FrostSuggestionPlacement.inline]: the field, then the visible list below
/// it. A bounded height gives the list the rest of it; an unbounded one lets
/// the list fit its rows, up to the view height above the keyboard. Outside a
/// page column the field takes the content column its rows take, while the
/// list keeps the full width for its scrollbar.
class _InlineSuggestions extends StatelessWidget {
  const _InlineSuggestions({required this.field, required this.list});
  final Widget field;
  final Widget? list;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final field = switch (FrostKeyline.maybeOf(context)) {
        FrostKeyline(insideContainer: false, contentStart: > 0) => this.field,
        _ => FrostContentColumn(maxWidth: FrostPageColumnWidth.of(context), child: this.field),
      };
      if (constraints.hasBoundedHeight) {
        return Column(
          children: [
            field,
            if (list case final list?) Expanded(child: list),
          ],
        );
      }
      final media = MediaQuery.of(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          field,
          if (list case final list?)
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: math.max(0.0, media.size.height - media.padding.vertical - media.viewInsets.bottom)),
              child: list,
            ),
        ],
      );
    },
  );
}

/// A suggestion group's title with its trailing text action. The list item's
/// keyboard highlight and Enter belong to the action, never to the title text.
class _GroupTitle extends StatefulWidget {
  const _GroupTitle({required this.title, required this.actionLabel});
  final String? title;
  final String actionLabel;
  @override
  State<_GroupTitle> createState() => _GroupTitleState();
}

class _GroupTitleState extends State<_GroupTitle> {
  FrostListItemHandle? _handle;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final handle = FrostListItemScope.of(context)?.handle;
    if (_handle != handle) _handle?.activate = null;
    _handle = handle?..activate = _activate;
  }

  void _activate() => FrostListItemScope.of(context)?.onSelected?.call();

  @override
  void dispose() {
    _handle?.activate = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: widget.title == null
            ? const SizedBox.shrink()
            : FrostText(widget.title!, role: FrostTextRole.caption, tone: FrostTextTone.secondary, maxLines: 1),
      ),
      const SizedBox(width: FrostGap.related),
      // The action text ends on the content edge that the title starts on;
      // its highlight padding is spent outside that line.
      Transform.translate(
        offset: Offset(Directionality.of(context) == TextDirection.rtl ? -_actionInset : _actionInset, 0),
        child: FrostClickHighlight(
          highlighted: FrostListItemScope.of(context)?.highlighted ?? false,
          child: FrostClickSurface(
            onTap: _activate,
            shape: FrostClickShape.rounded(FrostRadius.borderRadius(FrostRadius.xs)),
            child: Semantics(
              button: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: _actionInset, vertical: 2),
                child: FrostText(widget.actionLabel, role: FrostTextRole.caption, tone: FrostTextTone.accent, maxLines: 1),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

const _actionInset = 6.0;

/// A non-row line in the suggestion list (a group title, the status line),
/// inset by the same list bleed rows inset their content by, so titles, rows
/// and their trailing values share one pair of edges.
class _RowAligned extends StatelessWidget {
  const _RowAligned({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(padding: FrostListItemScope.of(context)?.viewportInset ?? frostBleedOutsetsOf(context), child: child);
}

/// Centres the search row in its page column with equal vertical breathing room.
class FrostSearchInputRegion extends StatelessWidget {
  const FrostSearchInputRegion({required this.child, super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) => FrostContentColumn(
    maxWidth: FrostPageColumnWidth.of(context),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: FrostGap.related),
      child: child,
    ),
  );
}
