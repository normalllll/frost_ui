import 'package:flutter/widgets.dart';

// The ellipsis replaces only presentation; selection always copies the path.
const frostPathEllipsis = '…';

/// [path] with its middle replaced by [frostPathEllipsis], keeping as many of
/// its first and last characters as [measure] fits in [maxWidth]. A path that
/// already fits, or has two characters or fewer, is returned unchanged.
String frostElidePathMiddle(String path, double maxWidth, double Function(String text) measure) {
  final characters = path.characters.toList();
  if (characters.length <= 2 || measure(path) <= maxWidth) return path;
  String presentation(int keep) {
    final leading = (keep / 2).ceil(), trailing = keep ~/ 2;
    return '${characters.take(leading).join()}$frostPathEllipsis${characters.skip(characters.length - trailing).join()}';
  }

  var lower = 2, upper = characters.length - 1;
  var displayed = presentation(lower);
  while (lower <= upper) {
    final middle = (lower + upper) ~/ 2, candidate = presentation(middle);
    if (measure(candidate) <= maxWidth) {
      displayed = candidate;
      lower = middle + 1;
    } else {
      upper = middle - 1;
    }
  }
  return displayed;
}
