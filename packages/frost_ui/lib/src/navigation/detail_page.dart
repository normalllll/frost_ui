import 'package:flutter/material.dart';
import 'package:frost_ui/src/foundation/metrics.dart';
import 'package:frost_ui/src/motion/page_transition.dart';

/// A pushed detail page with the shared page transition. It is a plain
/// [Page], so any router that takes pages (go_router's `pageBuilder`,
/// Navigator 2.0) can use it. [heroLed] pages receive a flying image; their
/// own motion is halved.
class FrostDetailPage<T> extends Page<T> {
  const FrostDetailPage({required this.child, this.heroLed = false, super.key, super.name, super.arguments, super.restorationId});

  final Widget child;
  final bool heroLed;

  @override
  Route<T> createRoute(BuildContext context) => PageRouteBuilder<T>(
    settings: this,
    transitionDuration: FrostMotion.duration(context, FrostMotion.page),
    reverseTransitionDuration: FrostMotion.duration(context, FrostMotion.exit),
    pageBuilder: (context, animation, secondaryAnimation) => child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) => frostPageTransition(context, animation, secondaryAnimation, child, heroLed: heroLed),
  );
}
