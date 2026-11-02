import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../feedback/error_content.dart';
import '../foundation/density.dart';
import '../foundation/metrics.dart';
import '../foundation/radius.dart';
import '../foundation/scope.dart';
import '../foundation/sizes.dart';
import '../foundation/spacing.dart';
import '../foundation/tokens.dart';
import '../foundation/typography.dart';
import '../motion/_material_reveal.dart';
import '../motion/_spring_simulation.dart';
import '../motion/layout_crossfade.dart';
import '../motion/spring.dart';
import '../overlays/dialogs.dart';
import '../primitives/_inline_or_below.dart';
import '../primitives/icon.dart';
import '../primitives/status_glyph.dart';
import '../primitives/surface.dart';
import '../primitives/text.dart';
import '_toast_viewport.dart';
import 'buttons.dart';

enum FrostToastKind { success, info, warning, error }

/// In-app notices for the result of a user action.
///
/// Touch platforms queue one capsule above bottom navigation. It can be swiped
/// up to dismiss or held to keep it. Desktop shows surface cards in the
/// content area's bottom-right corner: newer
/// cards stack in front with older ones peeking behind, and hovering spreads
/// the stack into a list and holds every timer.
///
/// Notices render in [FrostToastHost], inside the app's theme and locale.
class FrostToast {
  FrostToast._();

  /// A successful result, with optional supporting detail and one event action.
  /// Actions dismiss their own notice and run at most once on every platform.
  static void success(String message, {String? description, String? actionLabel, VoidCallback? onAction}) {
    assert((actionLabel == null) == (onAction == null));
    _show(FrostToastKind.success, message, const Duration(seconds: 3), description: description, actionLabel: actionLabel, onAction: onAction);
  }

  /// Whether the system already confirms clipboard writes (Android 13+), in
  /// which case [copied] stays silent so one copy shows one notice. The app
  /// sets this from its platform information; by default nothing is skipped.
  static Future<bool> Function() systemConfirmsClipboardCopies = () async => false;

  /// The result of a successful copy.
  static void copied(String message) {
    unawaited(
      systemConfirmsClipboardCopies().then((confirmed) {
        if (!confirmed) success(message);
      }),
    );
  }

  /// A failed result. Supporting detail uses secondary ink; the optional action
  /// should retry the specific operation that produced this notice.
  static void error(String message, {String? description, String? actionLabel, VoidCallback? onAction}) {
    assert((actionLabel == null) == (onAction == null));
    _show(FrostToastKind.error, message, const Duration(seconds: 5), description: description, actionLabel: actionLabel, onAction: onAction);
  }

  /// Presents an operation failure through the app's shared error mapping.
  /// Technical details stay out of the notice and are copied from a dialog.
  /// An optional existing action (for example retry) remains available beside
  /// the detail affordance; plain string notices keep their existing API.
  static void fromError(BuildContext context, Object error, {String? description, String? actionLabel, VoidCallback? onAction}) {
    assert((actionLabel == null) == (onAction == null));
    final presenter = FrostScope.errorsOf(context);
    final message = presenter.message(context, error);
    final details = presenter.details(error);
    final hasDetails = details != null && details.trim().isNotEmpty;
    final navigator = hasDetails ? Navigator.of(context, rootNavigator: true) : null;
    final label = FrostScope.labelsOf(context).errorDetails;
    final title = presenter.title?.call(context, error) ?? FrostScope.labelsOf(context).error;
    void openDetails() {
      if (navigator == null || !navigator.mounted) return;
      unawaited(
        showFrostDialog<void>(
          context: navigator.context,
          builder: (context) => FrostDialog(
            title: title,
            showsCloseButton: true,
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FrostText(message),
                const SizedBox(height: FrostGap.related),
                FrostErrorDetails(details: details!, initiallyExpanded: true),
              ],
            ),
          ),
        ),
      );
    }

    _show(
      FrostToastKind.error,
      message,
      const Duration(seconds: 5),
      description: description,
      actionLabel: actionLabel ?? (hasDetails ? label : null),
      onAction: onAction ?? (hasDetails ? openDetails : null),
      detailsLabel: hasDetails && onAction != null ? label : null,
      onDetails: hasDetails && onAction != null ? openDetails : null,
    );
  }

  static void info(String message) => _show(FrostToastKind.info, message, const Duration(seconds: 3));

  /// An info notice with one action, such as undo. It stays a little longer;
  /// the action runs at most once and dismisses the notice.
  static void actionableInfo(String message, {required String actionLabel, required VoidCallback onAction}) =>
      _show(FrostToastKind.info, message, const Duration(seconds: 5), actionLabel: actionLabel, onAction: onAction);

  static void warning(String message) => _show(FrostToastKind.warning, message, const Duration(seconds: 4));

  /// Dismisses every notice, the same way each card's close button does.
  /// [FrostToastHost] calls this for an Esc that nothing else handled.
  static void dismissAll() => FrostToastHost._key.currentState?._dismissAll();

  static _AppToastHostState? get _host {
    final host = FrostToastHost._key.currentState;
    if (host == null) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: FlutterError('FrostToast has no FrostToastHost to show in: build the app with FrostApp.router or place a FrostToastHost above it.'),
          stack: StackTrace.current,
          library: 'frost_ui',
        ),
      );
    }
    return host;
  }

  static void _show(
    FrostToastKind kind,
    String message,
    Duration duration, {
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
    String? detailsLabel,
    VoidCallback? onDetails,
  }) => _host?._show(
    kind,
    message,
    duration,
    description: description,
    actionLabel: actionLabel,
    onAction: onAction,
    detailsLabel: detailsLabel,
    onDetails: onDetails,
  );
}

/// Hosts the notices above [child] (the app's pages). Install once, inside
/// the app's theme and localizations.
class FrostToastHost extends StatefulWidget {
  FrostToastHost({required this.child}) : super(key: _key);

  static final _key = GlobalKey<_AppToastHostState>();

  final Widget child;

  @override
  State<FrostToastHost> createState() => _AppToastHostState();
}

class _Notice {
  _Notice({required this.id, required this.kind, required this.message, required this.duration, this.description, this.actionLabel, this.detailsLabel});

  final int id;
  final FrostToastKind kind;
  final String message;
  final String? description;
  final Duration duration;
  final String? actionLabel;
  final String? detailsLabel;
  VoidCallback? action;
  VoidCallback? detailsAction;
  bool leaving = false;

  /// How many identical passive notices this card or capsule represents.
  int count = 1;
  _NoticeTimer? timer;
}

/// A pausable countdown.
class _NoticeTimer {
  _NoticeTimer(this._remaining, this._onDone) {
    resume();
  }

  Duration _remaining;
  final VoidCallback _onDone;
  Timer? _timer;
  final Stopwatch _running = Stopwatch();

  void pause() {
    if (_timer == null) return;
    _timer!.cancel();
    _timer = null;
    _running.stop();
    _remaining -= _running.elapsed;
    _running.reset();
  }

  void resume() {
    if (_timer != null) return;
    _running
      ..reset()
      ..start();
    _timer = Timer(_remaining.isNegative ? Duration.zero : _remaining, _onDone);
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}

class _AppToastHostState extends State<FrostToastHost> {
  final List<_Notice> _notices = [];
  final List<_Notice> _pending = [];
  final _viewports = FrostToastViewportRegistry();
  bool _held = false;
  int _nextId = 0;

  /// Most desktop cards shown at once; overflow waits without starting timers.
  static const _maxCards = 5;

  bool get _touch => _viewports.owner?.touch ?? !FrostDensity.of(context).usesPointer;

  void _show(
    FrostToastKind kind,
    String message,
    Duration duration, {
    String? description,
    String? actionLabel,
    VoidCallback? onAction,
    String? detailsLabel,
    VoidCallback? onDetails,
  }) {
    // Each action belongs to one event. Merge passive duplicates, including
    // queued ones, while retaining every distinct event/action in FIFO order.
    final same = onAction != null || onDetails != null
        ? null
        : [..._notices, ..._pending]
              .where(
                (old) =>
                    !old.leaving &&
                    old.action == null &&
                    old.detailsAction == null &&
                    old.kind == kind &&
                    old.message == message &&
                    old.description == description,
              )
              .lastOrNull;
    if (same != null) {
      setState(() => same.count++);
      if (_notices.contains(same)) _startTimer(same);
      return;
    }
    final notice = _Notice(
      id: _nextId++,
      kind: kind,
      message: message,
      duration: onAction != null || onDetails != null ? const Duration(seconds: 5) : duration,
      description: description,
      actionLabel: actionLabel,
      detailsLabel: detailsLabel,
    );
    if (onAction != null) {
      notice.action = () {
        if (notice.leaving) return;
        notice.action = null;
        _dismiss(notice);
        onAction();
      };
    }
    if (onDetails != null) {
      notice.detailsAction = () {
        if (notice.leaving) return;
        notice.detailsAction = null;
        _dismiss(notice);
        onDetails();
      };
    }
    setState(() {
      if (_notices.length < (_touch ? 1 : _maxCards)) {
        _notices.add(notice);
        _startTimer(notice);
      } else {
        _pending.add(notice);
      }
    });
  }

  void _startTimer(_Notice notice) {
    notice.timer?.cancel();
    final accessible = (_viewports.owner?.media ?? MediaQuery.of(context)).accessibleNavigation;
    if (accessible && (notice.action != null || notice.detailsAction != null)) return;
    final duration = accessible && notice.duration < const Duration(seconds: 5) ? const Duration(seconds: 5) : notice.duration;
    notice.timer = _NoticeTimer(duration, () => _dismiss(notice));
    if (_held) notice.timer!.pause();
  }

  void _leave(_Notice notice) {
    notice.timer?.cancel();
    notice.leaving = true;
  }

  void _dismiss(_Notice notice) {
    if (!mounted || notice.leaving) return;
    setState(() => _leave(notice));
  }

  void _dismissAll() {
    if (!mounted) return;
    setState(() {
      _pending.clear();
      _notices.forEach(_leave);
    });
  }

  void _removed(_Notice notice) {
    if (!mounted) return;
    setState(() {
      _notices.remove(notice);
      while (_pending.isNotEmpty && _notices.length < (_touch ? 1 : _maxCards)) {
        final next = _pending.removeAt(0);
        _notices.add(next);
        _startTimer(next);
      }
    });
  }

  void _pauseAll() {
    _held = true;
    for (final notice in _notices) {
      notice.timer?.pause();
    }
  }

  void _resumeAll() {
    _held = false;
    for (final notice in _notices) {
      if (!notice.leaving) notice.timer?.resume();
    }
  }

  @override
  void dispose() {
    for (final notice in _notices) {
      notice.timer?.cancel();
    }
    _viewports.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FrostToastViewportScope(
    registry: _viewports,
    child: AnimatedBuilder(
      animation: _viewports,
      // An Esc that nothing focused handled bubbles up to here, after dialogs,
      // menus and search have had their turn.
      builder: (context, _) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (node, event) {
          if (event is! KeyDownEvent || event.logicalKey != LogicalKeyboardKey.escape) return KeyEventResult.ignored;
          if (!_notices.any((notice) => !notice.leaving)) return KeyEventResult.ignored;
          _dismissAll();
          return KeyEventResult.handled;
        },
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            widget.child,
            if (_notices.isNotEmpty) Positioned.fill(child: LayoutBuilder(builder: _layer)),
          ],
        ),
      ),
    ),
  );

  Widget _layer(BuildContext context, BoxConstraints constraints) {
    final owner = _viewports.owner;
    final host = this.context.findRenderObject();
    if (owner != null && host is RenderBox && !host.hasSize) {
      // A notice from before the first layout: the viewport can be measured
      // against the host from the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
      return const SizedBox.shrink();
    }
    final box = owner?.context.findRenderObject();
    final measured = box is RenderBox && box.hasSize && host is RenderBox
        ? Rect.fromPoints(host.globalToLocal(box.localToGlobal(Offset.zero)), host.globalToLocal(box.localToGlobal(box.size.bottomRight(Offset.zero))))
        : Offset.zero & constraints.biggest;
    final rect = owner?.bounds != null && host is RenderBox ? measured.intersect(owner!.bounds!.inOverlay(host)) : measured;
    final size = box is RenderBox && box.hasSize ? box.size : rect.size;
    if (size.isEmpty || rect.isEmpty) return const SizedBox.shrink();
    final sourceMedia = owner?.media ?? MediaQuery.of(context);
    final media = sourceMedia.copyWith(size: size, padding: owner == null ? sourceMedia.padding : EdgeInsets.zero);
    final layer = MediaQuery(
      data: media,
      child: Overlay.wrap(
        child: _touch
            ? _CapsuleLayer(notice: _notices.first, onDismiss: _dismiss, onRemoved: _removed, onHold: _pauseAll, onRelease: _resumeAll)
            : _CardStackLayer(notices: List.of(_notices), onDismiss: _dismiss, onRemoved: _removed, onHold: _pauseAll, onRelease: _resumeAll),
      ),
    );
    final themed = owner == null ? layer : InheritedTheme.capture(from: owner.context, to: this.context).wrap(layer);
    return Stack(
      children: [
        Positioned.fromRect(
          rect: rect,
          child: ClipRect(
            child: FittedBox(
              fit: BoxFit.fill,
              alignment: Alignment.topLeft,
              child: SizedBox.fromSize(size: size, child: themed),
            ),
          ),
        ),
      ],
    );
  }
}

Color _toastInk(FrostThemeTokens tokens, FrostToastKind kind) => switch (kind) {
  FrostToastKind.success => tokens.positiveInk,
  FrostToastKind.info => tokens.infoInk,
  FrostToastKind.warning => tokens.cautionInk,
  FrostToastKind.error => tokens.negativeInk,
};

class _ToastGlyphReveal extends InheritedWidget {
  const _ToastGlyphReveal({required this.ready, required super.child});
  final bool ready;
  static bool readyOf(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_ToastGlyphReveal>()?.ready ?? true;
  @override
  bool updateShouldNotify(_ToastGlyphReveal oldWidget) => ready != oldWidget.ready;
}

// ---------------------------------------------------------------------------
// Touch: the capsule.

class _CapsuleLayer extends StatefulWidget {
  const _CapsuleLayer({required this.notice, required this.onDismiss, required this.onRemoved, required this.onHold, required this.onRelease});

  final _Notice notice;
  final ValueChanged<_Notice> onDismiss;
  final ValueChanged<_Notice> onRemoved;
  final VoidCallback onHold;
  final VoidCallback onRelease;

  @override
  State<_CapsuleLayer> createState() => _CapsuleLayerState();
}

class _CapsuleLayerState extends State<_CapsuleLayer> with TickerProviderStateMixin {
  /// 0 hidden below, 1 in place.
  late final AnimationController _presence = AnimationController.unbounded(vsync: this);

  /// Upward drag while the finger is down; springs back or away on release.
  late final AnimationController _drag = AnimationController.unbounded(vsync: this);

  /// A swipe needs this much upward travel or speed to dismiss.
  static const _dismissDistance = 24.0;
  static const _dismissVelocity = 400.0;

  @override
  void initState() {
    super.initState();
    _enter();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _presence.value = widget.notice.leaving ? 0 : 1;
      _drag.value = 0;
    }
  }

  @override
  void didUpdateWidget(_CapsuleLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notice.leaving) {
      _exit();
    } else if (widget.notice != oldWidget.notice) {
      // A new notice while one is showing morphs the same capsule; it only
      // drops in again if the old one was already on its way out.
      _drag.value = 0;
      _enter();
    }
  }

  void _enter() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.notice.leaving) FrostMotion.springTo(context, _presence, 1, FrostMotion.standard);
    });
  }

  Future<void> _exit() async {
    final notice = widget.notice;
    await FrostMotion.springTo(context, _presence, 0, FrostMotion.snappy).orCancel.catchError((_) {});
    if (mounted && widget.notice == notice && notice.leaving) widget.onRemoved(notice);
  }

  void _dragUpdate(DragUpdateDetails details) {
    final next = _drag.value + details.delta.dy;
    // Upward follows the finger; downward resists.
    _drag.value = next < 0 ? next : next * .25;
  }

  void _dragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_drag.value < -_dismissDistance || velocity < -_dismissVelocity) {
      widget.onDismiss(widget.notice);
    } else {
      if (MediaQuery.disableAnimationsOf(context)) {
        _drag.value = 0;
      } else {
        _drag.animateWith(frostSpringSimulation(FrostMotion.snappy, _drag.value, 0, velocity));
      }
    }
    widget.onRelease();
  }

  @override
  void dispose() {
    _presence.dispose();
    _drag.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final width = math.min(480.0, media.size.width - 32);
    final notice = widget.notice;
    final capsule = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) => widget.onHold(),
      onVerticalDragUpdate: _dragUpdate,
      onVerticalDragEnd: _dragEnd,
      onLongPressStart: (_) => widget.onHold(),
      onLongPressEnd: (_) => widget.onRelease(),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: width, minHeight: 44),
        child: _ToastSurface(
          borderRadius: FrostRadius.borderRadius(FrostRadius.full(44)),
          child: FrostMotionSize(
            // Reuse the shared reduced-motion bypass: zero-duration
            // AnimatedSize can re-dirty itself while measuring a live capsule.
            duration: FrostMotion.standardDuration,
            curve: FrostSpringCurve(FrostMotion.standard, FrostMotion.standardDuration),
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: FrostMotion.duration(context, FrostMotion.hover),
              layoutBuilder: (current, previous) => Stack(alignment: Alignment.center, children: [...previous, ?current]),
              child: _CapsuleContent(key: ValueKey(notice.id), notice: notice, onDismiss: () => widget.onDismiss(notice)),
            ),
          ),
        ),
      ),
    );
    return Positioned(
      bottom: media.padding.bottom + media.viewInsets.bottom + 16,
      left: 16,
      right: 16,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AnimatedBuilder(
          animation: Listenable.merge([_presence, _drag]),
          builder: (context, child) {
            final presence = _presence.value;
            return Transform.translate(
              offset: Offset(0, 24 * (1 - presence).clamp(0.0, 1.0) + _drag.value),
              child: Transform.scale(
                scale: MediaQuery.disableAnimationsOf(context) ? 1 : .9 + .1 * presence,
                alignment: Alignment.topCenter,
                child: FrostMaterialReveal(
                  opacity: presence.clamp(0.0, 1.0),
                  child: _ToastGlyphReveal(ready: presence >= 1 && !notice.leaving, child: child!),
                ),
              ),
            );
          },
          child: capsule,
        ),
      ),
    );
  }
}

// Shared content keeps title/detail typography and semantics identical in the
// desktop stack and touch capsule; material, timers and input remain shared.
class _NoticeText extends StatelessWidget {
  const _NoticeText({required this.notice});
  final _Notice notice;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      FrostText(
        notice.count > 1 ? '${notice.message}  ×${notice.count}' : notice.message,
        role: FrostTextRole.callout,
        maxLines: 5,
        overflow: TextOverflow.ellipsis,
      ),
      if (notice.description case final detail?) ...[
        const SizedBox(height: FrostGap.inline),
        FrostText(detail, role: FrostTextRole.footnote, tone: FrostTextTone.secondary),
      ],
      if (notice.detailsLabel case final label?)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FrostButton.icon(label: label, icon: FrostIconSet.of(context).info, onPressed: notice.detailsAction, size: FrostControlSize.compact),
        ),
    ],
  );
}

// Measure the complete text and action, independent of the notice kind. Keep
// them on one line when they fit; otherwise give text the full width and align
// the visible action surface with that same leading keyline below it.
class _NoticeBody extends StatelessWidget {
  const _NoticeBody({required this.notice});
  final _Notice notice;
  @override
  Widget build(BuildContext context) => FrostInlineOrBelow(
    direction: Directionality.of(context),
    gap: FrostGap.inline,
    shrinkWraps: true,
    belowAtStart: true,
    start: _NoticeText(notice: notice),
    end: switch (notice.actionLabel) {
      final label? => FrostButton(label: label, onPressed: notice.action, size: FrostControlSize.compact),
      null => const SizedBox.shrink(),
    },
  );
}

class _CapsuleContent extends StatelessWidget {
  const _CapsuleContent({required this.notice, required this.onDismiss, super.key});

  final _Notice notice;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      onDismiss: onDismiss,
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(
          FrostGap.of(context).group,
          FrostGap.of(context).group,
          FrostGap.of(context).rowInset,
          FrostGap.of(context).group,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ToastGlyph(kind: notice.kind),
            const SizedBox(width: FrostGap.related),
            Flexible(child: _NoticeBody(notice: notice)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop: the stacked cards.

class _CardStackLayer extends StatefulWidget {
  const _CardStackLayer({required this.notices, required this.onDismiss, required this.onRemoved, required this.onHold, required this.onRelease});

  /// Oldest first; the newest is painted on top.
  final List<_Notice> notices;
  final ValueChanged<_Notice> onDismiss;
  final ValueChanged<_Notice> onRemoved;
  final VoidCallback onHold;
  final VoidCallback onRelease;

  @override
  State<_CardStackLayer> createState() => _CardStackLayerState();
}

class _CardStackLayerState extends State<_CardStackLayer> {
  static const _width = 360.0;
  static const _gap = 8.0;

  /// How far each older card peeks out below the one in front.
  static const _peek = 8.0;
  static const _visibleBehind = 2;

  final Map<int, double> _heights = {};
  bool _expanded = false;
  int _hovered = 0;
  Timer? _collapse;

  void _enter() {
    _hovered++;
    _collapse?.cancel();
    if (!_expanded) {
      setState(() => _expanded = true);
      widget.onHold();
    }
  }

  void _exit() {
    _hovered = math.max(0, _hovered - 1);
    if (_hovered > 0) return;
    // Moving between spread cards crosses their gaps; wait before folding.
    _collapse?.cancel();
    _collapse = Timer(const Duration(milliseconds: 120), () {
      if (!mounted || _hovered > 0) return;
      setState(() => _expanded = false);
      widget.onRelease();
    });
  }

  void _measured(_Notice notice, Size size) {
    if (_heights[notice.id] == size.height) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _heights[notice.id] = size.height);
    });
  }

  @override
  void dispose() {
    _collapse?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final active = widget.notices.where((notice) => !notice.leaving).toList().reversed.toList();
    // Front-to-back position of each card; leaving cards keep their last slot.
    final depth = {for (final (index, notice) in active.indexed) notice.id: index};
    var lift = 0.0;
    final lifts = <int, double>{};
    for (final notice in active) {
      lifts[notice.id] = lift;
      lift += (_heights[notice.id] ?? 72) + _gap;
    }
    final bottom = 16 + _peek * _visibleBehind + padding.bottom + MediaQuery.viewInsetsOf(context).bottom;
    return LayoutBuilder(
      builder: (context, constraints) => _CardsOnlyHitTest(
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(scrollbars: false),
          child: SingleChildScrollView(
            primary: false,
            reverse: true,
            child: SizedBox(
              height: _expanded ? math.max(constraints.maxHeight, lift + bottom) : constraints.maxHeight,
              child: Stack(
                children: [
                  for (final notice in widget.notices)
                    Positioned(
                      key: ValueKey(notice.id),
                      right: 16 + padding.right,
                      bottom: bottom,
                      width: math.max(0, math.min(_width, constraints.maxWidth - 32 - padding.horizontal)),
                      child: _StackedCard(
                        notice: notice,
                        depth: depth[notice.id] ?? 0,
                        lift: _expanded ? lifts[notice.id] ?? 0 : 0,
                        expanded: _expanded,
                        visibleBehind: _visibleBehind,
                        peek: _peek,
                        onSize: (size) => _measured(notice, size),
                        onClose: () => widget.onDismiss(notice),
                        onRemoved: () {
                          _heights.remove(notice.id);
                          widget.onRemoved(notice);
                        },
                        onEnter: _enter,
                        onExit: _exit,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lets pointer events through everywhere except on a card. The full-size
/// scroll view behind the cards would otherwise absorb every tap, hover and
/// wheel event over the page.
class _CardsOnlyHitTest extends SingleChildRenderObjectWidget {
  const _CardsOnlyHitTest({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCardsOnlyHitTest();
}

class _RenderCardsOnlyHitTest extends RenderProxyBox {
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final scratch = BoxHitTestResult();
    if (!super.hitTest(scratch, position: position)) return false;
    if (!scratch.path.any((entry) => entry.target is _RenderCardMarker)) return false;
    return super.hitTest(result, position: position);
  }
}

/// Marks the area of one card, so [_RenderCardsOnlyHitTest] can tell it from
/// the empty scroll view around the cards.
class _CardMarker extends SingleChildRenderObjectWidget {
  const _CardMarker({required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCardMarker();
}

class _RenderCardMarker extends RenderProxyBox {
  @override
  bool hitTestSelf(Offset position) => true;
}

class _StackedCard extends StatefulWidget {
  const _StackedCard({
    required this.notice,
    required this.depth,
    required this.lift,
    required this.expanded,
    required this.visibleBehind,
    required this.peek,
    required this.onSize,
    required this.onClose,
    required this.onRemoved,
    required this.onEnter,
    required this.onExit,
  });

  final _Notice notice;

  /// 0 for the front card, 1 behind it, and so on.
  final int depth;

  /// Upward offset while the stack is spread into a list.
  final double lift;
  final bool expanded;
  final int visibleBehind;
  final double peek;
  final ValueChanged<Size> onSize;
  final VoidCallback onClose;
  final VoidCallback onRemoved;
  final VoidCallback onEnter;
  final VoidCallback onExit;

  @override
  State<_StackedCard> createState() => _StackedCardState();
}

class _StackedCardState extends State<_StackedCard> with SingleTickerProviderStateMixin {
  /// 0 off to the right, 1 in place.
  late final AnimationController _presence = AnimationController.unbounded(vsync: this);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !widget.notice.leaving) FrostMotion.springTo(context, _presence, 1, FrostMotion.standard);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) _presence.value = widget.notice.leaving ? 0 : 1;
  }

  @override
  void didUpdateWidget(_StackedCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.notice.leaving && !_leaving) _leave();
  }

  bool _leaving = false;

  Future<void> _leave() async {
    _leaving = true;
    await FrostMotion.springTo(context, _presence, 0, FrostMotion.snappy).orCancel.catchError((_) {});
    if (mounted) widget.onRemoved();
  }

  @override
  void dispose() {
    _presence.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final depth = widget.depth.toDouble();
    final hidden = !widget.expanded && widget.depth > widget.visibleBehind;
    // Collapsed: older cards shrink and peek out below the front one.
    // Spread: every card at full size, stacked upward.
    final offset = widget.expanded ? -widget.lift : math.min(depth, widget.visibleBehind + 1.0) * widget.peek;
    final scale = widget.expanded ? 1.0 : 1 - .05 * math.min(depth, widget.visibleBehind + 1.0);
    final dim = widget.expanded ? 0.0 : .18 * math.min(depth, widget.visibleBehind.toDouble());
    return IgnorePointer(
      ignoring: hidden || widget.notice.leaving,
      child: FrostSpringBuilder(
        value: offset,
        spring: FrostMotion.standard,
        builder: (context, offset, child) => FrostSpringBuilder(
          value: scale,
          spring: FrostMotion.standard,
          builder: (context, scale, child) => AnimatedBuilder(
            animation: _presence,
            builder: (context, child) {
              final presence = _presence.value.clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(48 * (1 - presence), offset),
                child: Transform.scale(
                  scale: scale * (MediaQuery.disableAnimationsOf(context) ? 1 : .96 + .04 * presence),
                  alignment: Alignment.topCenter,
                  child: FrostMaterialReveal(
                    opacity: hidden ? 0 : presence,
                    child: _ToastGlyphReveal(ready: presence >= 1 && !widget.notice.leaving, child: child!),
                  ),
                ),
              );
            },
            child: child,
          ),
          child: child,
        ),
        child: _SizeReporter(
          onSize: widget.onSize,
          child: _CardMarker(
            child: Focus(
              skipTraversal: true,
              onFocusChange: (focused) => focused ? widget.onEnter() : widget.onExit(),
              child: MouseRegion(
                onEnter: (_) => widget.onEnter(),
                onExit: (_) => widget.onExit(),
                child: _CardContent(notice: widget.notice, dim: dim, onClose: widget.onClose),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardContent extends StatelessWidget {
  const _CardContent({required this.notice, required this.dim, required this.onClose});

  final _Notice notice;

  /// How much a card behind the front one is darkened, 0 for the front.
  final double dim;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return Semantics(
      liveRegion: true,
      child: _ToastSurface(
        borderRadius: FrostRadius.borderRadius(FrostRadius.xl),
        child: Stack(
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(FrostGap.of(context).group, FrostGap.related, FrostGap.inline, FrostGap.related),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: FrostGap.inline),
                    child: _ToastGlyph(kind: notice.kind),
                  ),
                  SizedBox(width: FrostGap.of(context).group),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: FrostGap.inline),
                      child: _NoticeBody(notice: notice),
                    ),
                  ),
                  const SizedBox(width: FrostGap.inline),
                  // Close remains an independent quiet target on the surface.
                  FrostButton.icon(
                    label: FrostScope.labelsOf(context).dismiss,
                    onPressed: onClose,
                    icon: FrostIconSet.of(context).close,
                    size: FrostControlSize.compact,
                  ),
                ],
              ),
            ),
            if (dim > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: tokens.canvas.withValues(alpha: dim)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Notifications must keep their neutral identity over saturated media. Reuse
// the shared opaque raised material (including its edge/shadows and plain ink)
// instead of weakening every overlay's glass or adding a caller-side scrim.
class _ToastSurface extends StatelessWidget {
  const _ToastSurface({required this.borderRadius, required this.child});
  final BorderRadiusGeometry borderRadius;
  final Widget child;
  @override
  Widget build(BuildContext context) => FrostScope(
    config: FrostScope.configOf(context),
    reduceTransparency: true,
    child: FrostSurface(role: FrostSurfaceRole.overlay, borderRadius: borderRadius, child: child),
  );
}

class _SizeReporter extends SingleChildRenderObjectWidget {
  const _SizeReporter({required this.onSize, required super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderSizeReporter(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderSizeReporter renderObject) => renderObject.onSize = onSize;
}

class _RenderSizeReporter extends RenderProxyBox {
  _RenderSizeReporter(this.onSize);

  ValueChanged<Size> onSize;

  @override
  void performLayout() {
    super.performLayout();
    onSize(size);
  }
}

// ---------------------------------------------------------------------------
// Status strokes begin only after the panel material has fully arrived.
class _ToastGlyph extends StatelessWidget {
  const _ToastGlyph({required this.kind});
  final FrostToastKind kind;
  @override
  Widget build(BuildContext context) {
    final color = _toastInk(FrostThemeTokens.of(context), kind);
    if (kind == FrostToastKind.info) return FrostIcon(FrostIconSet.of(context).info, size: 20, color: color);
    final status = switch (kind) {
      FrostToastKind.success => FrostStatusGlyphKind.success,
      FrostToastKind.error => FrostStatusGlyphKind.failure,
      FrostToastKind.warning => FrostStatusGlyphKind.warning,
      FrostToastKind.info => throw StateError('Info uses the app icon.'),
    };
    return FrostStatusGlyphAnimation(kind: status, size: 20, color: color, visible: _ToastGlyphReveal.readyOf(context), drawOnMount: true);
  }
}
