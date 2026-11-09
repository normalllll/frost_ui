import 'package:flutter/material.dart' show Theme, ThemeData;
import 'package:flutter/widgets.dart';

import '../foundation/field_appearance.dart';
import '../foundation/tokens.dart';

/// Internal player-strip presentation. A media viewer may still intentionally
/// use circular scrim controls; the player's continuous gradient owns contrast.
class FrostMediaControlsScope extends InheritedWidget {
  const FrostMediaControlsScope({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostMediaControlsScope>() != null;
  @override
  bool updateShouldNotify(FrostMediaControlsScope oldWidget) => false;
}

/// Media foregrounds use the current onMedia ink and circular icon-button scrim.
/// This changes neither the page theme nor separately opened menus and dialogs.
/// It adds no surface; use FrostSurface with the onMediaChrome role for a panel.
class FrostOnMediaChromeScope extends InheritedWidget {
  const FrostOnMediaChromeScope({this.originalTheme, required super.child, super.key}) : _enabled = true;
  const FrostOnMediaChromeScope._without({required super.child}) : _enabled = false, originalTheme = null;
  final bool _enabled;
  final ThemeData? originalTheme;
  static ThemeData? originalThemeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostOnMediaChromeScope>()?.originalTheme;

  static Color? inkOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<FrostOnMediaChromeScope>()?._enabled == true ? FrostThemeTokens.of(context).onMediaInk : null;

  @override
  bool updateShouldNotify(FrostOnMediaChromeScope oldWidget) => _enabled != oldWidget._enabled || originalTheme != oldWidget.originalTheme;
}

/// Internal: a page's pinned chrome declared to lie over media.
///
/// While [active], icon-only buttons below paint the on-media circle; text is
/// left alone, since nothing sits behind it to guarantee its contrast. Toolbars
/// keep the media layout whenever [declared], so turning [active] on and off
/// repaints the buttons without moving them.
class FrostChromeOverMedia extends InheritedWidget {
  const FrostChromeOverMedia({required this.declared, required this.active, required super.child, super.key});

  /// Subtree of the chrome that keeps its ordinary paint and layout.
  const FrostChromeOverMedia.none({required super.child, super.key}) : declared = false, active = false;
  final bool declared, active;

  static bool declaredOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostChromeOverMedia>()?.declared ?? false;
  static bool activeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostChromeOverMedia>()?.active ?? false;

  @override
  bool updateShouldNotify(FrostChromeOverMedia oldWidget) => declared != oldWidget.declared || active != oldWidget.active;
}

// A separately surfaced menu/popover keeps the page palette even when an
// OverlayPortal inherits the media trigger's complete ancestry.
Widget frostWithoutOnMediaChrome(Widget child) => Builder(
  builder: (context) {
    final original = context.dependOnInheritedWidgetOfExactType<FrostOnMediaChromeScope>()?.originalTheme;
    final appearance = context.dependOnInheritedWidgetOfExactType<FrostFieldAppearanceData>()?.appearance;
    final restored = original == null ? child : Theme(data: original, child: child);
    return FrostChromeOverMedia.none(
      child: FrostOnMediaChromeScope._without(
        // Only media restoration needs an appearance barrier. Ordinary surfaces
        // must preserve explicit scopes and allow search's own subtle default.
        child: original != null || appearance == FrostFieldAppearance.onMedia ? FrostFieldAppearanceData(appearance: null, child: restored) : restored,
      ),
    );
  },
);

/// Command ink sits near the frame edge while complete native targets remain
/// inside the player. The top Back/toolbar strip does not inherit this scope.
class FrostVideoCommandScope extends InheritedWidget {
  const FrostVideoCommandScope({required super.child, super.key});
  static bool of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostVideoCommandScope>() != null;
  @override
  bool updateShouldNotify(FrostVideoCommandScope oldWidget) => false;
}
