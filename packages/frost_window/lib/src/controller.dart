import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'placement.dart';

/// Whether a native desktop window plugin can be contacted. Actual decoration
/// geometry and controls come from FrostWindowState, independently of Theme.
bool get frostUsesCustomTitleBar =>
    !kIsWeb &&
    switch (defaultTargetPlatform) {
      TargetPlatform.windows || TargetPlatform.linux || TargetPlatform.macOS => true,
      _ => false,
    };

/// The requested system backdrop. [none] means no system backdrop: the app's
/// ambient image or solid base supplies the window background.
enum FrostWindowBackdrop { none, mica, micaAlt }

/// The actual decoration mode negotiated with the native window host.
enum FrostCaptionMode { system, client, nativeControls }

enum FrostCaptionAction { minimize, maximize, close }

/// Reported by the native host, independently of the app's Theme.platform.
enum FrostCaptionStyle { windows, adwaita, breeze }

enum FrostCaptionIcon { minimize, maximize, restore, close }

enum FrostFullscreenFailureReason { unavailable, rejected, timeout, superseded, disposed }

/// A request failed; the controller's actual window state remains authoritative.
class FrostFullscreenFailure extends FrostWindowFailure {
  const FrostFullscreenFailure(this.reason);
  final FrostFullscreenFailureReason reason;
}

class FrostWindowFailure implements Exception {
  const FrostWindowFailure();
}

/// Sanitised native diagnostics: method, failure code and native frame step.
/// Never contains window contents, input or titles.
typedef FrostWindowDiagnosticWriter = Future<void> Function(Map<String, Object?> diagnostic);

@immutable
class FrostWindowState {
  const FrostWindowState({
    this.fullscreen = false,
    this.fullscreenAvailable = false,
    this.fullscreenTransitioning = false,
    this.maximized = false,
    this.active = true,
    this.minimized = false,
    this.backdropActive = false,
    this.backdropAvailable = false,
    this.reduceTransparency = false,
    this.hoveredButton = '',
    this.pressedButton = '',
    this.revision = -1,
    this.captionMode = FrostCaptionMode.client,
    this.leftButtons = const [],
    this.rightButtons = const [FrostCaptionAction.minimize, FrostCaptionAction.maximize, FrostCaptionAction.close],
    this.nativeControls = Rect.zero,
    this.captionStyle = FrostCaptionStyle.windows,
    this.captionIcons = const {},
    this.geometry,
  });

  factory FrostWindowState.fromMap(Map<Object?, Object?> value, {FrostWindowState? previous}) => FrostWindowState(
    captionMode: switch (value['captionMode']) {
      'nativeControls' => FrostCaptionMode.nativeControls,
      'system' => FrostCaptionMode.system,
      null || 'client' => FrostCaptionMode.client,
      _ => throw const FormatException('Invalid native caption mode'),
    },
    leftButtons: _buttons(value['leftButtons'], const []),
    rightButtons: _buttons(value['rightButtons'], const [FrostCaptionAction.minimize, FrostCaptionAction.maximize, FrostCaptionAction.close]),
    nativeControls: _nativeRect(value['nativeControls']),
    captionStyle: switch (value['captionStyle']) {
      'adwaita' => FrostCaptionStyle.adwaita,
      'breeze' => FrostCaptionStyle.breeze,
      null || 'windows' => FrostCaptionStyle.windows,
      _ => throw const FormatException('Invalid native caption style'),
    },
    captionIcons: _icons(value['captionIcons'], previous?.captionIcons),
    fullscreen: value['fullscreen'] == true,
    fullscreenAvailable: value['fullscreenAvailable'] == true,
    fullscreenTransitioning: value['fullscreenTransitioning'] == true,
    maximized: value['maximized'] == true,
    active: value['active'] != false,
    minimized: value['minimized'] == true,
    backdropActive: value['backdropActive'] == true,
    backdropAvailable: value['backdropAvailable'] == true,
    reduceTransparency: value['reduceTransparency'] == true,
    hoveredButton: value['hoveredButton'] as String? ?? '',
    pressedButton: value['pressedButton'] as String? ?? '',
    revision: (value['revision'] as num?)?.toInt() ?? 0,
    geometry: switch (value['geometry']) {
      final Map<Object?, Object?> geometry => FrostWindowGeometry.fromMap(geometry),
      _ => null,
    },
  );

  final FrostCaptionMode captionMode;
  final FrostWindowGeometry? geometry;
  final FrostCaptionStyle captionStyle;
  final Map<FrostCaptionIcon, Uint8List> captionIcons;

  static Map<FrostCaptionIcon, Uint8List> _icons(Object? value, Map<FrostCaptionIcon, Uint8List>? previous) {
    if (value == null) return const {};
    final icons = <FrostCaptionIcon, Uint8List>{};
    for (final entry in (value as Map).entries) {
      final kind = FrostCaptionIcon.values.asNameMap()[entry.key as String] ?? (throw const FormatException('Unknown native caption icon'));
      final bytes = entry.value as Uint8List;
      if (bytes.isEmpty) throw const FormatException('Empty native caption icon');
      // Focus/resize notifications must not invalidate decoded Flutter images.
      final old = previous?[kind];
      icons[kind] = old != null && listEquals(old, bytes) ? old : bytes;
    }
    return Map.unmodifiable(icons);
  }

  final List<FrostCaptionAction> leftButtons, rightButtons;
  final Rect nativeControls;

  static List<FrostCaptionAction> _buttons(Object? value, List<FrostCaptionAction> defaults) => value == null
      ? defaults
      : List.unmodifiable(
          (value as List).map(
            (name) => FrostCaptionAction.values.asNameMap()[name as String] ?? (throw const FormatException('Unknown native caption button')),
          ),
        );
  static Rect _nativeRect(Object? value) {
    if (value == null) return Rect.zero;
    final coordinates = (value as List).cast<num>();
    if (coordinates.length != 4 || coordinates.any((n) => !n.isFinite) || coordinates[2] < coordinates[0] || coordinates[3] < coordinates[1]) {
      throw const FormatException('Invalid native control bounds');
    }
    return Rect.fromLTRB(coordinates[0].toDouble(), coordinates[1].toDouble(), coordinates[2].toDouble(), coordinates[3].toDouble());
  }

  /// Actual native fullscreen, never inferred from an accepted command.
  final bool fullscreen;
  final bool fullscreenAvailable;
  final bool fullscreenTransitioning;
  final bool maximized;
  final bool active;
  final bool minimized;

  /// Actual native support and system preference, not just the requested mode.
  /// Updated when Windows transparency, contrast or theme settings change.
  final bool backdropActive;

  /// Native DWM support and current system preferences permit a backdrop,
  /// independently of the requested mode. Updated with system setting changes.
  final bool backdropAvailable;

  /// Effective Windows transparency/high-contrast preference.
  final bool reduceTransparency;

  /// Native caption button under the pointer, as hit-tested by Windows so
  /// Snap Layouts keeps working: `maximize` or empty.
  final String hoveredButton;
  final String pressedButton;

  /// Native event order; a stale reply never overwrites a newer event.
  final int revision;
}

/// Talks to the native window plugin. One controller per window.
class FrostWindowController extends ChangeNotifier implements ValueListenable<FrostWindowState> {
  FrostWindowController({
    required this.minimumSize,
    this.channel = const MethodChannel('frost_window'),
    this.diagnosticWriter,
    this.registrationTimeout = const Duration(seconds: 5),
    this.fullscreenTimeout = const Duration(seconds: 10),
    this.geometryDebounce = const Duration(milliseconds: 200),
  });

  /// Smallest logical window size the user can resize to.
  final Size minimumSize;
  final MethodChannel channel;
  final FrostWindowDiagnosticWriter? diagnosticWriter;
  final Duration registrationTimeout;
  final Duration fullscreenTimeout;

  /// Trailing-edge notification for App-owned persistence, separate from the
  /// immediate caption/fullscreen state. No timer survives disposal.
  final Duration geometryDebounce;
  final _geometry = ValueNotifier<FrostWindowGeometry?>(null);
  ValueListenable<FrostWindowGeometry?> get geometry => _geometry;
  Timer? _geometryTimer;
  FrostWindowGeometry? _pendingGeometry;
  _FullscreenRequest? _fullscreenRequest;
  FrostFullscreenFailure? _fullscreenFailure;

  /// Retryable request error, independent of frame/bootstrap health.
  FrostFullscreenFailure? get fullscreenFailure => _fullscreenFailure;

  final Completer<void> _registration = Completer<void>();
  final _backRequests = ChangeNotifier();
  Future<void> _diagnosticTask = Future.value();
  // Wait for the host's actual mode before drawing client controls. In
  // particular, macOS already owns its native buttons on the first frame.
  FrostWindowState _state = const FrostWindowState(captionMode: FrostCaptionMode.system);
  Future<void>? _initializing;
  bool _initialized = false;
  bool _failed = false;
  bool _disposed = false;
  String? _failureMethod;
  String? _failureCode;

  FrostWindowState get state => _state;
  @override
  FrostWindowState get value => _state;
  bool get failed => _failed;
  bool get ready => _initialized && !_failed && !_disposed;
  String? get failureMethod => _failureMethod;
  String? get failureCode => _failureCode;

  /// Native Back requests: Alt+Left, the mouse back button and the browser
  /// back app command. They arrive here instead of as key events.
  void addBackListener(VoidCallback listener) => _backRequests.addListener(listener);
  void removeBackListener(VoidCallback listener) => _backRequests.removeListener(listener);

  Future<void> initialize() {
    if (_initialized || _disposed) return Future.value();
    return _initializing ??= _initialize().whenComplete(() => _initializing = null);
  }

  Future<void> _initialize() async {
    channel.setMethodCallHandler((call) async {
      if (_disposed) return;
      switch (call.method) {
        case 'navigateBack':
          _backRequests.notifyListeners();
        case 'registered':
          if (!_registration.isCompleted) _registration.complete();
        case 'stateChanged':
          if (!_registration.isCompleted) _registration.complete();
          if (call.arguments case final Map<Object?, Object?> arguments) {
            try {
              _acceptState(arguments);
            } on FrostWindowFailure {
              // A malformed event is dropped; the last accepted state stays authoritative.
              _logDiagnostic('stateChanged', 'invalid_state');
            }
          }
      }
    });
    // Dart can start before the plugin registers its channel. Probe an
    // already registered host or await its explicit registration event; never
    // race the first command against native startup.
    try {
      await channel.invokeMethod<Object?>('getDiagnostics');
      if (!_registration.isCompleted) _registration.complete();
    } on MissingPluginException {
      _logDiagnostic('bootstrap', 'waiting_registration');
    } on PlatformException {
      _recordFailure('bootstrap', 'platform_error');
      throw const FrostWindowFailure();
    }
    try {
      await _registration.future.timeout(registrationTimeout);
    } on TimeoutException {
      _recordFailure('bootstrap', 'registration_timeout');
      throw const FrostWindowFailure();
    }
    if (_disposed) return;
    await _invoke<void>('configure', [minimumSize.width, minimumSize.height], true);
    final result = await _invoke<Object?>('getState', null, true);
    if (_disposed) return;
    if (result is! Map) {
      _recordFailure('getState', 'invalid_state');
      throw const FrostWindowFailure();
    }
    // Parse before marking the controller ready, so a malformed startup state
    // leaves it failed and retryable with the previous state untouched.
    final FrostWindowState initial;
    try {
      initial = _parseState(Map<Object?, Object?>.from(result));
    } on FrostWindowFailure {
      _recordFailure('getState', 'invalid_state');
      rethrow;
    }
    _initialized = true;
    _failed = false;
    _failureMethod = null;
    _failureCode = null;
    _applyState(initial);
    notifyListeners();
  }

  FrostWindowState _parseState(Map<Object?, Object?> value) {
    try {
      return FrostWindowState.fromMap(value, previous: _state);
    } on FormatException {
      throw const FrostWindowFailure();
    } on TypeError {
      throw const FrostWindowFailure();
    }
  }

  void _acceptState(Map<Object?, Object?> value) => _applyState(_parseState(value));

  void _applyState(FrostWindowState next) {
    // A reply to the startup query can arrive after a newer native event.
    if (next.revision < _state.revision || _disposed) return;
    _state = next;
    if (next.geometry case final geometry?) _queueGeometry(geometry);
    final request = _fullscreenRequest;
    if (request != null && request.acknowledged && !next.fullscreenTransitioning && next.fullscreen == request.target) {
      _finishFullscreen(request, null);
    }
    notifyListeners();
  }

  /// Requests a target and completes only after both native acknowledgement and
  /// authoritative actual state agree. Repeats share a pending request; a newer
  /// target supersedes the old wait. External transitions never trigger re-entry.
  /// A route owner must request false when it leaves, including during entry.
  Future<void> setFullscreen(bool target) {
    if (_disposed) return Future.error(const FrostFullscreenFailure(FrostFullscreenFailureReason.disposed));
    final pending = _fullscreenRequest;
    if (pending != null && pending.target == target) return pending.completer.future;
    if (pending != null) _finishFullscreen(pending, const FrostFullscreenFailure(FrostFullscreenFailureReason.superseded), notify: false);
    final request = _FullscreenRequest(target);
    _fullscreenRequest = request;
    _fullscreenFailure = null;
    unawaited(_requestFullscreen(request));
    notifyListeners();
    return request.completer.future;
  }

  Future<void> _requestFullscreen(_FullscreenRequest request) async {
    try {
      await initialize();
      if (_disposed || _fullscreenRequest != request) return;
      if (!_state.fullscreenAvailable) {
        _finishFullscreen(request, const FrostFullscreenFailure(FrostFullscreenFailureReason.unavailable));
        return;
      }
      // Always send the target, including false while entry is still pending.
      // Native hosts serialize asynchronous transitions to their latest target.
      request.timer = Timer(fullscreenTimeout, () {
        if (_fullscreenRequest != request) return;
        if (request.target) {
          unawaited(channel.invokeMethod<void>('setFullscreen', false).catchError((Object _) {}));
        }
        _finishFullscreen(request, const FrostFullscreenFailure(FrostFullscreenFailureReason.timeout));
      });
      final result = await channel.invokeMethod<Object?>('setFullscreen', request.target);
      if (_disposed || _fullscreenRequest != request) return;
      request.acknowledged = true;
      if (result is Map) _acceptState(Map<Object?, Object?>.from(result));
      if (_fullscreenRequest != request) return;
      if (!_state.fullscreenTransitioning && _state.fullscreen == request.target) {
        _finishFullscreen(request, null);
      }
    } on MissingPluginException {
      if (_fullscreenRequest == request) _finishFullscreen(request, const FrostFullscreenFailure(FrostFullscreenFailureReason.unavailable));
    } on PlatformException catch (error) {
      if (_fullscreenRequest == request) {
        _finishFullscreen(
          request,
          FrostFullscreenFailure(error.code == 'fullscreen_unavailable' ? FrostFullscreenFailureReason.unavailable : FrostFullscreenFailureReason.rejected),
        );
      }
    } on FrostWindowFailure {
      if (_fullscreenRequest == request) _finishFullscreen(request, const FrostFullscreenFailure(FrostFullscreenFailureReason.rejected));
    }
  }

  void _finishFullscreen(_FullscreenRequest request, FrostFullscreenFailure? failure, {bool notify = true}) {
    if (_fullscreenRequest != request) return;
    _fullscreenRequest = null;
    request.timer?.cancel();
    _fullscreenFailure = failure;
    if (failure == null) {
      request.completer.complete();
    } else {
      // Replacing or disposing a request is not a failure of the window; the
      // error stays observable to callers that wait, but an ignored request
      // must not surface as an unhandled error.
      if (failure.reason == FrostFullscreenFailureReason.superseded || failure.reason == FrostFullscreenFailureReason.disposed) {
        request.completer.future.ignore();
      }
      request.completer.completeError(failure);
    }
    if (!_disposed && notify) notifyListeners();
  }

  Future<void> minimize() => _invoke<void>('minimize');

  void _queueGeometry(FrostWindowGeometry value) {
    if (value == _pendingGeometry) return;
    _pendingGeometry = value;
    _geometryTimer?.cancel();
    _geometryTimer = Timer(geometryDebounce, () {
      if (!_disposed) _geometry.value = _pendingGeometry;
    });
  }

  Future<FrostWindowEnvironment> queryEnvironment() async {
    await initialize();
    final map = await _invoke<Map<Object?, Object?>>('getEnvironment');
    if (map == null) throw const FrostWindowFailure();
    return FrostWindowEnvironment.fromMap(map);
  }

  Future<FrostWindowGeometry> queryGeometry() async {
    await initialize();
    final map = await _invoke<Map<Object?, Object?>>('getState');
    if (map == null || map['geometry'] is! Map) throw const FrostWindowFailure();
    _acceptState(map);
    return _state.geometry ?? (throw const FrostWindowFailure());
  }

  /// Call before runApp with a hidden native runner. Saved data comes from the
  /// App; this method never reads files or preferences, including on failure.
  Future<FrostWindowPlacementResult> prepare({FrostWindowPlacement? saved, FrostWindowSizing? sizing, String? displayId, bool useCursor = false}) async {
    final environment = await queryEnvironment();
    final requested = sizing ?? FrostWindowSizing(minimumSize: minimumSize);
    // A first-placement floor can be larger than the interactive minimum, but
    // must never bypass the controller's existing native minimum contract.
    final policy = FrostWindowSizing(
      preferredSize: requested.preferredSize,
      aspectRatio: requested.aspectRatio,
      maxWorkAreaFraction: requested.maxWorkAreaFraction,
      minimumSize: Size(
        requested.minimumSize.width < minimumSize.width ? minimumSize.width : requested.minimumSize.width,
        requested.minimumSize.height < minimumSize.height ? minimumSize.height : requested.minimumSize.height,
      ),
    );
    final result = validateFrostWindow(saved, environment, sizing: policy, displayId: displayId, useCursor: useCursor);
    await applyPlacement(result.placement);
    return result;
  }

  /// Apply normal bounds and a maximize target. If hidden, stay hidden until
  /// show(); visible windows apply immediately. Native state remains actual.
  Future<void> applyPlacement(FrostWindowPlacement placement) async {
    await initialize();
    await _invoke<void>('applyPlacement', placement.toMap());
  }

  /// The App calls this after its first correctly sized frame is rasterized.
  /// Existing runners that show on first frame must opt into hidden startup.
  Future<void> show() => _invoke<void>('show');
  Future<void> toggleMaximized() => _invoke<void>('toggleMaximized');
  Future<void> close() => _invoke<void>('close');

  /// Windows-only keyboard/programmatic menu. Linux opens its compositor menu
  /// from the original native right-click event; macOS has no window menu.
  Future<void> showSystemMenu() => _invoke<void>('showSystemMenu');

  /// Logical-pixel rectangles (left, top, right, bottom, kind) where kind is
  /// caption (drag/system menu), maximize (Snap Layouts), or client (interactive
  /// exclusions taking precedence over caption/maximize rectangles).
  Future<void> setRegions(List<List<Object>> regions) => _invoke<void>('setRegions', regions);

  /// Sets the Windows top resize strip or Linux edge strips, in logical pixels.
  /// AppKit owns macOS resize edges independently of this setting.
  Future<void> setResizeBorder(double width) => _invoke<void>('setResizeBorder', width);

  /// Native window title (taskbar, Alt+Tab) and dark-mode window chrome.
  Future<void> setToolbar({required String title, required bool dark}) => _invoke<void>('setToolbar', {'title': title, 'dark': dark});

  /// Unsupported systems and disabled transparency return inactive normally.
  Future<void> setBackdrop(FrostWindowBackdrop backdrop, {required bool reduceTransparency}) =>
      _invoke<void>('setBackdrop', {'backdrop': backdrop.name, 'reduceTransparency': reduceTransparency});

  /// Puts an image on the clipboard as a 32-bit sRGB BITMAPV5 [dib] plus the
  /// same image as [png]. Both must describe the same size.
  Future<void> copyImage({required Uint8List dib, required Uint8List png}) => _invoke<void>('copyImage', {'dib': dib, 'png': png});

  /// A failed command fails only that command. The controller is marked failed
  /// when startup ([bootstrap]) fails or the native channel or window is gone.
  Future<T?> _invoke<T>(String method, [Object? arguments, bool bootstrap = false]) async {
    if (_disposed) return null;
    try {
      return await channel.invokeMethod<T>(method, arguments);
    } on PlatformException catch (error) {
      final code = switch (error.code) {
        'window_unavailable' || 'invalid_arguments' || 'clipboard_unavailable' => error.code,
        _ => 'platform_error',
      };
      if (bootstrap || code == 'window_unavailable') {
        _recordFailure(method, code, error.details);
      } else {
        _logDiagnostic(method, code, error.details);
      }
      throw const FrostWindowFailure();
    } on MissingPluginException {
      _recordFailure(method, 'missing_plugin');
      throw const FrostWindowFailure();
    }
  }

  void _recordFailure(String method, String code, [Object? details]) {
    if (_disposed) return;
    _failed = true;
    _initialized = false;
    _failureMethod = method;
    _failureCode = code;
    _logDiagnostic(method, code, details);
    notifyListeners();
  }

  void _logDiagnostic(String method, String code, [Object? details]) {
    final writer = diagnosticWriter;
    if (writer == null) return;
    _diagnosticTask = _diagnosticTask.then((_) async {
      var metadata = details;
      if (metadata is! Map) {
        try {
          metadata = await channel.invokeMethod<Object?>('getDiagnostics').timeout(const Duration(seconds: 1));
        } catch (_) {
          metadata = null;
        }
      }
      final safe = <String, Object?>{'method': method, 'code': code};
      if (metadata is Map) {
        if (metadata['ready'] case final bool ready) safe['ready'] = ready;
        if (metadata['win32Error'] case final int error) safe['win32Error'] = error;
        if (metadata['step'] case final String step
            when const ['not_attached', 'content_subclass', 'window_subclass', 'window_style', 'frame_change', 'ready'].contains(step)) {
          safe['step'] = step;
        }
      }
      try {
        await writer(safe);
      } catch (_) {
        // Diagnostics never change the window's success or failure.
      }
    });
  }

  @override
  void dispose() {
    // Clear an owned pending/actual fullscreen target before dropping the
    // channel handler. This also supersedes AppKit's queued entry target.
    if (_fullscreenRequest != null || _state.fullscreen) {
      unawaited(channel.invokeMethod<void>('setFullscreen', false).catchError((Object _) {}));
    }
    _disposed = true;
    _geometryTimer?.cancel();
    _geometry.dispose();
    final request = _fullscreenRequest;
    if (request != null) _finishFullscreen(request, const FrostFullscreenFailure(FrostFullscreenFailureReason.disposed));
    channel.setMethodCallHandler(null);
    _backRequests.dispose();
    super.dispose();
  }
}

class _FullscreenRequest {
  _FullscreenRequest(this.target);
  final bool target;
  final completer = Completer<void>();
  bool acknowledged = false;
  Timer? timer;
}
