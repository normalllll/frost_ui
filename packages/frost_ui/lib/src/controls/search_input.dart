import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
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
import '../overlays/_anchored_panel_layout.dart';
import '../overlays/_popover_surface.dart';
import '../overlays/adaptive_panel.dart';
import '../primitives/_directional_icon.dart';
import '../primitives/keyline.dart';
import '../primitives/presence.dart';
import '_field_clear_button.dart';
import '_field_options.dart';
import '_field_row.dart';
import '_search_options.dart';
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
/// adds a dropdown of App content, shown in an anchored
/// panel or in the page ([FrostSuggestionPlacement]); it never takes editing
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
  }) : content = null,
       placement = FrostSuggestionPlacement.overlay,
       _suggesting = false;

  /// A search field with a dropdown of App content. It shows while the field
  /// has focus and [content] is not null; Escape, selecting a
  /// [FrostSearchOption] or tapping outside hides it until the query changes
  /// or focus returns.
  const FrostSearchInput.suggesting({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onSubmitted,
    required this.content,
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

  /// The dropdown of [FrostSearchInput.suggesting]: any widget the App builds,
  /// such as [FrostSearchSection]s of [FrostSearchSuggestionRow]s, a grid of
  /// cards made selectable with [FrostSearchOption], and a
  /// [FrostSearchStatus]. Null shows no dropdown; always null for the plain
  /// field.
  ///
  /// Frost scrolls the content vertically inside the dropdown's height, so
  /// lay it out without scrolling of its own: Column, Wrap, or a
  /// LayoutBuilder that picks a column count. The content gets the dropdown's
  /// bounded width, and a grid reflows when that width changes. It never takes
  /// focus; the field's arrow keys and Enter reach its options.
  final Widget? content;

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
        // A control beside a caption field holds the field's focused look.
        final focused = input.focusNode.hasFocus || (FrostCaptionFieldScope.read(context)?.region.hasFocus ?? false);
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
              if (focused || (input.controller.text.isNotEmpty && !FrostCaptionFieldScope.of(context)))
                FrostFieldIconSlot(
                  child: FrostButton.icon(
                    icon: frostForwardIcon(context),
                    label: FrostScope.labelsOf(context).search,
                    size: FrostControlSize.compact,
                    onPressed: input.controller.text.trim().isEmpty ? null : () => input._submit(input.controller.text),
                  ),
                ),
              if (input.hint case final hint? when !focused)
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

/// [FrostSearchInput.suggesting]: the field with its dropdown of App content,
/// keyboard highlight and overlay panel.
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
  final _scroll = ScrollController(keepScrollOffset: false);
  final _highlightRevision = ValueNotifier<int>(0);
  late final _options = FrostSearchOptions(onSelect: _select, onHighlight: () => _highlightRevision.value++);
  FrostHeaderSearchBody? _body;
  // The content last shown, kept while the dropdown fades out.
  Widget? _lastContent;
  String _text = '';
  bool _suppressed = false;
  bool _keptOpen = false;
  // False while the field is in a subtree with its tickers off, such as title
  // content the shell keeps offstage: the field keeps its text and focus, and
  // its dropdown is not shown.
  bool _active = true;

  FrostSearchInput get _input => widget.input;

  /// Where the dropdown goes, read once per build.
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

  /// The dropdown sits in the page rather than in a floating panel.
  bool get _inline => _placement != _Placement.overlay;
  bool get _visible => _active && (_input.focusNode.hasFocus || (_region?.hasFocus ?? false)) && !_suppressed && _input.content != null;

  /// Focus across a caption field and the controls beside it.
  FocusNode? _region;

  @override
  void initState() {
    super.initState();
    _text = _input.controller.text;
    _lastContent = _input.content;
    _input.controller.addListener(_queryChanged);
    _input.focusNode.addListener(_focusChanged);
    // Always attach a portal. Visibility is derived during layout so supplied
    // content gets correct geometry on the very first frame.
    _overlay.show();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final region = FrostCaptionFieldScope.read(context)?.region;
    if (identical(region, _region)) return;
    _region?.removeListener(_regionChanged);
    _region = region?..addListener(_regionChanged);
  }

  void _regionChanged() {
    if (mounted) setState(() {});
  }

  // A tap on the menu of a control beside the field is not a tap away from it.
  // A tap elsewhere with focus on such a control leaves the search altogether.
  void _tappedOutside() {
    if (FrostCaptionFieldScope.read(context)?.menu.open ?? false) return;
    final onControl = !_input.focusNode.hasFocus && (_region?.hasFocus ?? false);
    _dismiss();
    if (onControl) _input.onDismiss?.call();
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
  }

  /// A new query, focus entry or keep-open selection: the dropdown shows
  /// again with nothing highlighted.
  void _restart({bool keptOpen = false, bool scrollToTop = true}) {
    setState(() {
      _suppressed = false;
      _keptOpen = keptOpen;
      _options.reset();
    });
    if (!scrollToTop) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) _scroll.jumpTo(0);
    });
  }

  void _queryChanged() {
    if (_text == _input.controller.text) return;
    _text = _input.controller.text;
    _restart();
  }

  void _focusChanged() {
    _restart();
    _reportFocus(context, _input.focusNode);
  }

  void _dismiss() {
    if (!mounted) return;
    setState(() {
      _suppressed = true;
      _options.clear();
    });
  }

  void _select(VoidCallback onSelected, FrostSearchOptionExit exit) {
    if (exit == FrostSearchOptionExit.stay) {
      // A section action (clear, manage) changes the content in place.
      onSelected();
      return;
    }
    try {
      onSelected();
    } finally {
      if (mounted) {
        if (exit == FrostSearchOptionExit.reopen) {
          _reopen();
        } else {
          // Updating the query as part of choosing an option is still this
          // selection. Reopen only for a later query edit or a new focus entry.
          _dismiss();
        }
      }
    }
  }

  /// A keep-open selection: the dropdown stays up with nothing highlighted, so
  /// Enter submits. A mouse left over the chosen option highlights again once
  /// it moves; an arrow key starts a new highlight.
  void _reopen() {
    _input.focusNode.requestFocus();
    _restart(keptOpen: true, scrollToTop: false);
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
    if (event.logicalKey == LogicalKeyboardKey.arrowDown && !_visible && _input.content != null) {
      _restart();
      return KeyEventResult.handled;
    }
    if (_visible && _arrows.contains(event.logicalKey) && !_modifiedSideways(event) && _options.move(event.logicalKey) == KeyEventResult.handled) {
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      _submit(_input.controller.text);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static final _arrows = {LogicalKeyboardKey.arrowDown, LogicalKeyboardKey.arrowUp, LogicalKeyboardKey.arrowLeft, LogicalKeyboardKey.arrowRight};

  // Left and Right with a modifier select text or move by word: the editor's.
  static bool _modifiedSideways(KeyEvent event) {
    if (event.logicalKey != LogicalKeyboardKey.arrowLeft && event.logicalKey != LogicalKeyboardKey.arrowRight) return false;
    final keyboard = HardwareKeyboard.instance;
    return keyboard.isShiftPressed || keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isMetaPressed;
  }

  void _submit(String value) {
    if (_visible && _options.activate()) return;
    if (_keptOpen) _dismiss();
    _input._submit(value);
  }

  @override
  void dispose() {
    if (_body?.showing ?? false) _body!.showing = false;
    _region?.removeListener(_regionChanged);
    _input.controller.removeListener(_queryChanged);
    _input.focusNode.removeListener(_focusChanged);
    _highlightRevision.dispose();
    _options.dispose();
    _scroll.dispose();
    super.dispose();
  }

  String? _announcement() => _options.announcement();

  /// The App's content in the dropdown's scroll view. The scroll view keeps
  /// the full width for its scrollbar; a page dropdown's content takes the
  /// page's content column inside it.
  Widget _suggestionList(BuildContext context) => KeyedSubtree(
    key: _listKey,
    child: FrostBleed(
      amount: FrostGap.of(context).hitInset,
      child: FrostSearchOptionsBuilder(
        options: _options,
        inline: _inline,
        child: SingleChildScrollView(
          controller: _scroll,
          child: FrostSearchContentRoot(child: _suggestionColumn(_input.content ?? _lastContent ?? const SizedBox.shrink())),
        ),
      ),
    ),
  );

  // A page dropdown takes the page's content column, unless the App already
  // placed it inside one (a browse layout's slivers, say): a second column
  // would inset the titles and rows again and leave them short of the field
  // and Cancel.
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
            onTapOutside: (_) => _tappedOutside(),
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
    _active = TickerMode.valuesOf(context).enabled;
    _placement = _resolvePlacement();
    _options
      ..hoverNeedsMove = _keptOpen
      ..textDirection = Directionality.of(context)
      ..itemPosition = FrostScope.labelsOf(context).itemPosition
      // New content may put another option where the highlight was.
      ..refreshAnnouncement();
    if (_input.content != null) _lastContent = _input.content;
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
