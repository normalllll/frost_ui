import 'package:flutter/widgets.dart';

import '../foundation/_colors.dart';

/// The opaque pure black stage behind fullscreen media viewing, identical in
/// every theme and contrast mode. Fills the space it is given; with a [child]
/// it sizes like a colored box around it.
class FrostMediaBlackStage extends StatelessWidget {
  const FrostMediaBlackStage({this.child, super.key});
  final Widget? child;

  @override
  Widget build(BuildContext context) => ColoredBox(color: frostMediaStageBlack, child: child ?? const SizedBox.expand());
}
