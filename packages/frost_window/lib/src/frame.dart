import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:frost_ui/frost_ui.dart';

import 'back.dart';
import 'caption_glyph.dart';
import 'controller.dart';

abstract final class FrostWindowMetrics {
  static const titleBarHeight = 44.0;
  static const captionButtonWidth = 46.0;
  static const captionGlyph = 10.0;
}

/// Accessible names of the caption buttons, supplied by the app.
@immutable
class FrostWindowLabels {
  const FrostWindowLabels({required this.minimize, required this.maximize, required this.restore, required this.close, required this.retry});

  final String minimize;
  final String maximize;
  final String restore;
  final String close;

  /// Shown on the button that retries a failed native window setup.
  final String retry;
}

/// The window's title bar and the native window behaviour behind it.
///
/// Install it with `WidgetsApp.builder` (for example `MaterialApp.router`'s
/// builder), outside the app's Navigator, so dialog barriers cover the page
/// but never the window controls or the draggable caption. On platforms
/// without the custom title bar it returns [child] unchanged.
class FrostWindowFrame extends StatefulWidget {
  const FrostWindowFrame({required this.controller, required this.title, required this.labels, required this.child, this.leading, super.key});

  final FrostWindowController controller;

  /// Contextual title shown in the caption and given to the taskbar.
  final String title;

  /// Brand mark at the start of the caption, such as the app's logo and name.
  /// It is part of the draggable caption.
  final Widget? leading;
  final FrostWindowLabels labels;
  final Widget child;

  @override
  State<FrostWindowFrame> createState() => _FrostWindowFrameState();
}

class _FrostWindowFrameState extends State<FrostWindowFrame> with WidgetsBindingObserver {
  final _titleRegion = GlobalKey();
  final _spaceRegion = GlobalKey();
  final _maximizeRegion = GlobalKey();
  final _contentFocus = FocusScopeNode(debugLabel: 'Window content');
  FocusNode? _lastContentFocus;
  String? _lastRegions;
  String? _lastToolbar;
  bool _syncQueued = false;

  FrostWindowController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_stateChanged);
    _controller.addBackListener(_navigateBack);
    FocusManager.instance.addListener(_rememberContentFocus);
    WidgetsBinding.instance.addObserver(this);
    if (frostUsesCustomTitleBar) unawaited(_initializeNative());
  }

  @override
  void didUpdateWidget(FrostWindowFrame oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller
        ..removeListener(_stateChanged)
        ..removeBackListener(_navigateBack);
      _controller
        ..addListener(_stateChanged)
        ..addBackListener(_navigateBack);
      _lastRegions = null;
      _lastToolbar = null;
      if (frostUsesCustomTitleBar) unawaited(_initializeNative());
    }
  }

  Future<void> _initializeNative() async {
    try {
      await _controller.initialize();
    } on FrostWindowFailure {
      return;
    }
    if (!mounted) return;
    // Send the geometry again once the channel is ready, even when no
    // activation, maximize or resize event follows the first frame.
    _lastRegions = null;
    _lastToolbar = null;
    _queueSync();
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void _stateChanged() {
    if (mounted) setState(() {});
  }

  void _navigateBack() {
    if (!mounted || !_controller.state.active || _controller.state.minimized) return;
    FocusNode? target = FocusManager.instance.primaryFocus;
    if (target == null || !target.ancestors.contains(_contentFocus)) {
      target = _contentFocus.focusedChild;
      while (target is FocusScopeNode && target.focusedChild != null) {
        target = target.focusedChild;
      }
      final previous = _lastContentFocus;
      final previousContext = previous?.context;
      if (previousContext != null &&
          previousContext.mounted &&
          ModalRoute.of(previousContext)?.isCurrent == true &&
          (target == null || target is FocusScopeNode)) {
        target = previous;
      }
    }
    requestFrostBack(context: target?.context);
  }

  void _rememberContentFocus() {
    final current = FocusManager.instance.primaryFocus;
    if (current != null && current is! FocusScopeNode && current.ancestors.contains(_contentFocus)) {
      _lastContentFocus = current;
    }
  }

  @override
  void didChangeMetrics() => _queueSync();

  void _queueSync() {
    if (_syncQueued || !frostUsesCustomTitleBar) return;
    _syncQueued = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncQueued = false;
      if (mounted) _syncNative();
    });
  }

  void _syncNative() {
    if (_controller.failed || !_controller.ready) return;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final toolbar = '${widget.title}|$dark';
    if (toolbar != _lastToolbar) {
      _lastToolbar = toolbar;
      unawaited(_perform(() => _controller.setToolbar(title: widget.title, dark: dark)));
    }
    final regions = <List<Object>>[];
    for (final (key, kind) in [(_titleRegion, 'caption'), (_spaceRegion, 'caption'), (_maximizeRegion, 'maximize')]) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final rect = box.localToGlobal(Offset.zero) & box.size;
      regions.add([rect.left, rect.top, rect.right, rect.bottom, kind]);
    }
    if (regions.toString() != _lastRegions) {
      _lastRegions = regions.toString();
      unawaited(_perform(() => _controller.setRegions(regions)));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_stateChanged);
    _controller.removeBackListener(_navigateBack);
    FocusManager.instance.removeListener(_rememberContentFocus);
    _contentFocus.dispose();
    if (frostUsesCustomTitleBar && _controller.ready) unawaited(_perform(() => _controller.setRegions(const [])));
    super.dispose();
  }

  Future<void> _perform(Future<void> Function() operation) async {
    try {
      await operation();
    } on FrostWindowFailure {
      // The failure is shown in the frame with a retry; native details stay
      // private and command futures never escape as unhandled exceptions.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!frostUsesCustomTitleBar) return widget.child;
    final tokens = FrostThemeTokens.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        _queueSync();
        final state = _controller.state;
        final labels = widget.labels;
        final foreground = tokens.textPrimary.withValues(alpha: state.active ? 1 : .6);
        final titleWidth = math.max(0.0, math.min(constraints.maxWidth * .5, constraints.maxWidth - 3 * FrostWindowMetrics.captionButtonWidth - 8));
        final titleStyle = Theme.of(context).textTheme.labelLarge?.copyWith(color: foreground, fontWeight: FontWeight.w600);
        return Shortcuts(
          shortcuts: {
            const SingleActivator(LogicalKeyboardKey.arrowLeft, alt: true, includeRepeats: false): VoidCallbackIntent(_navigateBack),
            const SingleActivator(LogicalKeyboardKey.goBack, includeRepeats: false): VoidCallbackIntent(_navigateBack),
          },
          // The page's Navigator is below this frame. Caption tooltips get
          // their own overlay while modal barriers stay within the page.
          child: Overlay.wrap(
            child: Column(
              children: [
                ColoredBox(
                  color: tokens.canvas,
                  child: _WindowRegionLayout(
                    onLayout: _queueSync,
                    child: SizedBox(
                      height: FrostWindowMetrics.titleBarHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: titleWidth),
                            child: Row(
                              key: _titleRegion,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 12),
                                if (widget.leading case final leading?) ...[Opacity(opacity: state.active ? 1 : .6, child: leading), const SizedBox(width: 20)],
                                Flexible(
                                  child: Tooltip(
                                    message: widget.title,
                                    child: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: titleStyle),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(child: SizedBox(key: _spaceRegion)),
                          if (_controller.failed)
                            FrostCaptionButton(label: labels.retry, glyph: FrostCaptionGlyphKind.retry, onPressed: () => unawaited(_initializeNative())),
                          FrostCaptionButton(
                            label: labels.minimize,
                            glyph: FrostCaptionGlyphKind.minimize,
                            onPressed: () => unawaited(_perform(_controller.minimize)),
                          ),
                          FrostCaptionButton(
                            key: _maximizeRegion,
                            label: state.maximized ? labels.restore : labels.maximize,
                            glyph: state.maximized ? FrostCaptionGlyphKind.restore : FrostCaptionGlyphKind.maximize,
                            onPressed: () => unawaited(_perform(_controller.toggleMaximized)),
                            nativeHovered: state.hoveredButton == 'maximize',
                            nativePressed: state.pressedButton == 'maximize',
                          ),
                          FrostCaptionButton(
                            label: labels.close,
                            glyph: FrostCaptionGlyphKind.close,
                            onPressed: () => unawaited(_perform(_controller.close)),
                            danger: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Semantics(
                    container: true,
                    explicitChildNodes: true,
                    // Navigator barriers block earlier semantics only within
                    // this content boundary, preserving the window controls.
                    child: FocusScope(
                      node: _contentFocus,
                      child: FrostWindowCaptionScope(showsTitle: true, child: widget.child),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// One caption button. [nativeHovered]/[nativePressed] reflect Windows' own
/// hit testing of the maximize button, which keeps Snap Layouts working.
class FrostCaptionButton extends StatelessWidget {
  const FrostCaptionButton({
    required this.label,
    required this.glyph,
    required this.onPressed,
    this.nativeHovered = false,
    this.nativePressed = false,
    this.danger = false,
    super.key,
  });

  final String label;
  final FrostCaptionGlyphKind glyph;
  final VoidCallback onPressed;
  final bool nativeHovered;
  final bool nativePressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final tokens = FrostThemeTokens.of(context);
    return IconButton(
      tooltip: label,
      onPressed: onPressed,
      // Windows UI Automation names controls from their semantic label; a
      // tooltip alone leaves these otherwise valid button nodes unnamed.
      icon: Semantics(
        label: label,
        child: Builder(
          builder: (context) => FrostCaptionGlyph(glyph, color: IconTheme.of(context).color ?? tokens.textPrimary, size: FrostWindowMetrics.captionGlyph),
        ),
      ),
      style: ButtonStyle(
        fixedSize: const WidgetStatePropertyAll(Size(FrostWindowMetrics.captionButtonWidth, FrostWindowMetrics.titleBarHeight)),
        // Caption controls own their feedback; the shared animated neutral
        // background would otherwise cover the close button's red fill.
        backgroundBuilder: (context, states, child) => child ?? const SizedBox.shrink(),
        minimumSize: const WidgetStatePropertyAll(Size.zero),
        padding: const WidgetStatePropertyAll(EdgeInsets.zero),
        shape: const WidgetStatePropertyAll(RoundedRectangleBorder()),
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              danger && (states.contains(WidgetState.hovered) || states.contains(WidgetState.pressed)) ? FrostCaptionColors.onClose : tokens.textPrimary,
        ),
        mouseCursor: const WidgetStatePropertyAll(SystemMouseCursors.basic),
        side: WidgetStateProperty.resolveWith(
          (states) => BorderSide(color: frostShowsFocus(states) ? tokens.focus : Colors.transparent, width: FrostMetrics.focusBorderWidth),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          final hover = nativeHovered || states.contains(WidgetState.hovered);
          final press = (nativePressed && nativeHovered) || states.contains(WidgetState.pressed);
          if (!hover && !press) return (danger ? FrostCaptionColors.closeHover : tokens.hoverSurface).withValues(alpha: 0);
          if (danger) return press ? FrostCaptionColors.closePressed : FrostCaptionColors.closeHover;
          return press ? tokens.pressedSurface : tokens.hoverSurface;
        }),
      ),
    );
  }
}

// Overlay descendants can lay out without rebuilding the frame's
// LayoutBuilder. Synchronize from the actual title bar layout, not just
// ancestor rebuilds.
class _WindowRegionLayout extends SingleChildRenderObjectWidget {
  const _WindowRegionLayout({required this.onLayout, required super.child});

  final VoidCallback onLayout;

  @override
  RenderObject createRenderObject(BuildContext context) => _WindowRegionRenderBox(onLayout);

  @override
  void updateRenderObject(BuildContext context, _WindowRegionRenderBox renderObject) => renderObject.onLayout = onLayout;
}

class _WindowRegionRenderBox extends RenderProxyBox {
  _WindowRegionRenderBox(this.onLayout);

  VoidCallback onLayout;

  @override
  void performLayout() {
    super.performLayout();
    onLayout();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    // Route transitions can move the header through paint transforms
    // without laying it out again. Measure after that frame as well.
    onLayout();
  }
}
