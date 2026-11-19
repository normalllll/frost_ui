import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show SelectableText;

import '../feedback/_skeleton_geometry.dart';
import '../foundation/_page_title_scope.dart';
import '../foundation/fonts.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '_on_media_chrome_scope.dart';
import '_text_selection_chrome.dart';
import 'surface.dart';

enum FrostTextTone { primary, secondary, tertiary, quaternary, accent, positive, caution, negative, info }

/// Heavier weights a [FrostText] can take at its role's size.
enum FrostTextWeight {
  medium(FontWeight.w500),
  semibold(FontWeight.w600);

  const FrostTextWeight(this.fontWeight);
  final FontWeight fontWeight;
}

/// A run of a [FrostText.rich] in its own [tone], resolved like the text's
/// tone against the current theme and surface. The run stays part of the one
/// text: it shares the role, line limit, ellipsis and semantics label.
class FrostToneSpan extends TextSpan {
  const FrostToneSpan(String text, {required this.tone}) : super(text: text);
  final FrostTextTone tone;

  @override
  bool operator ==(Object other) => super == other && other is FrostToneSpan && other.tone == tone;

  @override
  int get hashCode => Object.hash(super.hashCode, tone);
}

/// Semantic typography whose colour belongs to its caller unless [tone] is set.
class FrostText extends StatelessWidget {
  const FrostText(
    this.data, {
    this.role = FrostTextRole.body,
    this.tone,
    this.weight,
    this.numeric = false,
    this.tabular = false,
    this.content = false,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.selectable = false,
    this.semanticsLabel,
    super.key,
  }) : span = null;

  const FrostText.rich(
    InlineSpan this.span, {
    this.role = FrostTextRole.body,
    this.tone,
    this.weight,
    this.numeric = false,
    this.tabular = false,
    this.content = false,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.selectable = false,
    this.semanticsLabel,
    super.key,
  }) : data = null;

  final String? data;
  final InlineSpan? span;
  final FrostTextRole role;
  final FrostTextTone? tone;

  /// A heavier weight at the role's size, for the main text of a list row
  /// such as a name. Null keeps the role's weight.
  final FrostTextWeight? weight;

  /// Explicitly use the App numeric family for dedicated numeric text.
  final bool numeric;

  /// Tabular figures within the body family, without changing fonts.
  final bool tabular;

  /// Content text (a name or title from the App's data, not an interface
  /// label): its regional CJK glyph forms follow its own script, then
  /// [FrostFonts.defaultScript], instead of the interface language. A
  /// Japanese name in a Chinese interface draws with the Japanese family.
  final bool content;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final bool selectable;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    var style = frostTextStyle(context, role, tone, numeric: numeric, tabular: tabular);
    if (weight case final weight?) style = style.copyWith(fontWeight: weight.fontWeight);
    if (content) style = frostContentTextStyle(context, data ?? this.span!.toPlainText(), style);
    final span = switch (this.span) {
      final span? => _resolveTones(context, span),
      null => null,
    };
    if (selectable) {
      final rich = span;
      return rich == null
          ? FrostSkeletonText(
              child: SelectableText(
                data!,
                selectionControls: frostTextSelectionControls,
                contextMenuBuilder: frostTextSelectionMenu,
                style: style,
                maxLines: maxLines,
                textAlign: textAlign,
                semanticsLabel: semanticsLabel,
              ),
            )
          : FrostSkeletonText(
              child: SelectableText.rich(
                rich is TextSpan ? rich : TextSpan(children: [rich]),
                selectionControls: frostTextSelectionControls,
                contextMenuBuilder: frostTextSelectionMenu,
                style: style,
                maxLines: maxLines,
                textAlign: textAlign,
                semanticsLabel: semanticsLabel,
              ),
            );
    }
    return span == null
        ? FrostSkeletonText(
            child: Text(data!, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign, semanticsLabel: semanticsLabel),
          )
        : FrostSkeletonText(
            child: Text.rich(span, style: style, maxLines: maxLines, overflow: overflow, textAlign: textAlign, semanticsLabel: semanticsLabel),
          );
  }
}

/// [span] with each [FrostToneSpan] given its tone's colour; [span] itself
/// when it holds none.
InlineSpan _resolveTones(BuildContext context, InlineSpan span) {
  if (span is FrostToneSpan) return TextSpan(text: span.text, style: TextStyle(color: _toneColor(context, span.tone)));
  if (span is! TextSpan) return span;
  final children = span.children;
  if (children == null) return span;
  final resolved = [for (final child in children) _resolveTones(context, child)];
  var changed = false;
  for (var index = 0; index < children.length; index++) {
    if (!identical(resolved[index], children[index])) changed = true;
  }
  if (!changed) return span;
  return TextSpan(
    text: span.text,
    style: span.style,
    recognizer: span.recognizer,
    mouseCursor: span.mouseCursor,
    onEnter: span.onEnter,
    onExit: span.onExit,
    semanticsLabel: span.semanticsLabel,
    semanticsIdentifier: span.semanticsIdentifier,
    locale: span.locale,
    spellOut: span.spellOut,
    children: resolved,
  );
}

/// Library-only shared text role and semantic ink resolution.
TextStyle frostTextStyle(BuildContext context, FrostTextRole role, FrostTextTone? tone, {bool numeric = false, bool tabular = false}) {
  if (FrostPageTitleScope.of(context) case final titleRole?) {
    if ({FrostTextRole.body, FrostTextRole.headline, FrostTextRole.title2}.contains(role)) role = titleRole;
  }
  final color = tone == null ? null : _toneColor(context, tone);
  return FrostTypography.of(context).style(role, numeric: numeric, tabular: tabular).copyWith(color: color);
}

Color _toneColor(BuildContext context, FrostTextTone tone) {
  final tokens = FrostThemeTokens.of(context);
  final mediaInk = FrostOnMediaChromeScope.inkOf(context);
  final glass = FrostSurfaceScope.maybeOf(context)?.isGlass ?? false;
  return switch (tone) {
    FrostTextTone.primary => mediaInk ?? tokens.textPrimary,
    FrostTextTone.secondary => mediaInk ?? (glass ? tokens.textSecondaryGlass : tokens.textSecondary),
    FrostTextTone.tertiary => mediaInk ?? (glass ? tokens.textTertiaryGlass : tokens.textTertiary),
    FrostTextTone.quaternary => mediaInk ?? tokens.textQuaternary,
    FrostTextTone.accent => tokens.accentInk,
    FrostTextTone.positive => tokens.positiveInk,
    FrostTextTone.caution => tokens.cautionInk,
    FrostTextTone.negative => tokens.negativeInk,
    FrostTextTone.info => tokens.infoInk,
  };
}
