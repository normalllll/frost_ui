import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../controls/_form_submit.dart';
import '../foundation/metrics.dart';
import '../motion/_material_reveal.dart';
import '_anchored_panel_layout.dart';
import '_menu_panel.dart';
import '_menu_target.dart';
import 'menu_entry.dart';
import 'overlay_region.dart';
import 'panel_action.dart';

typedef FrostMenuTriggerBuilder = Widget Function(BuildContext context, FocusNode focusNode, VoidCallback toggle);

/// MenuAnchor whose trigger takes focus when it opens the menu. A pointer
/// click does not focus a button, and without focus in the anchor Escape and
/// the arrow keys never reach the open menu. Closing returns focus to the
/// trigger, which is already where it is.
class FrostMenuAnchor extends StatelessWidget {
  const FrostMenuAnchor({required this.entries, required this.builder, super.key});
  final List<FrostMenuEntry> entries;
  final FrostMenuTriggerBuilder builder;
  @override
  Widget build(BuildContext context) => FrostMenuHost(entries: entries, builder: builder);
}

/// Internal host shared by anchored controls and point-anchored context menus.
class FrostMenuHost extends StatefulWidget {
  const FrostMenuHost({
    required this.entries,
    required this.builder,
    this.autoOpen = false,
    this.onClosed,
    this.returnFocus,
    this.panelBuilder,
    this.route,
    super.key,
  });

  final List<FrostMenuEntry> entries;
  final bool autoOpen;
  final VoidCallback? onClosed;
  final FocusNode? returnFocus;
  final FrostMenuTriggerBuilder builder;
  // Arbitrary content remains a library-only host capability. Public menus
  // accept entries; FrostPopover is the public arbitrary-content component.
  final Widget Function(BuildContext context, VoidCallback close)? panelBuilder;

  /// The route system Back should close this menu before, for a host placed in
  /// the root overlay, outside the route of the content it opened over.
  final ModalRoute<Object?>? route;

  @override
  State<FrostMenuHost> createState() => _AppMenuAnchorState();
}

/// Publishes Android's frameworkHandlesBack policy while a menu is open.
class _MenuPopEntry extends PopEntry<Object?> {
  @override
  final ValueNotifier<bool> canPopNotifier = ValueNotifier(true);
  @override
  void onPopInvokedWithResult(bool didPop, Object? result) {}
}

class _AppMenuAnchorState extends State<FrostMenuHost> with SingleTickerProviderStateMixin {
  final _controller = MenuController();
  final _focusNode = FocusNode(debugLabel: 'Menu trigger');
  final _menuFocus = FocusScopeNode(debugLabel: 'Menu');

  /// 0 closed, 1 open; a spring, so reopening mid-close turns back smoothly.
  late final AnimationController _reveal = AnimationController.unbounded(vsync: this);
  final _glass = FrostRevealHandle();
  final _side = FrostAnchoredPanelSide();
  bool _closing = false;
  LocalHistoryEntry? _history;
  ModalRoute<Object?>? _popRoute;
  Completer<void>? _closed;

  final _popEntry = _MenuPopEntry();
  ModalRoute<Object?>? _willPopRoute;

  // Back that closes a menu belongs to the menu alone. A pop entry would answer
  // too late: the route has refused by then and tells every PopScope on the
  // page. This is the one hook a route asks first, deprecated but still consulted.
  Future<bool> _willPop() async {
    if (_controller.isOpen && !_closing) _dismiss();
    return false;
  }

  void _releaseBack() {
    _popEntry.canPopNotifier.value = true;
    final route = _willPopRoute;
    _willPopRoute = null;
    // ignore: deprecated_member_use
    if (route != null && route.isActive && route.subtreeContext != null) route.removeScopedWillPopCallback(_willPop);
  }

  /// A popover's content can refuse to be left, with a PopScope like any route
  /// content. It registers with the page's route, which cannot say whose it is.
  PopScope<dynamic>? _contentPopScope() {
    PopScope<dynamic>? refusing;
    void visit(Element element) {
      if (refusing != null) return;
      final widget = element.widget;
      if (widget is PopScope<dynamic> && !widget.canPop) {
        refusing = widget;
      } else {
        element.visitChildren(visit);
      }
    }

    if (widget.panelBuilder != null) _menuFocus.context?.visitChildElements(visit);
    return refusing;
  }

  /// Escape and a tap outside, which a popover's PopScope can refuse. Selecting
  /// an item and the content's own close callback are decisions, and always close.
  void _dismiss() {
    final refusing = _contentPopScope();
    if (refusing == null) {
      _controller.close();
    } else {
      final dynamic scope = refusing;
      scope.onPopInvokedWithResult?.call(false, null);
    }
  }

  // The entry stays with the route and only changes its answer, as a PopScope
  // does: a route walks its entries to notify them, so one cannot leave then.
  void _claimPop(ModalRoute<Object?> route) {
    if (!identical(_popRoute, route)) {
      _unregisterPop();
      _popRoute = route;
      route.registerPopEntry(_popEntry);
    }
    _popEntry.canPopNotifier.value = false;
    // ignore: deprecated_member_use
    route.addScopedWillPopCallback(_willPop);
    _willPopRoute = route;
  }

  void _unregisterPop() {
    final route = _popRoute;
    _popRoute = null;
    if (route != null && route.isActive) route.unregisterPopEntry(_popEntry);
  }

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_focusChanged);
    _menuFocus.addListener(_focusChanged);
    if (widget.autoOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _toggle();
      });
    }
  }

  @override
  void dispose() {
    _closing = true;
    if (_closed?.isCompleted == false) _closed!.complete();
    _history?.remove();
    _history = null;
    _releaseBack();
    _unregisterPop();
    _popEntry.canPopNotifier.dispose();
    _reveal.dispose();
    _menuFocus.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _focusChanged() {
    if (_closing || !mounted) return;
    if (!_focusNode.hasFocus && !_menuFocus.hasFocus && _controller.isOpen) _dismiss();
  }

  bool get _tickersEnabled => TickerMode.valuesOf(context).enabled;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // A subtree whose tickers stop (a collapsing download panel) cannot run
    // the closing spring; its open menu closes at once instead of freezing
    // half-shrunk on screen.
    if (!_tickersEnabled && _controller.isOpen) _controller.close();
  }

  void _toggle() {
    if (widget.entries.isEmpty && widget.panelBuilder == null) return;
    if (_controller.isOpen && !_closing) {
      _dismiss();
      return;
    }
    _focusNode.requestFocus();
    _controller.open();
  }

  @override
  Widget build(BuildContext context) {
    // The menu grows out of its anchor on a spring and shrinks back into it,
    // on the glass overlay material; the framework's
    // own menu animation has fixed Material timings.
    return RawMenuAnchor(
      controller: _controller,
      childFocusNode: _focusNode,
      onClose: () {
        widget.onClosed?.call();
        if (_closed?.isCompleted == false) _closed!.complete();
      },
      onOpenRequested: (position, showOverlay) {
        _closed = Completer<void>();
        _closing = false;
        final route = widget.route ?? ModalRoute.of(context);
        if (_history == null && route != null) {
          // RawMenuAnchor is an Overlay, not a route. Local history lets system
          // Back close it before a root/nested page and disables page preview
          // while the menu owns that return, using the framework's usual path.
          // It handles imperative Navigator.pop. The pop entry also publishes
          // Android's frameworkHandlesBack policy, which local history does not
          // notify when added to a root route on its own.
          _history = LocalHistoryEntry(
            impliesAppBarDismissal: false,
            onRemove: () {
              _history = null;
              _releaseBack();
              if (mounted && !_closing && _controller.isOpen) _controller.close();
            },
          );
          route.addLocalHistoryEntry(_history!);
          _claimPop(route);
        }
        _glass.cancelClose();
        showOverlay();
        _animateReveal(true);
        if (widget.panelBuilder != null) {
          // The panel holds focus so Escape reaches it; a caller's autofocus wins.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_closing && _controller.isOpen && !_menuFocus.hasFocus) _menuFocus.requestFocus();
          });
        }
      },
      onCloseRequested: (hideOverlay) {
        final ownsFocus = _focusNode.hasFocus || _menuFocus.hasFocus;
        _closing = true;
        final history = _history;
        _history = null;
        history?.remove();
        _releaseBack();
        if (ownsFocus) {
          final target = widget.returnFocus ?? _focusNode;
          if (target.context != null && target.canRequestFocus) target.requestFocus();
        }
        if (!_tickersEnabled) {
          _closing = false;
          _reveal.value = 0;
          hideOverlay();
          return;
        }
        _closing = true;
        _glass.prepareClose().then((ready) {
          if (!ready || !mounted || !_closing) return;
          _animateReveal(false).orCancel.then((_) {
            if (mounted && _closing) {
              _closing = false;
              hideOverlay();
            }
          }, onError: (_) {});
        });
      },
      overlayBuilder: (overlayContext, info) => FrostPanelActionScope(
        origin: context,
        close: () async {
          if (!_controller.isOpen) return false;
          final done = _closed!.future;
          _controller.close();
          await done;
          return true;
        },
        child: _AnchoredMenu(
          info: RawMenuOverlayInfo(
            anchorRect: FrostMenuTarget.rectOf(context) ?? info.anchorRect,
            overlaySize: info.overlaySize,
            tapRegionGroupId: info.tapRegionGroupId,
            position: info.position,
          ),
          offset: frostAnchoredPanelGap,
          reveal: _reveal,
          revealHandle: _glass,
          closing: () => _closing,
          focusNode: _menuFocus,
          onDismiss: _dismiss,
          onClose: _controller.close,
          entries: widget.entries,
          triggerWidth: FrostMenuTarget.matchesWidthOf(context) ? (FrostMenuTarget.rectOf(context) ?? info.anchorRect).width : null,
          panelBuilder: widget.panelBuilder,
          side: _side,
        ),
      ),
      builder: (context, controller, _) => widget.builder(context, _focusNode, _toggle),
    );
  }

  // With reduced motion the spring goes straight to its end, for popovers as for menus.
  TickerFuture _animateReveal(bool opening) => FrostMotion.springTo(context, _reveal, opening ? 1 : 0, opening ? FrostMotion.standard : FrostMotion.snappy);
}

/// Lets the items of an open [FrostMenuAnchor] close it.
class FrostMenuScope extends InheritedWidget {
  const FrostMenuScope({required this.close, required super.child, super.key});

  final VoidCallback close;

  @override
  bool updateShouldNotify(FrostMenuScope oldWidget) => close != oldWidget.close;
}

/// The open menu of an [FrostMenuAnchor]: below the anchor (above when there is
/// no room), kept inside the overlay, as a glass panel that scales in from
/// the anchor's side.
class _AnchoredMenu extends StatelessWidget {
  const _AnchoredMenu({
    required this.info,
    required this.offset,
    required this.reveal,
    required this.revealHandle,
    required this.closing,
    required this.focusNode,
    required this.onDismiss,
    required this.onClose,
    required this.entries,
    required this.triggerWidth,
    required this.panelBuilder,
    required this.side,
  });

  final FrostAnchoredPanelSide side;
  final RawMenuOverlayInfo info;
  final Offset offset;
  final Animation<double> reveal;
  final FrostRevealHandle revealHandle;
  final bool Function() closing;
  final FocusScopeNode focusNode;
  final VoidCallback onDismiss, onClose;
  final List<FrostMenuEntry> entries;
  final double? triggerWidth;
  final Widget Function(BuildContext context, VoidCallback close)? panelBuilder;

  @override
  Widget build(BuildContext context) {
    return CustomSingleChildLayout(
      delegate: FrostAnchoredPanelLayout(
        anchor: info.anchorRect,
        offset: offset,
        direction: Directionality.of(context),
        side: side,
        margin: frostAnchoredPanelMargin,
        bounds: FrostOverlayRegionData.maybeOf(context)?.inOverlay(Overlay.of(context).context.findRenderObject()! as RenderBox),
      ),
      child: TapRegion(
        groupId: info.tapRegionGroupId,
        onTapOutside: (_) => onDismiss(),
        // Outside the focus scope, so Escape also works when the scope itself
        // holds focus, as a popover without a focused control does.
        child: Shortcuts(
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
            SingleActivator(LogicalKeyboardKey.arrowDown): DirectionalFocusIntent(TraversalDirection.down),
            SingleActivator(LogicalKeyboardKey.arrowUp): DirectionalFocusIntent(TraversalDirection.up),
          },
          child: Actions(
            actions: {DismissIntent: CallbackAction<DismissIntent>(onInvoke: (_) => onDismiss())},
            child: FocusScope(
              node: focusNode,
              child: FrostMenuScope(
                close: onClose,
                child: FrostMenuReveal(
                  reveal: reveal,
                  handle: revealHandle,
                  closing: closing,
                  alignment: AlignmentDirectional.topStart,
                  side: side,
                  child: panelBuilder == null
                      ? FrostMenuPanel(triggerWidth: triggerWidth, children: frostMenuChildren(context, entries))
                      : FrostDialogSubmitScope(submit: null, child: panelBuilder!(context, onClose)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Scales a menu panel in from its anchor side (0.94 → 1) and fades it, with
/// [reveal] running 0 → 1. While [closing] it no longer takes input.
class FrostMenuReveal extends StatelessWidget {
  const FrostMenuReveal({required this.reveal, required this.closing, required this.alignment, required this.child, this.handle, this.side, super.key});

  final FrostRevealHandle? handle;
  final Animation<double> reveal;
  final bool Function() closing;
  final AlignmentGeometry alignment;

  /// When set, a panel placed above its anchor scales from its bottom edge. Read
  /// each frame: the first frame is laid out before the side is known, at zero opacity.
  final FrostAnchoredPanelSide? side;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: reveal,
      builder: (context, child) {
        final progress = reveal.value.clamp(0.0, 1.0);
        final shut = closing();
        return IgnorePointer(
          ignoring: shut,
          child: ExcludeFocus(
            excluding: shut,
            child: ExcludeSemantics(
              excluding: shut,
              child: FrostMaterialReveal(
                handle: handle,
                opacity: progress,
                child: Transform.scale(
                  scale: MediaQuery.disableAnimationsOf(context) ? 1 : .94 + .06 * progress,
                  alignment: (side == null ? alignment : AlignmentDirectional(side!.turned ? 1 : -1, side!.below ? -1 : 1)).resolve(Directionality.of(context)),
                  child: child,
                ),
              ),
            ),
          ),
        );
      },
      child: child,
    );
  }
}
