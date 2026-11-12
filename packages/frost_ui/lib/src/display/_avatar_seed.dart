import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../foundation/color_math.dart';

final _letter = RegExp(r'\p{L}', unicode: true);

/// The initial of a person's [name]: its first letter, upper-cased, so a
/// leading digit or symbol is skipped; a CJK name gives its first character.
/// Null when the name has no letter, which shows the person icon.
String? frostPersonInitial(String name) {
  for (final character in name.characters) {
    if (_letter.hasMatch(character)) return character.toUpperCase();
  }
  return null;
}

/// A stable index for [seed]: FNV-1a over its UTF-8 bytes. `String.hashCode`
/// differs between runs and platforms; this does not, so a name keeps its
/// colour on every launch and every machine.
int frostSeedIndex(String seed, int length) {
  var hash = 0x811c9dc5;
  for (final byte in utf8.encode(seed)) {
    hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF;
  }
  return hash % length;
}

/// The placeholder fill a seed maps to in [palette].
Color frostAvatarSeedFill(String seed, List<Color> palette) => palette[frostSeedIndex(seed, palette.length)];

/// White or the solid wash (black), whichever reads better on [fill]. The better of the two is
/// at least 4.58:1 on any colour, so the initials always meet 4.5:1.
Color frostAvatarSeedInk(Color fill) =>
    swatchCheckInk(fill, solidWashColor(fill));
