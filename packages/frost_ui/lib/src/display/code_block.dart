import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show SelectableText;

import '../controls/_copy_feedback.dart';
import '../feedback/_skeleton_geometry.dart';
import '../foundation/radius.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../primitives/_text_selection_chrome.dart';

/// Diagnostic prose can wrap while source listings retain their original lines.
/// Wrapping uses the engine's line breaking, without inserting copy/semantics data.
enum FrostCodeWrap { none, anywhere }

// Source code has a fixed inset; the copy action owns a separate end column.
const _codeInset = 12.0;

class FrostCodeBlock extends StatelessWidget {
  const FrostCodeBlock({required this.text, this.copyable = true, this.wrap = FrostCodeWrap.none, super.key});
  final String text;
  final bool copyable;

  /// None retains horizontally scrollable source lines. Anywhere wraps within
  /// the text column, including long identifiers, and preserves the raw string.
  final FrostCodeWrap wrap;

  Widget _text(BuildContext context) => FrostSkeletonText(
    child: SelectableText(
      text,
      selectionControls: frostTextSelectionControls,
      contextMenuBuilder: frostTextSelectionMenu,
      style: FrostTypography.of(context).style(FrostTextRole.callout, tabular: true, monospace: true).copyWith(color: FrostThemeTokens.of(context).textPrimary),
    ),
  );
  @override
  Widget build(BuildContext context) => FrostCopyFeedback(
    text: text,
    enabled: copyable,
    builder: (context, copied, copy) => DecoratedBox(
      decoration: ShapeDecoration(color: FrostThemeTokens.of(context).fillSubtle, shape: FrostRadius.shape(context, FrostRadius.md)),
      child: Padding(
        padding: const EdgeInsets.all(_codeInset),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: wrap == FrostCodeWrap.anywhere
                  ? _text(context)
                  : SingleChildScrollView(primary: false, scrollDirection: Axis.horizontal, child: _text(context)),
            ),
            if (copyable) ...[const SizedBox(width: FrostGap.related), FrostCopyFeedbackButton(copied: copied, onCopy: copy)],
          ],
        ),
      ),
    ),
  );
}
