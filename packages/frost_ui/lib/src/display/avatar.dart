import 'package:flutter/widgets.dart';

import '../feedback/_skeleton_geometry.dart';
import '../feedback/skeleton.dart';
import '../foundation/scope.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/layout_crossfade.dart';
import '../primitives/_media_shape.dart';
import '../primitives/icon.dart';
import '../primitives/media_frame.dart';
import '../primitives/text.dart';
import '_avatar_seed.dart';
import '_avatar_size.dart';

export '_avatar_size.dart' show FrostAvatarSize;

// The initials fit the square inscribed in a circle, even at larger text scales.

const _maximumInitials = 2;

const _smallIcon = 16.0, _regularIcon = 18.0, _largeIcon = 22.0, _xlargeIcon = 28.0;

/// A circular media frame with a readable placeholder.
/// [image] uses FrostMediaFrame's loading, fade and error fallback. [child]
/// owns loading and failures; the library only clips, strokes and supplies its
/// background. Both may be absent, but they cannot be provided together.
class FrostAvatar extends StatelessWidget {
  factory FrostAvatar.skeleton({required FrostAvatarSize size}) => _SkeletonAvatar(size);
  const FrostAvatar({this.image, this.child, this.initials, this.size = FrostAvatarSize.regular, required this.semanticLabel, super.key})
    : assert(image == null || child == null),
      _name = null,
      _colorKey = null;

  /// The avatar of a person or account. Frost takes the initial from [name]
  /// (its first letter, upper-cased; the first character of a CJK name) and
  /// colors the placeholder by `colorKey ?? name`: a stable hash picks one of
  /// the palette's categorical colors, with black or white initials that
  /// reach 4.5:1 on it. [semanticLabel] defaults to [name].
  const FrostAvatar.person({required String name, String? colorKey, this.image, this.size = FrostAvatarSize.regular, String? semanticLabel, super.key})
    : _name = name,
      // Keep the public argument named colorKey; the storage is private.
      // ignore: prefer_initializing_formals
      _colorKey = colorKey,
      child = null,
      initials = null,
      semanticLabel = semanticLabel ?? name;
  final ImageProvider? image;
  final Widget? child;
  final String? initials;
  final FrostAvatarSize size;
  final String semanticLabel;
  final String? _name, _colorKey;

  String? get _text => switch (_name) {
    final name? => frostPersonInitial(name),
    null => initials?.characters.take(_maximumInitials).toString(),
  };

  /// Colors the placeholder by name; null keeps the neutral fill.
  String? get _seed => _name == null ? null : _colorKey ?? _name;
  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    final effectiveSize = FrostAvatarSizeScope.of(context) ?? size;
    final dimension = frostAvatarDimension(effectiveSize);
    final (iconSize, role) = switch (effectiveSize) {
      FrostAvatarSize.small => (_smallIcon, FrostTextRole.caption),
      FrostAvatarSize.regular => (_regularIcon, FrostTextRole.footnote),
      FrostAvatarSize.large => (_largeIcon, FrostTextRole.callout),
      FrostAvatarSize.xlarge => (_xlargeIcon, FrostTextRole.headline),
    };
    final text = _text, seed = _seed;
    final seeded = seed == null ? null : frostAvatarSeedFill(seed, tokens.categorical);
    final ink = seeded == null ? null : frostAvatarSeedInk(seeded);
    Widget placeholder() => FrostLayoutCrossfade(
      layoutIdentity: (text, size, seed),
      child: ColoredBox(
        color: seeded ?? tokens.fill,
        child: Center(
          child: text == null || text.isEmpty
              ? FrostIcon(FrostIconSet.of(context).user, size: iconSize, color: ink ?? tokens.textTertiary)
              : SizedBox.square(
                  dimension: dimension * frostAvatarInscribedScale,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ink == null
                        ? FrostText(text, role: role, tone: FrostTextTone.tertiary, tabular: true)
                        : DefaultTextStyle.merge(
                            style: TextStyle(color: ink),
                            child: FrostText(text, role: role, tabular: true),
                          ),
                  ),
                ),
        ),
      ),
    );
    return Semantics(
      label: semanticLabel,
      image: true,
      excludeSemantics: true,
      child: FrostSkeletonShape(
        shape: const CircleBorder(),
        child: SizedBox.square(
          dimension: dimension,
          child: DecoratedBox(
            decoration: BoxDecoration(color: tokens.fill, shape: BoxShape.circle),
            child: FrostMediaCircle(
              child: image == null
                  ? FrostMediaFrame(child: child ?? placeholder())
                  : FrostMediaFrame(image: image, placeholderBuilder: (_, _) => placeholder(), errorBuilder: (_, _) => placeholder()),
            ),
          ),
        ),
      ),
    );
  }
}

class _SkeletonAvatar extends FrostAvatar {
  const _SkeletonAvatar(FrostAvatarSize size) : super(size: size, semanticLabel: '');
  @override
  Widget build(BuildContext context) => FrostAvatar(
    size: size,
    semanticLabel: FrostScope.labelsOf(context).loading,
    child: FrostSkeletonLeaf(
      child: ColoredBox(color: FrostThemeTokens.of(context).fill, child: const SizedBox.expand()),
    ).frostSkeleton(true),
  );
}
