import 'package:flutter/material.dart' show SelectionArea;
import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../foundation/control_scope.dart';
import '../foundation/icon_data.dart';
import '../foundation/metrics.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_layout_identity.dart';
import '../motion/layout_crossfade.dart';
import '../overlays/tooltip.dart';
import '../primitives/_inline_or_below.dart';
import '../primitives/_measured_layout_builder.dart';
import '../primitives/_path_elision.dart';
import '../primitives/_path_selection.dart';
import '../primitives/_spaced_wrap.dart';
import '../primitives/_text_selection_chrome.dart';
import '_button_control.dart';
import '_button_types.dart';
import '_field_frame.dart';
import '_field_layout.dart';
import 'form.dart';

/// A readonly, selectable path. Selection and copying treat it as one complete
/// value, even when its displayed middle is elided. Choosing/revealing remains
/// app-owned; asynchronous failures are reported without inventing a message.
class FrostPathField extends StatefulWidget {
  const FrostPathField({required this.path, required this.label, this.onChoose, this.onReveal, this.placeholder, this.help, this.error, super.key});
  final String? path;
  final String label;
  final Future<void> Function()? onChoose;
  final VoidCallback? onReveal;
  final String? placeholder, help, error;
  @override
  State<FrostPathField> createState() => _PathFieldState();
}

class _PathFieldState extends State<FrostPathField> {
  final _chooseFocus = FocusNode(), _textFocus = FocusNode();
  final _layout = FrostLayoutIdentity();
  late final _selection = FrostPathSelection(() => widget.path ?? '');
  bool _loading = false;
  @override
  void dispose() {
    _chooseFocus.dispose();
    _textFocus.dispose();
    _layout.dispose();
    _selection.dispose();
    super.dispose();
  }

  Future<void> _choose() async {
    if (_loading || widget.onChoose == null || !FrostControlScope.enabledOf(context)) return;
    setState(() => _loading = true);
    try {
      await widget.onChoose!();
    } catch (error, stack) {
      if (mounted) FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack, library: 'frost_ui'));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = FrostControlScope.enabledOf(context), tokens = FrostThemeTokens.of(context), labels = FrostScope.labelsOf(context);
    final size = FrostControlScope.sizeOf(context), style = FrostTypography.of(context).style(FrostTextRole.body).copyWith(color: tokens.textPrimary);
    final path = widget.path, geometry = frostControlGeometry(context, size);
    double textWidth(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final width = painter.width;
      painter.dispose();
      return width;
    }

    final characters = (path ?? widget.placeholder ?? '').characters.toList();
    final minimumText = characters.length <= 2 ? characters.join() : '${characters.first}$frostPathEllipsis${characters.last}';
    final minimumWidth = textWidth(minimumText) + frostFieldInset(size) * 2;
    final actions = FrostSpacedWrap(
      alignment: WrapAlignment.end,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: FrostGap.related,
      runSpacing: FrostGap.related,
      children: [
        FrostButtonControl(
          label: labels.choose,
          focusNode: _chooseFocus,
          size: FrostControlSize.compact,
          onPressed: enabled && widget.onChoose != null ? _choose : null,
          activity: FrostButtonActivity(loading: _loading),
          wrapsLabel: true,
          truncates: false,
        ),
        if (path != null && widget.onReveal != null)
          FrostButtonControl(
            label: labels.showInFolder,
            icon: FrostIconSet.of(context).folder,
            iconStyle: FrostIconButtonStyle.plain,
            size: FrostControlSize.compact,
            onPressed: enabled ? widget.onReveal : null,
          ),
      ],
    );
    final field = ListenableBuilder(
      listenable: Listenable.merge([_chooseFocus, _textFocus]),
      builder: (context, _) => FrostFieldFrame(
        size: size,
        enabled: enabled,
        focused: _chooseFocus.hasFocus || _textFocus.hasFocus,
        invalid: widget.error != null,
        onPaddingTap: path == null ? _chooseFocus.requestFocus : _textFocus.requestFocus,
        child: FrostMeasuredLayoutBuilder(
          naturalSize: frostTextLineSize(context, path ?? widget.placeholder ?? '', style),
          builder: (context, constraints) {
            final displayed = path == null ? widget.placeholder ?? '' : frostElidePathMiddle(path, constraints.maxWidth, textWidth);
            final text = FrostSkeletonText(
              child: Text(
                displayed,
                style: path == null ? style.copyWith(color: tokens.textSecondary) : style,
                maxLines: 1,
                softWrap: false,
                semanticsLabel: path ?? widget.placeholder,
              ),
            );
            Widget content = path == null
                ? text
                : SelectionArea(
                    selectionControls: frostTextSelectionControls,
                    contextMenuBuilder: (context, state) => frostSelectionMenu(context, state.contextMenuAnchors, state.contextMenuButtonItems),
                    focusNode: _textFocus,
                    child: SelectionContainer(delegate: _selection, child: text),
                  );
            if (path != null) content = FrostTooltip(message: path, child: content);
            return Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: geometry.verticalInset),
                child: content,
              ),
            );
          },
        ),
      ),
    );
    return FrostFormFieldRegistration(
      focusOf: () => _chooseFocus,
      enabled: enabled && widget.onChoose != null && !_loading,
      error: widget.error,
      child: FrostFieldLayout(
        label: widget.label,
        help: widget.help,
        error: widget.error,
        enabled: enabled,
        child: FrostMotionSize(
          duration: FrostMotion.duration(context, FrostMotion.layoutFade),
          alignment: AlignmentDirectional.topStart,
          child: FrostLayoutCrossfade(
            layoutIdentity: _layout,
            child: FrostInlineOrBelow(
              direction: Directionality.of(context),
              gap: FrostGap.related,
              measuresEndAtWidth: false,
              fillsStart: true,
              minimumStart: (natural, width) => minimumWidth,
              onLayout: (below, constraints) => _layout.update(below, viewport: constraints),
              start: field,
              end: actions,
            ),
          ),
        ),
      ),
    );
  }
}
