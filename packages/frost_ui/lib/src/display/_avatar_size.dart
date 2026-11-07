import 'dart:math' as math;
import 'package:flutter/widgets.dart';

// Text fits the square inscribed in the avatar circle, including overflow counts.
const frostAvatarInscribedScale = 1 / math.sqrt2;

/// 24, 32, 40, 56 and 72 logical pixels. [xxlarge] is the identity size of a
/// profile or creator header.
enum FrostAvatarSize { small, regular, large, xlarge, xxlarge }

// One geometry source for standalone avatars and uniform avatar groups.
double frostAvatarDimension(FrostAvatarSize size) => switch (size) {
  FrostAvatarSize.small => 24,
  FrostAvatarSize.regular => 32,
  FrostAvatarSize.large => 40,
  FrostAvatarSize.xlarge => 56,
  FrostAvatarSize.xxlarge => 72,
};

class FrostAvatarSizeScope extends InheritedWidget {
  const FrostAvatarSizeScope({required this.size, required super.child, super.key});
  final FrostAvatarSize size;
  static FrostAvatarSize? of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostAvatarSizeScope>()?.size;
  @override
  bool updateShouldNotify(FrostAvatarSizeScope oldWidget) => size != oldWidget.size;
}
