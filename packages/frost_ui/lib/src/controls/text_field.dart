import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../foundation/control_scope.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../layout/_caption_search_scope.dart';
import '../primitives/_text_selection_chrome.dart';
import '../primitives/icon.dart';
import '_field_clear_button.dart';
import '_field_frame.dart';
import '_field_layout.dart';
import '_field_options.dart';
import '_field_row.dart';
import '_form_submit.dart';
import 'buttons.dart';
import 'field_appearance.dart';
import 'form.dart';

// Field icon gaps are control geometry, independent of page spacing.
const _compactIconGap = 6.0, _regularIconGap = 8.0;

/// The shared input base. Labels and supporting text belong to Frost chrome.
class FrostTextField extends StatefulWidget {
  const FrostTextField({
    this.controller,
    this.focusNode,
    this.label,
    this.placeholder,
    this.help,
    this.error,
    this.leading,
    this.trailing,
    this.clearable = false,
    this.size,
    this.appearance,
    this.monospace = false,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.keyboardType,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.scrollController,
    super.key,
  }) : _secure = false,
       assert(minLines > 0 && maxLines >= minLines);

  /// A single-line password field with a visibility toggle. The keyboard type
  /// is always visiblePassword; autocorrection and suggestions are disabled.
  /// Obscuring, clearing, monospace and line-count options are not accepted.
  const FrostTextField.secure({
    this.controller,
    this.focusNode,
    this.label,
    this.placeholder,
    this.help,
    this.error,
    this.leading,
    this.trailing,
    this.size,
    this.appearance,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.scrollController,
    super.key,
  }) : _secure = true,
       obscureText = true,
       clearable = false,
       monospace = false,
       minLines = 1,
       maxLines = 1,
       keyboardType = TextInputType.visiblePassword;
  final bool _secure;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? label, placeholder, help, error;
  final FrostIconData? leading;

  /// Structural accessory slot; use compact [FrostButton.icon] controls here.
  final Widget? trailing;
  final bool clearable, monospace, obscureText, readOnly, enabled, autofocus;
  final FrostControlSize? size;
  final FrostFieldAppearance? appearance;
  final int minLines, maxLines;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged, onSubmitted;
  final VoidCallback? onEditingComplete, onTap;
  final TapRegionCallback? onTapOutside;
  final ScrollController? scrollController;
  @override
  State<FrostTextField> createState() => _FrostTextFieldState();
}

class _FrostTextFieldState extends State<FrostTextField> {
  late TextEditingController _controller = widget.controller ?? TextEditingController();
  late FocusNode _focus = widget.focusNode ?? FocusNode();
  // Input offsets belong to this live field, not its ancestor page's storage.
  late final _localScroll = ScrollController(keepScrollOffset: false);
  bool _passwordVisible = false;
  FrostFormCoordinator? _form;
  late final _formField = FrostFormFieldHandle(
    context: context,
    focusOf: () => _focus,
    errorOf: () => widget.error != null,
    enabledOf: () => widget.enabled && FrostControlScope.enabledOf(context),
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final form = FrostFormScope.maybeOf(context);
    if (_form != form) {
      _form?.unregister(_formField);
      _form = form;
      _form?.register(_formField);
    }
    _formField.order = FrostFormOrder.of(context);
    _formField.beforeSubmit = FrostFieldOptions.of(context)?.beforeSubmit;
  }

  @override
  void didUpdateWidget(FrostTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget._secure != widget._secure) _passwordVisible = false;
    if (oldWidget.controller != widget.controller) {
      final previous = _controller;
      _controller = widget.controller ?? TextEditingController.fromValue(previous.value);
      if (oldWidget.controller == null) previous.dispose();
    }
    if (oldWidget.focusNode != widget.focusNode) {
      if (oldWidget.focusNode == null) _focus.dispose();
      _focus = widget.focusNode ?? FocusNode();
    }
  }

  @override
  void dispose() {
    _form?.unregister(_formField);
    _localScroll.dispose();
    if (widget.controller == null) _controller.dispose();
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _clear() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  @override
  Widget build(BuildContext context) => widget.appearance == null
      ? _build(context)
      : FrostFieldScope(
          appearance: widget.appearance!,
          child: Builder(builder: _build),
        );

  Widget _build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([_controller, _focus]),
    builder: (context, _) {
      final tokens = FrostThemeTokens.of(context);
      final options = FrostFieldOptions.of(context);
      final enabled = widget.enabled && FrostControlScope.enabledOf(context);
      final invalid = widget.error != null || (options?.invalid ?? false);
      final size = widget.size ?? FrostControlScope.sizeOf(context);
      final geometry = frostControlGeometry(context, size);
      final style = FrostTypography.of(context)
          .style(FrostTextRole.body, monospace: widget.monospace, tabular: options?.numeric ?? false)
          .copyWith(color: tokens.textPrimary, fontSize: FrostCaptionFieldScope.of(context) ? 12.5 : null);
      final multiLine = widget.maxLines > 1;
      // Large text needs a minimum 44px editing area. Borrow that space from
      // existing vertical padding; the shared frame and base height stay put.
      final largeText = MediaQuery.textScalerOf(context).scale(style.fontSize!) > style.fontSize!;
      final editorMinimum = largeText && !multiLine ? math.min(FrostControlSize.minimumHitHeight(touch: true), geometry.height) : 0.0;
      final editorPadding = math.max(0.0, (editorMinimum - (geometry.height - geometry.verticalInset * 2)) / 2);
      final editorInset = math.max(0.0, geometry.verticalInset - editorPadding);
      final gap = size == FrostControlSize.small || size == FrostControlSize.compact ? _compactIconGap : _regularIconGap;
      Widget editor(BuildContext context) {
        final automatic = _form != null && widget.textInputAction == null && !multiLine;
        // Outside a form, a dialog's default action is what finishing means,
        // unless the caller took over finishing this field.
        final dialogSubmit = _form == null && widget.textInputAction == null && !multiLine && widget.onSubmitted == null && widget.onEditingComplete == null
            ? FrostDialogSubmitScope.maybeOf(context)
            : null;
        final textEditor = FrostTextSelectionInput(
          builder: (context, selectionControls) => TextField(
            selectionControls: selectionControls,
            contextMenuBuilder: frostTextSelectionMenu,
            controller: _controller,
            focusNode: _focus,
            readOnly: widget.readOnly,
            enabled: enabled,
            autofocus: widget.autofocus,
            obscureText: widget._secure ? !_passwordVisible : widget.obscureText,
            autocorrect: !widget._secure,
            enableSuggestions: !widget._secure,
            minLines: widget.minLines,
            maxLines: widget.maxLines,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction ?? (multiLine ? TextInputAction.newline : _form?.actionFor(_formField)),
            onChanged: widget.onChanged,
            onSubmitted: widget.onSubmitted,
            onEditingComplete: automatic
                ? () {
                    widget.onEditingComplete?.call();
                    _form?.completeEditing(_formField);
                  }
                : dialogSubmit != null
                ? () => dialogSubmit()
                : widget.onEditingComplete,
            onTap: widget.onTap,
            onTapOutside: widget.onTapOutside,
            scrollController: widget.scrollController ?? _localScroll,
            textAlignVertical: multiLine ? TextAlignVertical.top : TextAlignVertical.center,
            style: style,
            cursorColor: tokens.accent,
            decoration: InputDecoration(
              isCollapsed: true,
              isDense: true,
              filled: false,
              constraints: editorMinimum == 0 ? null : BoxConstraints(minHeight: editorMinimum),
              contentPadding: EdgeInsets.symmetric(vertical: editorPadding),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              hintText: widget.placeholder,
              hintStyle: style.copyWith(color: tokens.textSecondary),
            ),
          ),
        );
        final hint = options?.semanticHint;
        // Announcements change as suggestions are highlighted. Keep the editor
        // at the same element-tree position so IME and undo state survive.
        return Semantics(label: widget.label, hint: hint, liveRegion: hint != null, child: textEditor);
      }

      // All sibling fields register before layout. Defer only the editor's
      // action choice so next/done is correct on the cold frame, without a
      // post-layout setState or an extra input/controller implementation.
      final field = _form == null ? editor(context) : LayoutBuilder(builder: (context, _) => editor(context));
      // The editor keeps two characters of room; trailing controls that do
      // not fit beside it are dropped from the end rather than overflowing.
      final trailingBleed = frostFieldTrailingBleed(context, size);
      final contents = FrostFieldRow(
        top: multiLine,
        editorMinimum: MediaQuery.textScalerOf(context).scale(style.fontSize!) * 2,
        trailingBleed: trailingBleed,
        leading: switch (widget.leading) {
          final leading? => Padding(
            padding: EdgeInsetsDirectional.only(top: multiLine ? geometry.verticalInset : 0, end: gap),
            child: FrostIcon(leading, size: size.iconSize, color: tokens.textSecondary),
          ),
          null => null,
        },
        editor: Padding(
          padding: EdgeInsets.symmetric(vertical: editorInset),
          child: Material(type: MaterialType.transparency, child: field),
        ),
        trailing: FrostFieldTrailing(
          children: [
            FrostFieldIconSlot(
              child: FrostFieldClearButton(visible: widget.clearable && _controller.text.isNotEmpty && enabled && !widget.readOnly, onClear: _clear),
            ),
            ?widget.trailing,
            if (widget._secure)
              FrostFieldIconSlot(
                child: TextFieldTapRegion(
                  child: FrostButton.icon(
                    icon: _passwordVisible ? FrostIconSet.of(context).eyeOff : FrostIconSet.of(context).eye,
                    label: _passwordVisible ? FrostScope.labelsOf(context).hidePassword : FrostScope.labelsOf(context).showPassword,
                    size: FrostControlSize.compact,
                    onPressed: enabled
                        ? () {
                            setState(() => _passwordVisible = !_passwordVisible);
                            _focus.requestFocus();
                          }
                        : null,
                  ),
                ),
              ),
          ],
        ),
      );
      return FrostFieldLayout(
        label: widget.label,
        labelSemantics: false,
        help: widget.help,
        error: widget.error,
        supportingTrailing: options?.supportingTrailing,
        enabled: enabled,
        child: FrostFieldFrame(
          size: size,
          enabled: enabled,
          focused: _focus.hasFocus,
          invalid: invalid,
          multiline: multiLine,
          trailingBleed: trailingBleed,
          onPaddingTap: _focus.requestFocus,
          child: contents,
        ),
      );
    },
  );
}
