import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart' show GlobalMaterialLocalizations, MaterialApp, ThemeData, ThemeMode;
import 'package:skeletonizer/skeletonizer.dart';

import '../controls/toast.dart';
import '../feedback/skeleton.dart';
import '../layout/auto_scaffold.dart';
import '../media/system_chrome.dart';
import '../surface/_window_background.dart';
import 'appearance.dart';
import 'density.dart';
import 'input_feedback.dart';
import 'metrics.dart';
import 'scope.dart';
import 'theme.dart';
import 'tokens.dart';

/// Theme and environment integration; routing remains owned by the caller.
class FrostApp extends StatelessWidget {
  const FrostApp.router({
    required this.config,
    required this.routerConfig,
    required this.title,
    this.appearance,
    this.density = FrostDensity.comfortable,
    this.locale,
    this.supportedLocales = const [Locale('en', 'US')],
    this.localizationsDelegates,
    this.builder,
    this.debugShowCheckedModeBanner = false,
    super.key,
  });
  final FrostConfig config;
  final RouterConfig<Object> routerConfig;
  final String title;
  final FrostAppearance? appearance;
  final FrostDensity density;
  final Locale? locale;
  final Iterable<Locale> supportedLocales;

  /// Delegates of the app. Frost adds the Material, Cupertino and Widgets
  /// delegates after them, so an app delegate of the same type wins; apps need
  /// not pass flutter_localizations' legacy Material delegate, which the Material
  /// widgets under Frost cannot read.
  final Iterable<LocalizationsDelegate<dynamic>>? localizationsDelegates;
  final TransitionBuilder? builder;
  final bool debugShowCheckedModeBanner;

  @override
  Widget build(BuildContext context) => _FrostAppBody(app: this, reduceTransparency: FrostScope.maybeOf(context)?.reduceTransparency ?? false);
}

class _FrostAppBody extends StatefulWidget {
  const _FrostAppBody({required this.app, required this.reduceTransparency});
  final FrostApp app;
  final bool reduceTransparency;

  @override
  State<_FrostAppBody> createState() => _FrostAppBodyState();
}

typedef _ThemeInputs = ({FrostConfig config, TargetPlatform platform, Locale locale, FrostTone tone, Color accent, FrostDensity density, bool reducedMotion});

class _FrostAppBodyState extends State<_FrostAppBody> {
  // A rebuild with the same inputs hands MaterialApp the same ThemeData, so
  // Theme does not notify its dependents. Two builds never compare equal:
  // each carries new resolver closures.
  final _themes = <Brightness, (_ThemeInputs, ThemeData)>{};

  ThemeData _theme(Brightness brightness, _ThemeInputs inputs) {
    // FrostConfig has no ==, so the config is compared by identity, as
    // FrostScope does.
    if (_themes[brightness] case (final previous, final theme) when previous == inputs) return theme;
    final theme = FrostTheme.build(
      config: inputs.config,
      brightness: brightness,
      platform: inputs.platform,
      locale: inputs.locale,
      tone: inputs.tone,
      accent: inputs.accent,
      density: inputs.density,
      reducedMotion: inputs.reducedMotion,
    );
    _themes[brightness] = (inputs, theme);
    return theme;
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final FrostApp(:config, :appearance, :density, :locale, :builder) = app;
    final view = View.of(context);
    final inheritedMedia = MediaQuery.maybeOf(context);
    final reduced = inheritedMedia?.disableAnimations ?? view.platformDispatcher.accessibilityFeatures.disableAnimations;
    final effectiveLocale = locale ?? view.platformDispatcher.locale;
    final selected = appearance ?? FrostAppearance.initial(config.palettes);
    ThemeData theme(Brightness brightness) => _theme(brightness, (
      config: config,
      platform: defaultTargetPlatform,
      locale: effectiveLocale,
      tone: selected.effectiveToneFor(brightness),
      accent: selected.accentFor(brightness),
      density: density,
      reducedMotion: reduced,
    ));
    return FrostScope(
      config: config,
      reduceTransparency: widget.reduceTransparency,
      child: MaterialApp.router(
        title: app.title,
        routerConfig: app.routerConfig,
        debugShowCheckedModeBanner: app.debugShowCheckedModeBanner,
        theme: theme(Brightness.light),
        darkTheme: theme(Brightness.dark),
        themeMode: switch (selected.mode) {
          FrostThemeMode.system => ThemeMode.system,
          FrostThemeMode.light => ThemeMode.light,
          FrostThemeMode.dark => ThemeMode.dark,
        },
        themeAnimationDuration: reduced ? Duration.zero : FrostMotion.layoutFade,
        themeAnimationCurve: Curves.easeInOutCubic,
        locale: locale,
        supportedLocales: app.supportedLocales,
        localizationsDelegates: [...?app.localizationsDelegates, ...GlobalMaterialLocalizations.delegates],
        builder: (context, child) {
          final data = MediaQuery.of(context);
          final targetBrightness = switch (selected.mode) {
            FrostThemeMode.light => Brightness.light,
            FrostThemeMode.dark => Brightness.dark,
            FrostThemeMode.system => data.platformBrightness,
          };
          return MediaQuery(
            data: data.copyWith(disableAnimations: reduced, textScaler: inheritedMedia?.textScaler ?? data.textScaler),
            child: AnnotatedRegion<SystemUiOverlayStyle>(
              value: frostSystemOverlayStyle(FrostThemeTokens.of(context)),
              child: SkeletonizerConfig(
                data: frostSkeletonConfig(context),
                child: FrostLayoutScope(
                  // Above the toasts, whose buttons also take the touch-sized region.
                  child: FrostInputFeedback(
                    child: FrostToastHost(
                      child: FrostAmbientThemeScope(
                        tokens: config.palettes.palette(targetBrightness, selected.effectiveToneFor(targetBrightness), selected.accentFor(targetBrightness)),
                        child: FrostMediaSystemChromeHost(
                          child: Builder(builder: (context) => builder?.call(context, child) ?? child ?? const SizedBox.shrink()),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
