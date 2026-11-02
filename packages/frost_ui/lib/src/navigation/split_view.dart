import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../foundation/_focus_modality.dart';
import '../foundation/_layout_scope.dart';
import '../foundation/_touch_targets.dart';
import '../foundation/feedback.dart';
import '../foundation/metrics.dart';
import '../foundation/tokens.dart';
import '../primitives/divider.dart';
import '_shell_back_scope.dart';
import 'detail_page.dart';
import 'shell_navigation_scope.dart';

// Requested widths persist independently of temporary local constraints.
const _minimumPrimaryWidth = 240.0;
const _maximumPrimaryWidth = 480.0;
// Reserve the same minimum for the detail pane when local space permits.
const _minimumSecondaryWidth = _minimumPrimaryWidth;
const _resizeHitWidth = 8.0;
const _keyboardWidthStep = 16.0;

/// A persistent master/detail view: two panes when the view itself is wide
/// enough for them, page navigation when it is not.
///
/// Give the view a stable key to restore its requested primary width from
/// PageStorage. Both panes retain their State across size-class changes.
/// [onCloseSecondary] asks the owner to clear [secondary]; it never mutates it.
class FrostSplitView extends StatefulWidget {
  const FrostSplitView({
    required this.primary,
    required this.secondary,
    required this.onCloseSecondary,
    this.header,
    this.initialPrimaryWidth = 320,
    this.onPrimaryWidthChanged,
    this.resizable = true,
    super.key,
  }) : assert(initialPrimaryWidth > 0 && initialPrimaryWidth < double.infinity);

  final Widget primary;
  final Widget? secondary;

  /// Shared, fixed header above both panes. In compact mode it belongs to the
  /// primary page and is covered along with that page when detail opens.
  final Widget? header;
  final VoidCallback? onCloseSecondary;
  final double initialPrimaryWidth;

  /// Commits the requested width once after a drag, a keyboard adjustment, or
  /// an accessibility increment. The owner may persist it and supply it as
  /// [initialPrimaryWidth] on a later mount. PageStorage still takes precedence
  /// within the current session. Temporary window constraints do not commit.
  final ValueChanged<double>? onPrimaryWidthChanged;
  final bool resizable;

  @override
  State<FrostSplitView> createState() => _FrostSplitViewState();
}

class _FrostSplitViewState extends State<FrostSplitView> with SingleTickerProviderStateMixin {
  final _primaryKey = GlobalKey();
  final _headerKey = GlobalKey();
  final _secondaryKey = GlobalKey();
  final _navigatorKey = GlobalKey<NavigatorState>();
  final _reselection = ValueNotifier<({int index, int sequence})>((index: -1, sequence: 0));
  late double _requestedWidth = widget.initialPrimaryWidth.clamp(_minimumPrimaryWidth, _maximumPrimaryWidth);
  late final _width = AnimationController.unbounded(vsync: this, value: _requestedWidth);
  bool _restored = false;
  bool _closeRequested = false;
  late double _committedWidth = _requestedWidth;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restored) {
      _restored = true;
      final saved = widget.key == null ? null : PageStorage.maybeOf(context)?.readState(context, identifier: widget.key);
      if (saved is double && saved.isFinite) _requestedWidth = saved.clamp(_minimumPrimaryWidth, _maximumPrimaryWidth);
      _width.value = _requestedWidth;
      _committedWidth = _requestedWidth;
    }
    if (MediaQuery.disableAnimationsOf(context)) _width.value = _requestedWidth;
  }

  @override
  void didUpdateWidget(FrostSplitView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.secondary == null || widget.secondary != oldWidget.secondary) _closeRequested = false;
  }

  void _close() {
    if (widget.secondary == null || widget.onCloseSecondary == null || _closeRequested) return;
    _closeRequested = true;
    widget.onCloseSecondary!();
  }

  void _resize(double value, {bool animate = false}) {
    _requestedWidth = value.clamp(_minimumPrimaryWidth, _maximumPrimaryWidth);
    if (widget.key != null) PageStorage.maybeOf(context)?.writeState(context, _requestedWidth, identifier: widget.key);
    if (animate) {
      FrostMotion.springTo(context, _width, _requestedWidth, FrostMotion.standard);
    } else {
      _width.value = _requestedWidth;
    }
  }

  void _commitResize() {
    if (_committedWidth == _requestedWidth) return;
    _committedWidth = _requestedWidth;
    widget.onPrimaryWidthChanged?.call(_requestedWidth);
  }

  @override
  void dispose() {
    _width.dispose();
    _reselection.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, constraints) => _build(context, constraints.maxWidth < FrostSizeClass.medium.minimumWidth));

  Widget _build(BuildContext context, bool compact) {
    final outer = FrostShellNavigationScope.maybeOf(context);
    final hasDetail = compact && widget.secondary != null;
    return FrostShellBackTarget(
      enabled: hasDetail && widget.onCloseSecondary != null && (outer?.ownsBackControl ?? false),
      onBack: _close,
      child: _SplitEnvironment(
        compact: compact,
        header: widget.header == null ? null : KeyedSubtree(key: _headerKey, child: widget.header!),
        primary: KeyedSubtree(key: _primaryKey, child: widget.primary),
        secondary: widget.secondary == null ? null : KeyedSubtree(key: _secondaryKey, child: widget.secondary!),
        width: _width,
        requestedWidth: () => _requestedWidth,
        resize: _resize,
        commitResize: _commitResize,
        resizable: widget.resizable,
        close: widget.onCloseSecondary == null ? null : _close,
        reselection: outer?.primaryReselection ?? _reselection,
        child: Focus(
          canRequestFocus: false,
          skipTraversal: true,
          onKeyEvent: (_, event) {
            if (hasDetail && event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape && widget.onCloseSecondary != null) {
              _close();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Stack(
            fit: StackFit.expand,
            children: [
              Offstage(
                offstage: !compact,
                child: ExcludeFocus(
                  excluding: !compact,
                  child: NavigatorPopHandler<void>(
                    enabled: hasDetail,
                    onPopWithResult: (_) {
                      if (hasDetail) _close();
                    },
                    child: Navigator(
                      key: _navigatorKey,
                      pages: [
                        const FrostDetailPage<void>(key: ValueKey(_SplitRoot), child: _SplitRoot()),
                        if (hasDetail) const FrostDetailPage<void>(key: ValueKey(_SplitSecondary), child: _SplitSecondary()),
                      ],
                      onDidRemovePage: (page) {
                        if (hasDetail && page.key == const ValueKey(_SplitSecondary)) _close();
                      },
                    ),
                  ),
                ),
              ),
              // Desktop panes stay outside the route's focus scope. The retained
              // navigator is only active in compact mode; GlobalKeys move panes
              // between these hosts without destroying their State.
              if (!compact)
                Builder(
                  builder: (context) {
                    final view = _SplitEnvironment.of(context);
                    return view.withHeader(_WideSplit(view: view));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

typedef _Resize = void Function(double value, {bool animate});

class _SplitEnvironment extends InheritedWidget {
  const _SplitEnvironment({
    required this.compact,
    required this.header,
    required this.primary,
    required this.secondary,
    required this.width,
    required this.requestedWidth,
    required this.resize,
    required this.commitResize,
    required this.resizable,
    required this.close,
    required this.reselection,
    required super.child,
  });
  final bool compact;
  final Widget? header;
  final Widget primary;
  final Widget? secondary;
  final AnimationController width;
  final double Function() requestedWidth;
  final _Resize resize;
  final VoidCallback commitResize;
  final bool resizable;
  final VoidCallback? close;
  final ValueListenable<({int index, int sequence})> reselection;
  static _SplitEnvironment of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<_SplitEnvironment>()!;
  @override
  bool updateShouldNotify(_SplitEnvironment oldWidget) => true;

  Widget withHeader(Widget child) => header == null
      ? child
      : Column(
          children: [
            header!,
            Expanded(child: child),
          ],
        );
}

class _SplitRoot extends StatelessWidget {
  const _SplitRoot();
  @override
  Widget build(BuildContext context) {
    final view = _SplitEnvironment.of(context);
    if (view.compact) return view.withHeader(view.primary);
    return const SizedBox.shrink();
  }
}

class _SplitSecondary extends StatelessWidget {
  const _SplitSecondary();
  @override
  Widget build(BuildContext context) {
    final view = _SplitEnvironment.of(context);
    // A removed route may animate out after the GlobalKey moves to the row.
    if (!view.compact || view.secondary == null) return const SizedBox.shrink();
    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) view.close?.call();
      },
      child: FrostShellNavigationScope(
        ownsBackControl: FrostShellNavigationScope.maybeOf(context)?.ownsBackControl ?? false,
        canGoBack: view.close != null,
        goBack: view.close ?? () {},
        primaryReselection: view.reselection,
        child: view.secondary!,
      ),
    );
  }
}

class _WideSplit extends StatelessWidget {
  const _WideSplit({required this.view});
  final _SplitEnvironment view;
  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final line = 1 / MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) => AnimatedBuilder(
        animation: view.width,
        builder: (context, _) {
          final width = math.min(view.width.value, math.max(0.0, constraints.maxWidth - line - _minimumSecondaryWidth));
          // One step moves what the user sees. While the pane is held below its
          // requested width there is no room to grow: the request stays as it is.
          double stepped(double delta) {
            final requested = view.requestedWidth();
            final room = math.max(0.0, constraints.maxWidth - line - _minimumSecondaryWidth);
            if (delta > 0 && requested >= room) return requested;
            return (math.min(requested, room) + delta).clamp(_minimumPrimaryWidth, _maximumPrimaryWidth);
          }

          return Stack(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: width, child: view.primary),
                  const FrostDivider(axis: Axis.vertical),
                  Expanded(child: view.secondary ?? const SizedBox.shrink()),
                ],
              ),
              if (view.resizable)
                PositionedDirectional(
                  start: width + (line - _resizeHitWidth) / 2,
                  top: 0,
                  bottom: 0,
                  width: _resizeHitWidth,
                  child: AnimatedBuilder(
                    animation: view.width,
                    builder: (context, _) => Semantics(
                      value: width.round().toString(),
                      increasedValue: stepped(_keyboardWidthStep).round().toString(),
                      decreasedValue: stepped(-_keyboardWidthStep).round().toString(),
                      onIncrease: () {
                        view.resize(stepped(_keyboardWidthStep), animate: true);
                        view.commitResize();
                      },
                      onDecrease: () {
                        view.resize(stepped(-_keyboardWidthStep), animate: true);
                        view.commitResize();
                      },
                      child: _ResizeFocus(
                        onResizeEnd: view.commitResize,
                        onKeyEvent: (_, event) {
                          if (event is! KeyDownEvent && event is! KeyRepeatEvent) return KeyEventResult.ignored;
                          final key = event.logicalKey;
                          final target = switch (key) {
                            LogicalKeyboardKey.arrowLeft => stepped(rtl ? _keyboardWidthStep : -_keyboardWidthStep),
                            LogicalKeyboardKey.arrowRight => stepped(rtl ? -_keyboardWidthStep : _keyboardWidthStep),
                            LogicalKeyboardKey.home => _minimumPrimaryWidth,
                            LogicalKeyboardKey.end => _maximumPrimaryWidth,
                            _ => null,
                          };
                          if (target == null) return KeyEventResult.ignored;
                          view.resize(target, animate: true);
                          return KeyEventResult.handled;
                        },
                        child: FrostTouchTarget(
                          enabled: true,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onHorizontalDragStart: (_) => view.resize(width),
                            onHorizontalDragUpdate: (details) => view.resize(view.requestedWidth() + details.delta.dx * (rtl ? -1 : 1)),
                            onHorizontalDragEnd: (_) => view.commitResize(),
                            onHorizontalDragCancel: view.commitResize,
                            child: const MouseRegion(cursor: SystemMouseCursors.resizeLeftRight, child: SizedBox.expand()),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _ResizeFocus extends StatefulWidget {
  const _ResizeFocus({required this.onKeyEvent, required this.onResizeEnd, required this.child});
  final FocusOnKeyEventCallback onKeyEvent;
  final VoidCallback onResizeEnd;
  final Widget child;
  @override
  State<_ResizeFocus> createState() => _ResizeFocusState();
}

class _ResizeFocusState extends State<_ResizeFocus> {
  bool _highlight = false;
  final _adjusting = <LogicalKeyboardKey>{};

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent && _adjusting.remove(event.logicalKey)) {
      if (_adjusting.isEmpty) widget.onResizeEnd();
      return KeyEventResult.handled;
    }
    final result = widget.onKeyEvent(node, event);
    if (result == KeyEventResult.handled) _adjusting.add(event.logicalKey);
    return result;
  }

  @override
  Widget build(BuildContext context) => Focus(
    canRequestFocus: false,
    skipTraversal: true,
    onKeyEvent: _key,
    child: FocusableActionDetector(
      onFocusChange: (focused) {
        if (!focused && _adjusting.isNotEmpty) {
          _adjusting.clear();
          widget.onResizeEnd();
        }
      },
      onShowFocusHighlight: (value) => setState(() => _highlight = value),
      child: ListenableBuilder(
        listenable: FrostInputModality.instance,
        builder: (context, child) => DecoratedBox(
          decoration: BoxDecoration(
            border: frostShowsFocus({if (_highlight) WidgetState.focused})
                ? Border.all(color: FrostThemeTokens.of(context).focus, width: FrostMetrics.focusBorderWidth)
                : null,
          ),
          child: child,
        ),
        child: widget.child,
      ),
    ),
  );
}
