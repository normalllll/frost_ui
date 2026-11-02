import 'package:flutter/widgets.dart';

import 'density.dart';

/// Visual sizes follow the platform's pointer/touch column, not density.
enum FrostControlSize {
  small,
  compact,
  regular,
  large;

  double visualHeight({required bool touch}) => switch ((this, touch)) {
    (small, false) => 30,
    (small, true) => 30,
    (compact, false) => 32,
    (regular, false) => 36,
    (large, false) => 44,
    (compact, true) => 36,
    (regular, true) => 44,
    (large, true) => 52,
  };

  double get iconSize => switch (this) {
    small => 14,
    compact => 16,
    regular => 18,
    large => 20,
  };

  double height(BuildContext context) => FrostDensity.of(context).heightFor(this);
  static double minimumHitHeight({required bool touch}) => touch ? 44 : 36;
}
