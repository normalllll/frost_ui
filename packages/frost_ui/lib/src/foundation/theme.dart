import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:frost_ui/src/foundation/color_math.dart';
import 'package:frost_ui/src/foundation/density.dart';
import 'package:frost_ui/src/foundation/feedback.dart';
import 'package:frost_ui/src/foundation/fonts.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/foundation/scope.dart';
import 'package:frost_ui/src/foundation/tokens.dart';
import 'package:frost_ui/src/motion/page_transition.dart';

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
      density: density,
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
    final shrink = (FrostDensity.comfortable.controlHeight - density.controlHeight) / 2;
    final colorScheme = _colorScheme(palettes: palettes, tokens: tokens, brightness: brightness);
    final base = ThemeData(
      platform: platform,
      colorScheme: colorScheme,
      // Pages are transparent over the window's ambient backdrop.
      scaffoldBackgroundColor: Colors.transparent,
      pageTransitionsTheme: PageTransitionsTheme(
        builders: {for (final platform in TargetPlatform.values) platform: FrostPageTransitionsBuilder(reducedMotion: reducedMotion)},
      ),
      fontFamily: fonts.family,
      fontFamilyFallback: fonts.fallbacks,
      useMaterial3: true,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      extensions: [tokens, density, FrostConfigTheme(config)],
    );

    return _applyTextTheme(base).copyWith(
      splashFactory: NoSplash.splashFactory,
      splashColor: Colors.transparent,
      highlightColor: tokens.pressedSurface,
      hoverColor: tokens.hoverSurface,
      focusColor: tokens.hoverSurface,
      dividerColor: tokens.line,
      dividerTheme: DividerThemeData(color: tokens.line, thickness: 1, space: 1),
      appBarTheme: AppBarThemeData(
        // Headers sit on the ambient backdrop like the title bar above them.
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        // A transparent bar cannot infer icon brightness; use the palette's.
        systemOverlayStyle: frostSystemOverlayStyle(tokens),
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(color: colorScheme.onSurface, fontWeight: FontWeight.w600),
      ),
      cardTheme: CardThemeData(
        color: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        shadowColor: tokens.shadow,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
      ),
      tabBarTheme: TabBarThemeData(
        overlayColor: WidgetStateProperty.resolveWith((states) => frostShowsFocus(states) ? tokens.hoverSurface : frostFeedbackSurface(tokens, states)),
        labelColor: colorScheme.onSurface,
        unselectedLabelColor: colorScheme.onSurfaceVariant,
        indicatorColor: tokens.keyGraphicOn(tokens.surface),
        // A short rounded bar under the label, in the readable accent tone.
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: tokens.keyGraphicOn(tokens.surface), width: FrostMetrics.selectionIndicatorWidth),
          borderRadius: BorderRadius.circular(FrostMetrics.selectionIndicatorWidth),
          insets: const EdgeInsets.symmetric(horizontal: 6),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        // Hover and press read as a rounded pill, like the navigation items,
        // rather than a square block that runs into the bar's corners.
        splashBorderRadius: BorderRadius.circular(FrostMetrics.controlRadius),
        dividerColor: tokens.line,
        labelStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: base.textTheme.labelLarge,
        splashFactory: NoSplash.splashFactory,
      ),
      switchTheme: SwitchThemeData(
        mouseCursor: frostClickCursor,
        overlayColor: WidgetStateProperty.resolveWith((states) => frostButtonStateLayer(tokens, states, FrostFeedbackRole.quiet)),
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? tokens.disabledText
              : states.contains(WidgetState.selected)
              ? _switchThumb(tokens)
              : (tokens.isDark ? tokens.textSecondary : tokens.surfaceRaised),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? tokens.accent.withValues(alpha: states.contains(WidgetState.disabled) ? .38 : 1) : colorScheme.outline,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) => frostShowsFocus(states) ? tokens.focus : Colors.transparent),
      ),
      checkboxTheme: CheckboxThemeData(
        mouseCursor: frostClickCursor,
        overlayColor: WidgetStateProperty.resolveWith((states) => frostFeedbackSurface(tokens, states)),
        side: WidgetStateBorderSide.resolveWith(
          (states) => frostFeedbackBorder(
            tokens,
            states,
            restingSide: BorderSide(
              color: states.contains(WidgetState.selected) ? tokens.keyGraphicOn(tokens.surface) : colorScheme.onSurfaceVariant,
              width: 2,
            ),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.badgeRadius)),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? tokens.keyGraphicOn(tokens.surface).withValues(alpha: states.contains(WidgetState.disabled) ? .38 : 1)
              : Colors.transparent,
        ),
        checkColor: WidgetStatePropertyAll(tokens.keyGraphicOn(tokens.surface) == tokens.accent ? tokens.onAccent : tokens.surface),
      ),
      radioTheme: RadioThemeData(
        mouseCursor: frostClickCursor,
        overlayColor: WidgetStateProperty.resolveWith(
          (states) => frostFeedbackSurface(tokens, states, resting: frostShowsFocus(states) ? tokens.hoverSurface : Colors.transparent),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.disabled)
              ? colorScheme.outline
              : states.contains(WidgetState.selected)
              ? tokens.selectionInk
              : colorScheme.onSurfaceVariant,
        ),
      ),
      sliderTheme: SliderThemeData(
        mouseCursor: frostClickCursor,
        activeTrackColor: tokens.keyGraphicOn(tokens.surface),
        thumbColor: tokens.keyGraphicOn(tokens.surface),
        inactiveTrackColor: tokens.line,
        overlayColor: tokens.hoverSurface,
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: tokens.keyGraphicOn(tokens.surface), linearTrackColor: tokens.line),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: colorScheme.inverseSurface, borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
        textStyle: base.textTheme.bodySmall?.copyWith(color: colorScheme.onInverseSurface),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        waitDuration: const Duration(milliseconds: 500),
      ),
      menuButtonTheme: MenuButtonThemeData(
        // The menu surface owns the outer corners; contiguous rows fill it.
        style: frostFeedbackStyle(tokens).copyWith(shape: const WidgetStatePropertyAll(RoundedRectangleBorder())),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          padding: const WidgetStatePropertyAll(EdgeInsets.zero),
          backgroundColor: WidgetStatePropertyAll(tokens.surfaceRaised),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(4),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(FrostMetrics.groupRadius),
              side: BorderSide(color: tokens.line),
            ),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style:
            IconButton.styleFrom(
              overlayColor: Colors.transparent,
              minimumSize: Size.square(density.controlHeight),
              iconSize: FrostMetrics.iconSize,
              foregroundColor: colorScheme.onSurfaceVariant,
              disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
              highlightColor: Colors.transparent,
              hoverColor: Colors.transparent,
              shape: const CircleBorder(),
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
              disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
              textStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostButtonFeedbackBackground,
              backgroundColor: WidgetStateProperty.resolveWith((states) => frostButtonRestingSurface(tokens, states, resting: Colors.transparent)),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens, restingSide: BorderSide.none).side,
            ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
              backgroundColor: tokens.actionFill,
              overlayColor: Colors.transparent,
              foregroundColor: tokens.onAction,
              disabledBackgroundColor: tokens.surfaceInset,
              disabledForegroundColor: tokens.disabledText,
              elevation: 0,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12 - shrink),
              textStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostPrimaryButtonFeedbackBackground,
              backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.disabled) ? tokens.surfaceInset : tokens.actionFill),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens).side,
            ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
              overlayColor: Colors.transparent,
              backgroundColor: tokens.surfaceRaised,
              foregroundColor: colorScheme.onSurface,
              disabledBackgroundColor: tokens.surfaceMuted,
              disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.42),
              elevation: 0,
              shadowColor: Colors.transparent,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12 - shrink),
              textStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostSecondaryButtonFeedbackBackground,
              backgroundColor: WidgetStatePropertyAll(tokens.surfaceInset),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens).side,
            ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
              overlayColor: Colors.transparent,
              foregroundColor: colorScheme.onSurface,
              disabledForegroundColor: colorScheme.onSurfaceVariant.withValues(alpha: 0.38),
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 11 - shrink),
              textStyle: base.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
            ).copyWith(
              mouseCursor: frostClickCursor,
              backgroundBuilder: frostSecondaryButtonFeedbackBackground,
              backgroundColor: WidgetStatePropertyAll(tokens.surfaceInset),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              side: frostFeedbackStyle(tokens).side,
            ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(style: _segmentedButtonStyle(tokens, colorScheme, base.textTheme.labelLarge, density)),
      chipTheme: ChipThemeData(
        // Selected chips use the accent wash, a check and accent ink; resting
        // chips stay neutral and never carry a coloured outline.
        color: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? Color.alphaBlend(frostButtonStateLayer(tokens, states, FrostFeedbackRole.quiet), tokens.selectionSurface)
              : frostFeedbackSurface(tokens, states, resting: states.contains(WidgetState.disabled) ? tokens.surfaceMuted : tokens.surfaceInset),
        ),
        backgroundColor: tokens.surfaceInset,
        selectedColor: tokens.selectionSurface,
        disabledColor: tokens.surfaceMuted,
        checkmarkColor: tokens.selectionInk,
        labelStyle: base.textTheme.labelLarge?.copyWith(color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
        secondaryLabelStyle: base.textTheme.labelLarge?.copyWith(color: tokens.selectionInk, fontWeight: FontWeight.w600),
        side: WidgetStateBorderSide.resolveWith((states) => frostFeedbackBorder(tokens, states)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        showCheckmark: true,
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: tokens.surfaceInset,
        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12 - shrink),
        border: _inputBorder(tokens.line),
        enabledBorder: _inputBorder(tokens.line),
        focusedBorder: _inputBorder(tokens.fieldFocus, width: FrostMetrics.fieldFocusWidth),
        errorBorder: _inputBorder(colorScheme.error),
        focusedErrorBorder: _inputBorder(colorScheme.error, width: FrostMetrics.fieldFocusWidth),
        hintStyle: base.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.72)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        menuPadding: EdgeInsets.zero,
        color: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.modalRadius)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(FrostMetrics.modalRadius))),
      ),
      listTileTheme: ListTileThemeData(
        mouseCursor: frostClickCursor,
        iconColor: colorScheme.onSurfaceVariant,
        textColor: colorScheme.onSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      ),
    );
  }

  static ThemeData _applyTextTheme(ThemeData theme) {
    return theme.copyWith(
      textTheme: theme.textTheme.copyWith(
        displayLarge: theme.textTheme.displayLarge?.copyWith(fontWeight: FontWeight.w600),
        displayMedium: theme.textTheme.displayMedium?.copyWith(fontWeight: FontWeight.w600),
        displaySmall: theme.textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
        headlineLarge: theme.textTheme.headlineLarge?.copyWith(fontWeight: FontWeight.w600),
        headlineMedium: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
        headlineSmall: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
        titleLarge: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        titleMedium: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        titleSmall: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w400),
        bodyMedium: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w400),
        bodySmall: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w400),
        labelLarge: theme.textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        labelMedium: theme.textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        labelSmall: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

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
      error: tokens.textPrimary,
      onError: tokens.surface,
      errorContainer: tokens.surfaceMuted,
      onErrorContainer: tokens.textPrimary,
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
      scrim: Colors.black.withValues(alpha: tokens.isDark ? .48 : .24),
    );
  }

  static Color _switchThumb(FrostThemeTokens tokens) {
    final lightThumb = tokens.isDark ? tokens.textPrimary : tokens.surfaceRaised;
    // Keep the familiar light thumb on the default pink track. On an almost
    // white custom track, a dark thumb is needed to retain a visible handle.
    return colorContrast(tokens.accent, lightThumb) >= 2.3 ? lightThumb : tokens.onAccent;
  }

  static ButtonStyle _segmentedButtonStyle(FrostThemeTokens tokens, ColorScheme colorScheme, TextStyle? labelStyle, FrostDensity density) {
    return ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, density.controlHeight)),
      textStyle: WidgetStatePropertyAll(labelStyle?.copyWith(fontWeight: FontWeight.w600)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 9)),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(borderRadius: BorderRadius.circular(FrostMetrics.controlRadius))),
      side: WidgetStateProperty.resolveWith((states) {
        return frostFeedbackBorder(tokens, states);
      }),
      mouseCursor: frostClickCursor,
      backgroundBuilder: frostButtonFeedbackBackground,
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return tokens.isDark ? tokens.surfaceMuted : tokens.surfaceRaised;
        }

        return tokens.isDark ? tokens.surfaceRaised : tokens.surfaceInset;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return colorScheme.onSurfaceVariant.withValues(alpha: 0.38);
        }
        if (states.contains(WidgetState.selected)) {
          return tokens.selectionInk;
        }

        return colorScheme.onSurfaceVariant;
      }),
      iconColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected) && !states.contains(WidgetState.disabled)
            ? tokens.keyGraphicOn(tokens.surfaceRaised)
            : colorScheme.onSurfaceVariant,
      ),
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    );
  }

  static OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(FrostMetrics.controlRadius),
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
