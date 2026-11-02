import 'package:flutter/widgets.dart';

import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '_copyable_text.dart';

/// Selectable, wrapping display text whose button and context menu always copy
/// [text], even when [display] is a shortened or differently formatted value.
/// The copy button follows the text while it fits on one line, moves to the
/// end of the row when the text wraps, and is centred on the first line.
class FrostCopyable extends StatelessWidget {
  const FrostCopyable({required this.text, this.display, this.monospace = false, super.key});
  final String text;
  final String? display;
  final bool monospace;
  @override
  Widget build(BuildContext context) => FrostCopyableText(
    text: text,
    display: display,
    style: FrostTypography.of(context).style(FrostTextRole.body, monospace: monospace).copyWith(color: FrostThemeTokens.of(context).textPrimary),
  );
}
