import 'dart:math' as math;

import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:frost_window/frost_window.dart' show FrostCaptionMode;

import '../foundation/_control_geometry.dart';
import '../foundation/icon_data.dart';
import '../foundation/sizes.dart';
import '../layout/_caption_search_scope.dart';
import '../layout/window_caption_scope.dart';
import '../primitives/_measured_layout_builder.dart';
import 'buttons.dart';
import 'field_appearance.dart';
import 'search_input.dart';

/// Where a title-row search sits. [end] is beside the window buttons, narrower
/// at rest; the search still expands toward the leading edge.
enum FrostCaptionSearchPlacement { center, end }

/// Editable caption search. The shell reserves 360 logical pixels at rest, or
/// 240 with [FrostCaptionSearchPlacement.end], and expands toward the leading edge to 520, over the tabs when needed. On a
/// narrow caption it rests as an icon and expands across available caption room.
/// The App owns the query, history, results and tab navigation.
class FrostCaptionSearch extends StatefulWidget {
  const FrostCaptionSearch({
    required this.controller,
    required this.focusNode,
    required this.placeholder,
    required this.onSubmitted,
    this.onSubmittedInNewTab,
    this.content,
    this.hint,
    this.actions = const [],
    super.key,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final String placeholder;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String>? onSubmittedInNewTab;

  /// As [FrostSearchInput.content]: the dropdown under the expanded field,
  /// null for none. A resting icon shows no dropdown.
  final Widget? content;

  /// As [FrostSearchInput.hint]; none by default.
  final String? hint;

  /// Compact controls at the end of the expanded field, before submit, such as
  /// a menu button choosing what to search. They take no room at rest. While
  /// one of them or its menu has focus the search stays expanded and its
  /// dropdown stays up; closing a menu returns focus to the field.
  final List<Widget> actions;
  @override
  State<FrostCaptionSearch> createState() => _FrostCaptionSearchState();
}

class _FrostCaptionSearchState extends State<FrostCaptionSearch> {
  FrostCaptionSearchScope? _layout;
  final _region = FocusNode(debugLabel: 'Caption search', canRequestFocus: false, skipTraversal: true);
  final _menu = FrostCaptionFieldMenu();
  @override
  void initState() {
    super.initState();
    _region.addListener(_focusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _layout = FrostCaptionSearchScope.maybeOf(context);
  }

  void _focusChanged() {
    if (_layout case final layout?) {
      layout.onExpanded(_region.hasFocus);
    } else if (mounted) {
      // Outside the caption, focus alone decides when the actions show.
      setState(() {});
    }
  }

  void _open() {
    _layout?.onExpanded(true);
    // The icon and editor share one stable component. Wait until the expanded
    // editor is attached before requesting its focus; no native focus is stolen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.focusNode.requestFocus();
    });
  }

  void _collapse() {
    // Restore the previous page/traversal scope so caption shortcuts remain
    // reachable after Escape, instead of clearing the route's entire history.
    widget.focusNode.unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
    _layout?.onExpanded(false);
  }

  void _submit(String query) {
    final keyboard = HardwareKeyboard.instance;
    final newTab = keyboard.isControlPressed || keyboard.isMetaPressed;
    (newTab ? widget.onSubmittedInNewTab ?? widget.onSubmitted : widget.onSubmitted)(query);
  }

  @override
  void dispose() {
    _region.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostMeasuredLayoutBuilder(
    naturalSize: Size(frostCaptionSearchWidth, frostControlGeometry(context, FrostControlSize.small).height),
    builder: (context, constraints) {
      final iconOnly = !(_layout?.expanded ?? false) && constraints.maxWidth < 120;
      final field = FrostSearchInput.suggesting(
        // The title bar always anchors its panel under the field.
        placement: FrostSuggestionPlacement.overlay,
        controller: widget.controller,
        focusNode: widget.focusNode,
        placeholder: widget.placeholder,
        onSubmitted: _submit,
        onDismiss: _collapse,
        appearance: FrostFieldAppearance.subtle,
        size: FrostControlSize.small,
        leadingIcon: true,
        hint: widget.hint,
        actions: (_layout?.expanded ?? _region.hasFocus) ? widget.actions : const [],
        // A resting icon has no dropdown; it returns with the field.
        content: constraints.maxWidth >= 120 ? widget.content : null,
      );
      // The caption slot is bounded and the field fills it. Outside the caption
      // (the shell moves title content into the page header at large text
      // sizes) a column leaves the height unbounded: the field then keeps its
      // own single control row, and an unbounded width takes the resting width.
      final bounded = constraints.hasBoundedHeight;
      final width = constraints.hasBoundedWidth ? math.max(160.0, constraints.maxWidth) : frostCaptionSearchWidth;
      // The field keeps its own target height and is centred in the row, so
      // its frame shares the centre line of Back, the brand and the caption
      // buttons. AppKit places the traffic lights itself; the caption row sits
      // at the top of the view, so their reported centre is a row offset too.
      // The frame keeps at least two pixels of the row above and below it.
      var shift = 0.0;
      final caption = FrostWindowCaptionScope.stateOf(context);
      if (_layout != null && bounded && caption != null && caption.mode == FrostCaptionMode.nativeControls && !caption.fullscreen) {
        final lights = caption.nativeControls;
        if (!lights.isEmpty) {
          final half = frostControlGeometry(context, FrostControlSize.small).height / 2 + 2;
          final row = constraints.maxHeight;
          shift = lights.center.dy.clamp(half, math.max(half, row - half)) - row / 2;
        }
      }
      return Stack(
        fit: bounded ? StackFit.expand : StackFit.loose,
        children: [
          FocusTraversalGroup(
            descendantsAreTraversable: !iconOnly,
            child: Offstage(
              offstage: iconOnly,
              child: ClipRect(
                child: OverflowBox(
                  fit: bounded ? OverflowBoxFit.max : OverflowBoxFit.deferToChild,
                  alignment: AlignmentDirectional.centerEnd,
                  minWidth: width,
                  maxWidth: width,
                  minHeight: 0,
                  child: Transform.translate(
                    offset: Offset(0, shift),
                    child: Focus(
                      focusNode: _region,
                      child: FrostCaptionFieldScope(region: _region, editor: widget.focusNode, menu: _menu, child: field),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (iconOnly) FrostButton.icon(icon: FrostIconSet.of(context).search, label: widget.placeholder, size: FrostControlSize.compact, onPressed: _open),
        ],
      );
    },
  );
}
