import 'package:flutter/foundation.dart';

/// Internal layout-to-paint notification. It never rebuilds a widget or repairs
/// geometry after layout; the first layout establishes its identity silently.
enum FrostLayoutChange { identity, viewport }

class FrostLayoutIdentity extends ChangeNotifier {
  Object? _identity, _viewport;
  FrostLayoutChange change = FrostLayoutChange.viewport;
  bool get identityChanged => change == FrostLayoutChange.identity;
  Object? get current => _identity;

  /// A [quiet] update records a new identity that moved nothing already on
  /// screen, so it is reported like a viewport change.
  void update(Object identity, {required Object viewport, bool quiet = false}) {
    if (_identity == identity && _viewport == viewport) return;
    final initial = _identity == null;
    change = _identity != identity && !quiet ? FrostLayoutChange.identity : FrostLayoutChange.viewport;
    _identity = identity;
    _viewport = viewport;
    if (!initial) notifyListeners();
  }
}
