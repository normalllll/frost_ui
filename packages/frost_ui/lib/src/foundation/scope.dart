import 'package:flutter/material.dart';

import 'package:frost_ui/src/controls/icon.dart';
import 'fonts.dart';
import 'tokens.dart';

/// Every text a Frost component may show on its own, in the current locale.
/// The library contains no language; the app supplies all of it.
@immutable
class FrostLabels {
  const FrostLabels({
    required this.retry,
    required this.error,
    required this.errorDetails,
    required this.copyDetails,
    required this.detailsCopied,
    required this.loading,
    required this.loadFailed,
    required this.noMoreItems,
    required this.pullToRefresh,
    required this.releaseToRefresh,
    required this.refreshing,
    required this.refreshComplete,
    required this.refreshFailed,
    required this.previous,
    required this.next,
    required this.back,
    required this.more,
    required this.expandNavigation,
    required this.collapseNavigation,
    required this.clearText,
    required this.search,
    required this.dismiss,
  });

  final String retry;

  /// Title of a full-page error on compact layouts.
  final String error;
  final String errorDetails;
  final String copyDetails;

  /// Toast after the error details were copied.
  final String detailsCopied;
  final String loading;
  final String loadFailed;

  /// End of a paged list, and the empty state of a list without its own.
  final String noMoreItems;
  final String pullToRefresh;
  final String releaseToRefresh;
  final String refreshing;
  final String refreshComplete;
  final String refreshFailed;

  /// Scroll a horizontal shelf back or forward.
  final String previous;
  final String next;
  final String back;

  /// The navigation overflow menu.
  final String more;
  final String expandNavigation;
  final String collapseNavigation;

  /// Clears a search or text field.
  final String clearText;

  /// Submits a search field.
  final String search;

  /// Closes a toast or panel.
  final String dismiss;
}

/// Turns failures into user-facing text. [message] is the localized summary;
/// [details] is optional technical detail shown collapsed (status, endpoint),
/// which must never contain credentials or private content.
@immutable
class FrostErrorPresenter {
  const FrostErrorPresenter({required this.message, required this.details});

  final String Function(BuildContext context, Object error) message;
  final String? Function(Object error) details;
}

/// What an app chooses about the shared design language. The design values
/// themselves ([FrostMetrics], [FrostMotion], surface materials) are fixed.
///
/// Keep one instance per app (a top-level `final`); [FrostScope] compares
/// configurations by identity of their parts.
@immutable
class FrostConfig {
  const FrostConfig({required this.palettes, required this.fonts, required this.icons, required this.labels, required this.errors});

  /// Palettes, default accent and accent presets; start from
  /// [FrostPalettes.pink] and `copyWith` a different accent.
  final FrostPalettes palettes;
  final FrostFonts fonts;
  final FrostIconSet icons;

  /// Labels in the locale of [context]; called during build.
  final FrostLabels Function(BuildContext context) labels;
  final FrostErrorPresenter errors;

  FrostConfig copyWith({
    FrostPalettes? palettes,
    FrostFonts? fonts,
    FrostIconSet? icons,
    FrostLabels Function(BuildContext context)? labels,
    FrostErrorPresenter? errors,
  }) => FrostConfig(
    palettes: palettes ?? this.palettes,
    fonts: fonts ?? this.fonts,
    icons: icons ?? this.icons,
    labels: labels ?? this.labels,
    errors: errors ?? this.errors,
  );
}

/// Carries the [FrostConfig] inside a theme built by `FrostTheme.build`, so
/// every widget under that theme can reach it without a [FrostScope].
@immutable
class FrostConfigTheme extends ThemeExtension<FrostConfigTheme> {
  const FrostConfigTheme(this.config);

  final FrostConfig config;

  @override
  FrostConfigTheme copyWith({FrostConfig? config}) => FrostConfigTheme(config ?? this.config);

  @override
  FrostConfigTheme lerp(ThemeExtension<FrostConfigTheme>? other, double t) => t < .5 || other is! FrostConfigTheme ? this : other;
}

/// Provides the user's material preferences, and optionally a [FrostConfig]
/// that overrides the theme's, to every Frost widget below it. Place it
/// above the app's `WidgetsApp`.
class FrostScope extends InheritedWidget {
  const FrostScope({required super.child, this.config, this.reduceTransparency = false, super.key});

  /// Overrides the configuration carried by the theme, if given.
  final FrostConfig? config;

  /// Draws glass surfaces as opaque panels. High contrast does the same
  /// regardless of this flag.
  final bool reduceTransparency;

  static FrostScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostScope>();

  /// The configuration of the nearest scope, else of the nearest Frost theme.
  static FrostConfig configOf(BuildContext context) {
    final config = maybeOf(context)?.config ?? Theme.of(context).extension<FrostConfigTheme>()?.config;
    assert(config != null, 'No FrostConfig: build the theme with FrostTheme.build or place a FrostScope above this widget.');
    return config!;
  }

  /// Whether glass surfaces render opaque here.
  static bool solidSurfaces(BuildContext context) => (maybeOf(context)?.reduceTransparency ?? false) || MediaQuery.highContrastOf(context);

  /// Labels in the locale of [context].
  static FrostLabels labelsOf(BuildContext context) => configOf(context).labels(context);

  /// The app's error text.
  static FrostErrorPresenter errorsOf(BuildContext context) => configOf(context).errors;

  @override
  bool updateShouldNotify(FrostScope oldWidget) => !identical(config, oldWidget.config) || reduceTransparency != oldWidget.reduceTransparency;
}
