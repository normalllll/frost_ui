import 'package:flutter/widgets.dart';

import '../foundation/radius.dart';
import 'media_stage.dart';

/// Library-only: the corners of the media area a [FrostMediaHero] sits in. A
/// card's frame and a mosaic cell publish theirs; below a detail stage the
/// stage's corners apply, and elsewhere the media radius.
class FrostMediaHeroRadius extends InheritedWidget {
  const FrostMediaHeroRadius({required this.radius, required super.child, super.key});
  final BorderRadius radius;

  /// The corners at [context]. [listen] false reads them without a rebuild
  /// dependency, for a flight snapshot taken outside build.
  static BorderRadius of(BuildContext context, {bool listen = true}) {
    final area = listen ? context.dependOnInheritedWidgetOfExactType<FrostMediaHeroRadius>() : context.getInheritedWidgetOfExactType<FrostMediaHeroRadius>();
    if (area != null) return area.radius;
    final stage = listen
        ? context.dependOnInheritedWidgetOfExactType<FrostMediaStagePresentation>()
        : context.getInheritedWidgetOfExactType<FrostMediaStagePresentation>();
    return FrostRadius.borderRadius(stage?.radius ?? FrostRadius.lg);
  }

  @override
  bool updateShouldNotify(FrostMediaHeroRadius oldWidget) => radius != oldWidget.radius;
}
