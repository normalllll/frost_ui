import 'package:flutter/widgets.dart';

/// Draws a glyph widget in the square slot an icon of [size] would
/// occupy. The widget keeps its own proportions and is scaled to fit, so its
/// ink and its text edge are those of an icon, and it adds nothing to the
/// semantics tree: the control already speaks the option's label.
class FrostIconSlot extends StatelessWidget {
  const FrostIconSlot({required this.size, required this.child, super.key});
  final double size;
  final Widget child;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox.square(
      dimension: size,
      child: FittedBox(child: child),
    ),
  );
}
