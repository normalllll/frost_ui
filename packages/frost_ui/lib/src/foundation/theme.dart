import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../motion/page_transition.dart';
import '_control_geometry.dart';
import '_menu_metrics.dart';
import 'density.dart';
import 'feedback.dart';
import 'fonts.dart';
import 'metrics.dart';
import 'radius.dart';
import 'scope.dart';
import 'sizes.dart';
import 'spacing.dart';
import 'tokens.dart';
import 'typography.dart';

// Keep idle/hover/drag thumbs inside the outside page margin.
const _scrollbarThickness = 6.0;

/// Builds the app's [ThemeData] from its [FrostConfig]. Material component
/// themes are restyled into the Frost language, so the Material widgets Frost
/// components use internally look like the rest.
abstract final class FrostTheme {
  static ThemeData build({
    required FrostConfig config,
    required Brightness brightness,
    required TargetPlatform platform,
    required Locale locale,
    FrostTone tone = FrostTone.neutral,
    Color? accent,
    FrostDensity density = FrostDensity.comfortable,
    bool reducedMotion = false,
  }) {
    final palettes = config.palettes;
    return _build(
      config: config,
      palettes: palettes,
      tokens: palettes.palette(brightness, tone, accent ?? palettes.defaultAccent(brightness)),
      brightness: brightness,
      fonts: config.fonts.resolve(platform: platform, locale: locale),
      platform: platform,
      density: density.forPlatform(platform),
      reducedMotion: reducedMotion,
    );
  }

  static ThemeData _build({
    required FrostConfig config,
    required FrostPalettes palettes,
    required FrostThemeTokens tokens,
    required Brightness brightness,
    required FrostFontChain fonts,
    required TargetPlatform platform,
    required FrostDensity density,
    required bool reducedMotion,
  }) {
    // Controls shrink with the density; their vertical padding gives up the
    // difference so labels stay centred at every size.
    final shrink = density.name == FrostDensity.compact.name ? FrostGap.inline : 0.0;
    final groupGap = FrostGap.group - shrink;
    final colorScheme = _colorScheme(palettes: palettes, tokens: tokens, brightness: brightness);
    final typography = FrostTypography(
      platform: platform,
      base: TextStyle(fontFamily: fonts.family, fontFamilyFallback: fonts.fallbacks),
      monospace: config.fonts.monospace,
      numeric: config.fonts.numeric,
    );
    final controlRadius = FrostRadius.forHeight(density.controlHeight);
    final menuSize = FrostMenuMetrics.sizeFor(density);
    final menuGeometry = frostControlTextGeometry(baseHeight: density.heightFor(menuSize), style: typography.style(FrostTextRole.callout));
    final menuRadius = FrostRadius.inner(FrostRadius.lg, FrostMenuMetrics.panelInset);
    final base = _applyTextTheme(
      ThemeData(
        platform: platform,
        colorScheme: colorScheme,
        // Pages are transparent over the window's ambient backdrop.
        scaffoldBackgroundColor: Colors.transparent,
        pageTransitionsTheme: PageTransitionsTheme(
          builders: {
            for (final target in TargetPlatform.values) target: frostPageTransitionsBuilder(reducedMotion: reducedMotion, pointer: density.usesPointer),
          },
        ),
        fontFamily: fonts.family,
        fontFamilyFallback: fonts.fallbacks,
        useMaterial3: true,
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
        extensions: [tokens, density, typography, FrostConfigTheme(config)],
        iconTheme: IconThemeData(size: FrostControlSize.regular.iconSize, color: tokens.textSecondary),
      ),
      typography,
    );

    return base.copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: tokens.fillStrong,
      hoverColor: tokens.fillSubtle,
      focusColor: tokens.fillSubtle,
      dividerColor: tokens.separator,
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(_scrollbarThickness),
        radius: const Radius.circular(999),
        minThumbLength: 28,
        crossAxisMargin: 0,
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => tokens.textPrimary.withValues(
            alpha: states.contains(WidgetState.dragged)
                ? .50
                : states.contains(WidgetState.hovered)
                ? .38
                : .24,
          ),
        ),
        trackColor: const WidgetStatePropertyAll(Colors.transparent),
        trackBorderColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: tokens.accent,
        selectionColor: tokens.accent.withValues(alpha: .24),
        selectionHandleColor: tokens.accentInk,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: ShapeDecoration(
          color: tokens.surfaceRaised,
          shape: _shape(config, FrostRadius.sm),
          shadows: [...tokens.shadowAmbient, ...tokens.shadowContact],
        ),
        textStyle: base.textTheme.bodySmall?.copyWith(color: tokens.textPrimary),
        padding: EdgeInsets.symmetric(horizontal: groupGap, vertical: FrostGap.related),
        waitDuration: const Duration(milliseconds: 500),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: frostFeedbackStyle(tokens).copyWith(
          // Menus express keyboard current-item focus with the same whole-row
          // fill as pointer hover. Removing focused here also suppresses the
          // button-only ring in the shared Material feedback painter.
          backgroundBuilder: (context, states, child) => frostButtonFeedbackBackground(context, {
            ...states.where((state) => state != WidgetState.focused),
            if (states.contains(WidgetState.focused)) WidgetState.hovered,
          }, child),
          side: const WidgetStatePropertyAll(BorderSide.none),
          minimumSize: WidgetStatePropertyAll(Size(0, menuGeometry.height)),
          padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: FrostMenuMetrics.rowInset, vertical: menuGeometry.verticalInset)),
          visualDensity: VisualDensity.standard,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          textStyle: WidgetStatePropertyAll(typography.style(FrostTextRole.callout)),
          shape: WidgetStatePropertyAll(_shape(config, menuRadius)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(
              overlayColor: Colors.transparent,
              minimumSize: Size.square(density.controlHeight),
              iconSize: FrostControlSize.regular.iconSize,
              foregroundColor: colorScheme.onSurfaceVariant,
              disabledForegroundColor: tokens.textQuaternary,
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              shape: _shape(config, FrostRadius.forHeight(density.controlHeight)),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostButtonFeedbackBackground,
              backgroundColor: WidgetStateProperty.resolveWith((states) => frostButtonRestingSurface(tokens, states, resting: Colors.transparent)),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens, restingSide: BorderSide.none).side,
            ),
      ),
      textButtonTheme: TextButtonThemeData(
        style:
            TextButton.styleFrom(
              overlayColor: Colors.transparent,
              foregroundColor: colorScheme.onSurface,
              disabledForegroundColor: tokens.textQuaternary,
              textStyle: base.textTheme.labelLarge,
              shape: _shape(config, controlRadius),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostButtonFeedbackBackground,
              backgroundColor: WidgetStateProperty.resolveWith((states) => frostButtonRestingSurface(tokens, states, resting: Colors.transparent)),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens, restingSide: BorderSide.none).side,
            ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: tokens.fill,
        contentPadding: EdgeInsets.symmetric(horizontal: groupGap, vertical: groupGap),
        border: _inputBorder(Colors.transparent, controlRadius, width: 0),
        enabledBorder: _inputBorder(Colors.transparent, controlRadius, width: 0),
        focusedBorder: _inputBorder(tokens.fieldFocus, controlRadius, width: FrostMetrics.fieldFocusWidth),
        errorBorder: _inputBorder(tokens.negativeInk, controlRadius, width: FrostMetrics.fieldFocusWidth),
        focusedErrorBorder: _inputBorder(tokens.negativeInk, controlRadius, width: FrostMetrics.fieldFocusWidth),
        hintStyle: WidgetStateTextStyle.resolveWith(
          (states) => base.textTheme.bodyMedium!.copyWith(color: states.contains(WidgetState.disabled) ? tokens.textQuaternary : tokens.textSecondary),
        ),
      ),
    );
  }

  static ThemeData _applyTextTheme(ThemeData theme, FrostTypography typography) => theme.copyWith(
    textTheme: TextTheme(
      displayLarge: typography.style(FrostTextRole.hero),
      displayMedium: typography.style(FrostTextRole.hero),
      displaySmall: typography.style(FrostTextRole.value),
      headlineLarge: typography.style(FrostTextRole.value),
      headlineMedium: typography.style(FrostTextRole.title1),
      headlineSmall: typography.style(FrostTextRole.title1),
      titleLarge: typography.style(FrostTextRole.title2),
      titleMedium: typography.style(FrostTextRole.headline),
      titleSmall: typography.style(FrostTextRole.headline),
      bodyLarge: typography.style(FrostTextRole.body),
      bodyMedium: typography.style(FrostTextRole.body),
      bodySmall: typography.style(FrostTextRole.subheadline),
      labelLarge: typography.style(FrostTextRole.callout),
      labelMedium: typography.style(FrostTextRole.footnote),
      labelSmall: typography.style(FrostTextRole.caption),
    ).apply(bodyColor: theme.colorScheme.onSurface, displayColor: theme.colorScheme.onSurface),
  );

  static ColorScheme _colorScheme({required FrostPalettes palettes, required FrostThemeTokens tokens, required Brightness brightness}) {
    final base = ColorScheme.fromSeed(seedColor: tokens.accent, brightness: brightness);
    return base.copyWith(
      primary: tokens.accent,
      onPrimary: tokens.onAccent,
      primaryContainer: tokens.selectionSurface,
      onPrimaryContainer: tokens.selectionInk,
      secondary: tokens.accent,
      onSecondary: tokens.onAccent,
      secondaryContainer: tokens.selectionSurface,
      onSecondaryContainer: tokens.selectionInk,
      tertiary: tokens.accent,
      onTertiary: tokens.onAccent,
      tertiaryContainer: tokens.selectionSurface,
      onTertiaryContainer: tokens.selectionInk,
      error: tokens.negativeInk,
      onError: tokens.surface,
      errorContainer: tokens.negativeTint,
      onErrorContainer: tokens.negativeInk,
      surface: tokens.surface,
      surfaceTint: tokens.surfaceTint,
      onSurface: tokens.textPrimary,
      surfaceContainerLowest: tokens.canvas,
      surfaceContainerLow: tokens.surface,
      surfaceContainer: tokens.surfaceInset,
      surfaceContainerHigh: tokens.surfaceRaised,
      surfaceContainerHighest: tokens.surfaceMuted,
      onSurfaceVariant: tokens.textSecondary,
      inverseSurface: tokens.isDark ? palettes.lightNeutral.surface : palettes.darkNeutral.surface,
      onInverseSurface: tokens.isDark ? palettes.lightNeutral.textPrimary : palettes.darkNeutral.textPrimary,
      outline: tokens.line,
      outlineVariant: tokens.line,
      shadow: tokens.shadow,
      scrim: tokens.onMediaScrim,
    );
  }

  static OutlinedBorder _shape(FrostConfig config, double radius, {BorderRadiusGeometry? corners, BorderSide side = BorderSide.none}) =>
      config.continuousCorners
      ? RoundedSuperellipseBorder(borderRadius: corners ?? FrostRadius.borderRadius(radius), side: side)
      : RoundedRectangleBorder(borderRadius: corners ?? FrostRadius.borderRadius(radius), side: side);

  static OutlineInputBorder _inputBorder(Color color, double controlRadius, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: FrostRadius.borderRadius(controlRadius),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

/// Status and navigation bar styling over the transparent ambient backdrop.
SystemUiOverlayStyle frostSystemOverlayStyle(FrostThemeTokens tokens) => (tokens.isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
  statusBarColor: Colors.transparent,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarContrastEnforced: false,
);
