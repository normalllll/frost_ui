import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:frost_ui/src/foundation/scope.dart';

/// An icon supplied by the app. The library ships no icon files: an app
/// names its own SVG assets (single-colour, tinted at runtime) or glyphs.
@immutable
sealed class FrostIconData {
  const FrostIconData();

  /// A single-colour SVG asset, tinted with the icon colour.
  /// [mirrorInRtl] flips directional icons such as a back arrow.
  const factory FrostIconData.svg(String asset, {String? package, bool mirrorInRtl}) = FrostSvgIcon;

  /// A font glyph.
  const factory FrostIconData.glyph(IconData data) = FrostGlyphIcon;
}

final class FrostSvgIcon extends FrostIconData {
  const FrostSvgIcon(this.asset, {this.package, this.mirrorInRtl = false});

  final String asset;
  final String? package;
  final bool mirrorInRtl;

  @override
  bool operator ==(Object other) => other is FrostSvgIcon && other.asset == asset && other.package == package && other.mirrorInRtl == mirrorInRtl;

  @override
  int get hashCode => Object.hash(asset, package, mirrorInRtl);
}

final class FrostGlyphIcon extends FrostIconData {
  const FrostGlyphIcon(this.data);

  final IconData data;

  @override
  bool operator ==(Object other) => other is FrostGlyphIcon && other.data == data;

  @override
  int get hashCode => data.hashCode;
}

/// The icons Frost components draw themselves. Every slot is required; an
/// app maps each to its own icon set.
@immutable
class FrostIconSet {
  const FrostIconSet({
    required this.back,
    required this.close,
    required this.more,
    required this.expand,
    required this.collapse,
    required this.chevronLeft,
    required this.chevronRight,
    required this.chevronDown,
    required this.refresh,
    required this.copy,
    required this.search,
    required this.check,
    required this.success,
    required this.info,
    required this.warning,
    required this.error,
    required this.empty,
    required this.sidebarExpand,
    required this.sidebarCollapse,
  });

  final FrostIconData back;
  final FrostIconData close;
  final FrostIconData more;

  /// Disclosure of collapsed content (details, sections).
  final FrostIconData expand;
  final FrostIconData collapse;
  final FrostIconData chevronLeft;
  final FrostIconData chevronRight;

  /// The arrow of a select or menu button.
  final FrostIconData chevronDown;
  final FrostIconData refresh;
  final FrostIconData copy;
  final FrostIconData search;

  /// The mark of a selected item.
  final FrostIconData check;
  final FrostIconData success;
  final FrostIconData info;
  final FrostIconData warning;
  final FrostIconData error;

  /// An empty list or result.
  final FrostIconData empty;
  final FrostIconData sidebarExpand;
  final FrostIconData sidebarCollapse;

  /// The icon set of the nearest [FrostScope].
  static FrostIconSet of(BuildContext context) => FrostScope.configOf(context).icons;
}

/// Draws a [FrostIconData] at the [IconTheme] size and colour unless given.
/// Pair decorative icons with a labelled control; give [semanticLabel] only
/// when the icon itself conveys information outside a labelled control.
class FrostIcon extends StatelessWidget {
  const FrostIcon(this.icon, {this.size, this.color, this.semanticLabel, super.key});

  final FrostIconData icon;
  final double? size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final resolvedSize = size ?? iconTheme.size ?? 20;
    final resolvedColor = color ?? iconTheme.color ?? Theme.of(context).colorScheme.onSurface;
    return switch (icon) {
      FrostGlyphIcon(:final data) => Icon(data, size: resolvedSize, color: resolvedColor, semanticLabel: semanticLabel),
      FrostSvgIcon(:final asset, :final package, :final mirrorInRtl) => SvgPicture.asset(
        asset,
        package: package,
        width: resolvedSize,
        height: resolvedSize,
        colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
        semanticsLabel: semanticLabel,
        excludeFromSemantics: semanticLabel == null,
        matchTextDirection: mirrorInRtl,
      ),
    };
  }
}
