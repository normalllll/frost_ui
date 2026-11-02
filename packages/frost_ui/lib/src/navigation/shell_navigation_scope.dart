import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../foundation/icon_data.dart';

/// Back to the first page of a destination, offered by page headers once the
/// route is two levels deep in bottom navigation.
@immutable
class FrostShellBackToFirst {
  const FrostShellBackToFirst({required this.label, required this.icon, required this.onPressed});

  /// The caller-localized label, also the button's tooltip.
  final String label;
  final FrostIconData icon;
  final VoidCallback onPressed;

  @override
  bool operator ==(Object other) => other is FrostShellBackToFirst && other.label == label && other.icon == icon && other.onPressed == onPressed;

  @override
  int get hashCode => Object.hash(label, icon, onPressed);
}

/// The horizontal shell owns ordinary page back; vertical layouts use page headers.
class FrostShellNavigationScope extends InheritedWidget {
  const FrostShellNavigationScope({
    required this.ownsBackControl,
    required this.canGoBack,
    required this.goBack,
    required this.primaryReselection,
    required super.child,
    this.routeDepth = 0,
    this.backToFirst,
    super.key,
  });

  /// True when a horizontal shell supplies the fixed Back control. Page headers
  /// and custom page navigation must omit their ordinary Back in that case.
  /// A standalone route outside the shell still owns its own close/back control.
  final bool ownsBackControl;
  final bool canGoBack;
  final VoidCallback goBack;

  /// The destination index tapped again while already selected, with a
  /// sequence number so repeated taps are distinct events.
  final ValueListenable<({int index, int sequence})> primaryReselection;
  final int routeDepth;
  final FrostShellBackToFirst? backToFirst;
  bool get showsBackToFirst => !ownsBackControl && routeDepth >= 2 && backToFirst != null;

  static FrostShellNavigationScope? maybeOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<FrostShellNavigationScope>();

  @override
  bool updateShouldNotify(FrostShellNavigationScope oldWidget) =>
      backToFirst != oldWidget.backToFirst ||
      routeDepth != oldWidget.routeDepth ||
      ownsBackControl != oldWidget.ownsBackControl ||
      canGoBack != oldWidget.canGoBack ||
      goBack != oldWidget.goBack ||
      primaryReselection != oldWidget.primaryReselection;
}
