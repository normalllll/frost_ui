import 'package:flutter/widgets.dart';

import '../display/avatar.dart';
import '../foundation/icon_data.dart';

/// Content for a leading slot. Rows that accept any widget there take a
/// [FrostLeading]; slots sized like an icon take a [FrostGlyph].
sealed class FrostLeading {
  const FrostLeading();

  /// Any widget, laid out by the slot's owner. Only the default list row
  /// accepts it; thumbnails, status dots and buttons go here.
  const factory FrostLeading.custom(Widget child) = FrostCustomLeading;
}

/// A widget in a leading slot; see [FrostLeading.custom].
final class FrostCustomLeading extends FrostLeading {
  const FrostCustomLeading(this.child);
  final Widget child;
}

/// Content of an icon slot: options, menu rows and list rows draw it at the
/// slot's icon size, so text after it starts where it would after an icon.
sealed class FrostGlyph extends FrostLeading {
  const FrostGlyph();

  const factory FrostGlyph.icon(FrostIconData icon) = FrostIconGlyph;

  /// An avatar scaled to the icon slot. It adds nothing to semantics: the
  /// control already speaks its label.
  const factory FrostGlyph.avatar(FrostAvatar avatar) = FrostAvatarGlyph;
}

/// An icon in an icon slot; see [FrostGlyph.icon].
final class FrostIconGlyph extends FrostGlyph {
  const FrostIconGlyph(this.icon);
  final FrostIconData icon;
}

/// An avatar in an icon slot; see [FrostGlyph.avatar].
final class FrostAvatarGlyph extends FrostGlyph {
  const FrostAvatarGlyph(this.avatar);
  final FrostAvatar avatar;
}

/// The two halves internal controls draw: an icon, or a widget for the slot.
extension FrostGlyphParts on FrostGlyph? {
  FrostIconData? get icon => switch (this) {
    FrostIconGlyph(:final icon) => icon,
    _ => null,
  };
  Widget? get widget => switch (this) {
    FrostAvatarGlyph(:final avatar) => avatar,
    _ => null,
  };
}
