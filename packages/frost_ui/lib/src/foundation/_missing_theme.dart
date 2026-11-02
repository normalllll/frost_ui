import 'package:flutter/foundation.dart';

/// What a component throws when the theme above it was not built by Frost.
FlutterError frostMissingThemeError(String what) => FlutterError.fromParts([
  ErrorSummary('No $what found: this widget needs a Frost theme above it.'),
  ErrorHint(
    'Build the app with FrostApp.router or the theme with FrostTheme.build. A plain Theme(data: ...) inside the app hides the Frost theme from its subtree.',
  ),
]);
