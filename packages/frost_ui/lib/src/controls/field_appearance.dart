import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show Theme;

import '../foundation/control_scope.dart';
import '../foundation/field_appearance.dart';
import '../foundation/tokens.dart';
import '../primitives/_on_media_chrome_scope.dart';

export '../foundation/field_appearance.dart' show FrostFieldAppearance;

/// Applies an appearance to an input or a composed group of inputs.
/// Toolbar inputs default to subtle; other inputs retain standard chrome.
class FrostFieldScope extends StatelessWidget {
  const FrostFieldScope({required this.appearance, required this.child, super.key});
  final FrostFieldAppearance appearance;
  final Widget child;

  static FrostFieldAppearance? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostFieldAppearanceData>()?.appearance;
  static FrostFieldAppearance of(BuildContext context) =>
      maybeOf(context) ?? (FrostControlScope.toolbarOf(context) ? FrostFieldAppearance.subtle : FrostFieldAppearance.standard);

  @override
  Widget build(BuildContext context) {
    Widget content = child;
    if (appearance == FrostFieldAppearance.onMedia) {
      final theme = Theme.of(context), tokens = FrostThemeTokens.of(context);
      final ink = tokens.onMediaInk;
      // Even the brightest frame is at most #525252 below the active .68
      // black scrim. White .78 supporting ink retains ordinary text contrast.
      final media = tokens.copyWith(
        brightness: Brightness.dark,
        textPrimary: ink,
        textSecondary: ink.withValues(alpha: ink.a * .78),
        textTertiary: ink.withValues(alpha: ink.a * .78),
        textQuaternary: ink.withValues(alpha: ink.a * .25),
        disabledText: ink.withValues(alpha: ink.a * .25),
        negativeInk: const Color(0xFFFFB4B7),
      );
      content = FrostOnMediaChromeScope(
        originalTheme: FrostOnMediaChromeScope.originalThemeOf(context) ?? theme,
        child: Theme(
          data: theme.copyWith(
            extensions: [
              for (final extension in theme.extensions.values)
                if (extension is! FrostThemeTokens) extension,
              media,
            ],
          ),
          child: content,
        ),
      );
    } else if (FrostOnMediaChromeScope.inkOf(context) != null) {
      return frostWithoutOnMediaChrome(FrostFieldAppearanceData(appearance: appearance, child: content));
    }
    return FrostFieldAppearanceData(appearance: appearance, child: content);
  }
}
